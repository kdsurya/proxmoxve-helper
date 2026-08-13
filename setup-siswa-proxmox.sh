#!/bin/bash

set -Eeuo pipefail

# ============================================================
# SETUP LAB SISWA - PROXMOX VE 9.x - ChatGPT
#
# Fitur:
# - Membuat akun siswa01@pve ... siswa30@pve
# - Membuat pool khusus setiap siswa
# - Siswa hanya dapat mengelola CT dalam pool miliknya
# - Siswa dapat membuat LXC sendiri
# - Template diambil dari storage "local"
# - Disk CT disimpan di "local-lvm"
# - Bridge yang boleh digunakan hanya "vmbr0"
# - Pool siswa lain tidak dapat digunakan
#
# ============================================================


# ============================================================
# KONFIGURASI
# ============================================================

JUMLAH_SISWA=30

USER_PREFIX="siswa"
REALM="pve"

# Storage tempat template LXC
TEMPLATE_STORAGE="local"

# Storage rootfs container
CT_STORAGE="local-lvm"

# Bridge yang boleh digunakan siswa
BRIDGE="vmbr0"

# File penyimpanan username/password
PASSWORD_FILE="/root/password-siswa-proxmox.csv"


# ============================================================
# CUSTOM ROLE
# ============================================================

ROLE_CT="LabStudentCT"

ROLE_TEMPLATE="LabTemplateRead"

ROLE_STORAGE="LabCTStorage"

ROLE_NODE="LabNodeView"

ROLE_NETWORK_AUDIT="LabNetworkAudit"

ROLE_NETWORK_USE="LabNetworkUse"


# ============================================================
# ERROR HANDLER
# ============================================================

trap 'echo; echo "ERROR pada baris $LINENO."; exit 1' ERR


# ============================================================
# CEK ROOT
# ============================================================

if [ "$(id -u)" -ne 0 ]; then

    echo
    echo "ERROR:"
    echo "Script harus dijalankan sebagai root."
    echo

    exit 1

fi


echo
echo "============================================================"
echo " SETUP LAB SISWA PROXMOX VE 9.x"
echo "============================================================"
echo

pveversion

echo
echo "Jumlah siswa     : $JUMLAH_SISWA"
echo "Template storage : $TEMPLATE_STORAGE"
echo "CT storage       : $CT_STORAGE"
echo "Bridge           : $BRIDGE"
echo


# ============================================================
# CEK COMMAND
# ============================================================

for CMD in pveum pvesm pveversion openssl ip
do

    if ! command -v "$CMD" >/dev/null 2>&1; then

        echo "ERROR: command '$CMD' tidak ditemukan."
        exit 1

    fi

done


# ============================================================
# CEK STORAGE TEMPLATE
# ============================================================

echo "Memeriksa storage template..."

if ! pvesm status | awk 'NR > 1 {print $1}' | grep -Fxq "$TEMPLATE_STORAGE"; then

    echo
    echo "ERROR:"
    echo "Storage template '$TEMPLATE_STORAGE' tidak ditemukan."
    echo
    echo "Storage tersedia:"
    echo

    pvesm status

    exit 1

fi

echo "OK: $TEMPLATE_STORAGE ditemukan."


# ============================================================
# CEK STORAGE CT
# ============================================================

echo "Memeriksa storage CT..."

if ! pvesm status | awk 'NR > 1 {print $1}' | grep -Fxq "$CT_STORAGE"; then

    echo
    echo "ERROR:"
    echo "Storage '$CT_STORAGE' tidak ditemukan."
    echo
    echo "Storage tersedia:"
    echo

    pvesm status

    exit 1

fi

echo "OK: $CT_STORAGE ditemukan."


# ============================================================
# CEK BRIDGE
# ============================================================

echo "Memeriksa bridge..."

if ! ip link show "$BRIDGE" >/dev/null 2>&1; then

    echo
    echo "ERROR:"
    echo "Bridge '$BRIDGE' tidak ditemukan."
    echo
    echo "Interface yang tersedia:"
    echo

    ip -br link

    exit 1

fi

echo "OK: $BRIDGE ditemukan."


# ============================================================
# FUNCTION: ROLE EXISTS
# ============================================================

role_exists() {

    local ROLE="$1"

    pveum role list \
        | awk 'NR > 1 {print $1}' \
        | grep -Fxq "$ROLE"

}


# ============================================================
# FUNCTION: CREATE / UPDATE ROLE
# ============================================================

create_or_update_role() {

    local ROLE="$1"
    local PRIVS="$2"

    if role_exists "$ROLE"; then

        echo "Update role: $ROLE"

        pveum role modify "$ROLE" \
            -privs "$PRIVS"

    else

        echo "Membuat role: $ROLE"

        pveum role add "$ROLE" \
            -privs "$PRIVS"

    fi

}


# ============================================================
# ROLE 1
#
# Hak untuk mengelola CT milik siswa.
#
# Pool.Audit
#     diperlukan supaya Resource Pool tampil pada Create CT
#
# VM.Allocate
#     membuat/menghapus CT pada pool
#
# ============================================================

create_or_update_role "$ROLE_CT" \
"Pool.Audit VM.Allocate VM.Audit VM.Console VM.PowerMgmt VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Disk VM.Config.Options"


# ============================================================
# ROLE 2
#
# Siswa hanya dapat melihat template.
#
# Tidak diberikan:
#
# Datastore.AllocateTemplate
#
# sehingga siswa tidak bisa upload template sendiri.
#
# ============================================================

create_or_update_role "$ROLE_TEMPLATE" \
"Datastore.Audit"


# ============================================================
# ROLE 3
#
# Storage untuk rootfs CT
#
# ============================================================

create_or_update_role "$ROLE_STORAGE" \
"Datastore.Audit Datastore.AllocateSpace"


# ============================================================
# ROLE 4
#
# Melihat node Proxmox
#
# ============================================================

create_or_update_role "$ROLE_NODE" \
"Sys.Audit"


# ============================================================
# ROLE 5
#
# Melihat local network di GUI
#
# ============================================================

create_or_update_role "$ROLE_NETWORK_AUDIT" \
"SDN.Audit"


# ============================================================
# ROLE 6
#
# Menggunakan bridge vmbr0
#
# ============================================================

create_or_update_role "$ROLE_NETWORK_USE" \
"SDN.Use"


# ============================================================
# PASSWORD FILE
# ============================================================

umask 077

if [ ! -f "$PASSWORD_FILE" ]; then

    echo "username,password,pool" > "$PASSWORD_FILE"

fi

chmod 600 "$PASSWORD_FILE"


# ============================================================
# FUNCTION USER EXISTS
# ============================================================

user_exists() {

    local USERID="$1"

    pveum user list \
        | awk 'NR > 1 {print $1}' \
        | grep -Fxq "$USERID"

}


# ============================================================
# FUNCTION POOL EXISTS
# ============================================================

pool_exists() {

    local POOL="$1"

    pveum pool list \
        | awk 'NR > 1 {print $1}' \
        | grep -Fxq "$POOL"

}


echo
echo "============================================================"
echo " MEMBUAT USER DAN RESOURCE POOL"
echo "============================================================"


# ============================================================
# LOOP SISWA
# ============================================================

for N in $(seq 1 "$JUMLAH_SISWA")
do

    # hasil:
    #
    # 1  -> 01
    # 2  -> 02
    # 10 -> 10

    NOMOR=$(printf "%02d" "$N")

    USERNAME="${USER_PREFIX}${NOMOR}"

    USERID="${USERNAME}@${REALM}"

    POOL="pool-${USERNAME}"


    echo
    echo "------------------------------------------------------------"
    echo " SISWA : $USERID"
    echo " POOL  : $POOL"
    echo "------------------------------------------------------------"


    # ========================================================
    # BUAT USER
    # ========================================================

    if user_exists "$USERID"; then

        echo "User sudah ada: $USERID"

    else

        PASSWORD=$(openssl rand -hex 8)

        echo "Membuat user $USERID..."

        pveum user add "$USERID" \
            -password "$PASSWORD" \
            -enable 1 \
            -comment "Akun Lab Proxmox ${USERNAME}"

        echo "${USERID},${PASSWORD},${POOL}" \
            >> "$PASSWORD_FILE"

        echo "OK: user berhasil dibuat."

    fi


    # ========================================================
    # BUAT RESOURCE POOL
    # ========================================================

    if pool_exists "$POOL"; then

        echo "Pool sudah ada: $POOL"

    else

        echo "Membuat pool $POOL..."

        pveum pool add "$POOL" \
            -comment "Container milik ${USERNAME}"

        echo "OK: pool berhasil dibuat."

    fi


    # ========================================================
    # ACL RESOURCE POOL
    #
    # INI BAGIAN TERPENTING.
    #
    # siswa01:
    #
    # /pool/pool-siswa01
    #
    # siswa02:
    #
    # /pool/pool-siswa02
    #
    # dst.
    #
    # ========================================================

    echo "ACL: memberikan akses CT pada $POOL..."

    pveum acl modify "/pool/${POOL}" \
        -user "$USERID" \
        -role "$ROLE_CT" \
        -propagate 1


    # ========================================================
    # ACL TEMPLATE STORAGE
    #
    # Bisa melihat template di storage local.
    #
    # ========================================================

    echo "ACL: memberikan akses template..."

    pveum acl modify "/storage/${TEMPLATE_STORAGE}" \
        -user "$USERID" \
        -role "$ROLE_TEMPLATE" \
        -propagate 0


    # ========================================================
    # ACL ROOTFS STORAGE
    #
    # Bisa membuat disk/rootfs CT pada local-lvm.
    #
    # ========================================================

    echo "ACL: memberikan akses storage CT..."

    pveum acl modify "/storage/${CT_STORAGE}" \
        -user "$USERID" \
        -role "$ROLE_STORAGE" \
        -propagate 0


    # ========================================================
    # ACL NODE
    #
    # Supaya pve1 terlihat di GUI.
    #
    # ========================================================

    echo "ACL: memberikan akses melihat node..."

    pveum acl modify "/nodes" \
        -user "$USERID" \
        -role "$ROLE_NODE" \
        -propagate 1


    # ========================================================
    # ACL NETWORK AUDIT
    #
    # Dibutuhkan supaya GUI dapat melihat localnetwork.
    #
    # TIDAK propagate supaya tidak memberikan SDN.Use
    # secara luas.
    #
    # ========================================================

    echo "ACL: memberikan SDN.Audit..."

    pveum acl modify "/sdn/zones/localnetwork" \
        -user "$USERID" \
        -role "$ROLE_NETWORK_AUDIT" \
        -propagate 0


    # ========================================================
    # ACL BRIDGE
    #
    # Siswa hanya diberikan SDN.Use pada vmbr0.
    #
    # ========================================================

    echo "ACL: memberikan akses bridge $BRIDGE..."

    pveum acl modify "/sdn/zones/localnetwork/${BRIDGE}" \
        -user "$USERID" \
        -role "$ROLE_NETWORK_USE" \
        -propagate 0


    echo
    echo "OK: konfigurasi $USERID selesai."

done


# ============================================================
# SELESAI
# ============================================================

echo
echo
echo "============================================================"
echo " SETUP SELESAI"
echo "============================================================"

echo
echo "Jumlah siswa:"
echo
echo "    $JUMLAH_SISWA"

echo
echo "User:"
echo
echo "    ${USER_PREFIX}01@${REALM}"
echo "    ..."
printf "    %s%02d@%s\n" "$USER_PREFIX" "$JUMLAH_SISWA" "$REALM"

echo
echo "Storage template:"
echo
echo "    $TEMPLATE_STORAGE"

echo
echo "Storage container:"
echo
echo "    $CT_STORAGE"

echo
echo "Bridge:"
echo
echo "    $BRIDGE"

echo
echo "Password akun baru:"
echo
echo "    $PASSWORD_FILE"

echo
echo "Lihat password dengan:"
echo
echo "    cat $PASSWORD_FILE"

echo
echo "============================================================"
echo " CONTOH PERMISSION SISWA01"
echo "============================================================"
echo

if user_exists "${USER_PREFIX}01@${REALM}"; then

    pveum user permissions "${USER_PREFIX}01@${REALM}"

fi

echo
echo "============================================================"
echo " SELESAI"
echo "============================================================"
