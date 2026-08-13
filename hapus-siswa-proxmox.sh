#!/bin/bash

set -u
set -o pipefail

# ============================================================
# CLEANUP LAB SISWA - PROXMOX VE 9.x - ChatGPT
#
# Pasangan dari:
#
#   setup-siswa-proxmox.sh
#
# Script ini:
# - Menghapus seluruh LXC di pool siswa
# - Menghapus pool siswa
# - Menghapus user siswa
# - Menghapus file password siswa
# - Opsional: menghapus custom role Lab
#
# KEAMANAN:
# - Default hanya DRY-RUN
# - Hanya container dalam pool-siswaXX yang dihapus
# - VM/QEMU tidak otomatis dihapus
# - Jika ada resource asing dalam pool, pool/user tidak dihapus
#
# ============================================================


# ============================================================
# KONFIGURASI
# Harus sama dengan setup-siswa-proxmox.sh
# ============================================================

JUMLAH_SISWA=30

USER_PREFIX="siswa"
REALM="pve"

PASSWORD_FILE="/root/password-siswa-proxmox.csv"


# ============================================================
# CUSTOM ROLE YANG DIBUAT OLEH SCRIPT SETUP
# ============================================================

ROLE_LIST=(
    "LabStudentCT"
    "LabTemplateRead"
    "LabCTStorage"
    "LabNodeView"
    "LabNetworkAudit"
    "LabNetworkUse"
)


# ============================================================
# MODE
#
# Default:
#
#   ./hapus-siswa-proxmox.sh
#
# hanya DRY-RUN.
#
# Hapus sungguhan:
#
#   ./hapus-siswa-proxmox.sh --execute
#
# Hapus sungguhan + custom role:
#
#   ./hapus-siswa-proxmox.sh --execute --delete-roles
#
# ============================================================

EXECUTE=0
DELETE_ROLES=0


for ARG in "$@"
do

    case "$ARG" in

        --execute)
            EXECUTE=1
            ;;

        --delete-roles)
            DELETE_ROLES=1
            ;;

        *)
            echo "Parameter tidak dikenal: $ARG"
            echo
            echo "Penggunaan:"
            echo
            echo "  $0"
            echo "  $0 --execute"
            echo "  $0 --execute --delete-roles"
            echo
            exit 1
            ;;

    esac

done


if [ "$EXECUTE" -eq 1 ]; then
    MODE="EXECUTE"
else
    MODE="DRY-RUN"
fi


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


# ============================================================
# CEK COMMAND
# ============================================================

for CMD in pveum pvesh pct jq
do

    if ! command -v "$CMD" >/dev/null 2>&1; then

        echo
        echo "ERROR:"
        echo "Command '$CMD' tidak ditemukan."

        if [ "$CMD" = "jq" ]; then

            echo
            echo "Install jq dengan:"
            echo
            echo "    apt update"
            echo "    apt install -y jq"

        fi

        echo

        exit 1

    fi

done


# ============================================================
# FUNCTION
# ============================================================

user_exists() {

    local USERID="$1"

    pveum user list 2>/dev/null \
        | awk 'NR > 1 {print $1}' \
        | grep -Fxq "$USERID"

}


pool_exists() {

    local POOL="$1"

    pveum pool list 2>/dev/null \
        | awk 'NR > 1 {print $1}' \
        | grep -Fxq "$POOL"

}


role_exists() {

    local ROLE="$1"

    pveum role list 2>/dev/null \
        | awk 'NR > 1 {print $1}' \
        | grep -Fxq "$ROLE"

}


get_pool_json() {

    local POOL="$1"

    pvesh get "/pools/${POOL}" \
        --output-format json 2>/dev/null

}


# ============================================================
# HEADER
# ============================================================

echo
echo "============================================================"
echo " CLEANUP LAB SISWA PROXMOX VE 9.x"
echo "============================================================"
echo
echo "Mode            : $MODE"
echo "Jumlah siswa    : $JUMLAH_SISWA"
echo "User awal       : ${USER_PREFIX}01@${REALM}"
printf "User akhir      : %s%02d@%s\n" \
    "$USER_PREFIX" "$JUMLAH_SISWA" "$REALM"

echo
echo "Yang akan dibersihkan:"
echo
echo "  - Container LXC dalam pool siswa"
echo "  - pool-siswaXX"
echo "  - siswaXX@${REALM}"
echo "  - $PASSWORD_FILE"

if [ "$DELETE_ROLES" -eq 1 ]; then

    echo "  - Custom role Lab"

fi

echo
echo "============================================================"


# ============================================================
# KONFIRMASI
# ============================================================

if [ "$EXECUTE" -eq 1 ]; then

    echo
    echo "PERINGATAN!"
    echo
    echo "Container siswa akan DIHAPUS PERMANEN."
    echo "Root filesystem dan data di dalam CT juga akan hilang."
    echo

    read -r -p "Ketik HAPUS untuk melanjutkan: " KONFIRMASI

    if [ "$KONFIRMASI" != "HAPUS" ]; then

        echo
        echo "Dibatalkan."
        echo

        exit 0

    fi

fi


# ============================================================
# COUNTER
# ============================================================

TOTAL_CT=0
TOTAL_POOL=0
TOTAL_USER=0
TOTAL_GAGAL=0


# ============================================================
# PROSES SETIAP SISWA
# ============================================================

for N in $(seq 1 "$JUMLAH_SISWA")
do

    NOMOR=$(printf "%02d" "$N")

    USERNAME="${USER_PREFIX}${NOMOR}"

    USERID="${USERNAME}@${REALM}"

    POOL="pool-${USERNAME}"


    echo
    echo "============================================================"
    echo " SISWA : $USERID"
    echo " POOL  : $POOL"
    echo "============================================================"


    # ========================================================
    # JIKA POOL ADA
    # ========================================================

    if pool_exists "$POOL"; then

        echo
        echo "Pool ditemukan."

        POOL_JSON=$(get_pool_json "$POOL")

        if [ -z "$POOL_JSON" ]; then

            echo "ERROR: gagal membaca isi pool $POOL."
            TOTAL_GAGAL=$((TOTAL_GAGAL + 1))
            continue

        fi


        # ====================================================
        # AMBIL SEMUA LXC
        # ====================================================

        mapfile -t CONTAINERS < <(

            echo "$POOL_JSON" \
                | jq -r '
                    .members[]?
                    | select(.type == "lxc")
                    | "\(.vmid)|\(.name // "-")"
                '

        )


        if [ "${#CONTAINERS[@]}" -eq 0 ]; then

            echo "Tidak ada LXC dalam pool."

        else

            echo
            echo "Container LXC ditemukan:"

            for ITEM in "${CONTAINERS[@]}"
            do

                VMID="${ITEM%%|*}"
                NAME="${ITEM#*|}"

                echo "    CT $VMID - $NAME"

            done

        fi


        # ====================================================
        # HAPUS CT
        # ====================================================

        for ITEM in "${CONTAINERS[@]}"
        do

            VMID="${ITEM%%|*}"
            NAME="${ITEM#*|}"

            echo
            echo "------------------------------------------------------------"
            echo " CT ID    : $VMID"
            echo " Hostname : $NAME"
            echo "------------------------------------------------------------"


            if [ "$EXECUTE" -eq 0 ]; then

                echo "[DRY-RUN] Akan menghapus CT $VMID"

                continue

            fi


            # ------------------------------------------------
            # Pastikan CT masih ada
            # ------------------------------------------------

            if ! pct status "$VMID" >/dev/null 2>&1; then

                echo "CT $VMID sudah tidak ditemukan."

                continue

            fi


            # ------------------------------------------------
            # Hilangkan protection
            # ------------------------------------------------

            echo "Menonaktifkan protection..."

            pct set "$VMID" \
                --protection 0 \
                >/dev/null 2>&1 || true


            # ------------------------------------------------
            # Cek status
            # ------------------------------------------------

            STATUS=$(

                pct status "$VMID" 2>/dev/null \
                    | awk '{print $2}'

            )


            # ------------------------------------------------
            # Stop jika running
            # ------------------------------------------------

            if [ "$STATUS" = "running" ]; then

                echo "Menghentikan CT $VMID..."

                if ! pct stop "$VMID"; then

                    echo
                    echo "ERROR:"
                    echo "Tidak dapat menghentikan CT $VMID."
                    echo "CT tidak dihapus."
                    echo

                    TOTAL_GAGAL=$((TOTAL_GAGAL + 1))

                    continue

                fi

            fi


            # ------------------------------------------------
            # Destroy
            # ------------------------------------------------

            echo "Menghapus CT $VMID..."

            if pct destroy "$VMID" --purge; then

                echo "OK: CT $VMID berhasil dihapus."

                TOTAL_CT=$((TOTAL_CT + 1))

            else

                echo
                echo "ERROR:"
                echo "Gagal menghapus CT $VMID."
                echo

                TOTAL_GAGAL=$((TOTAL_GAGAL + 1))

            fi

        done


        # ====================================================
        # DRY RUN
        # ====================================================

        if [ "$EXECUTE" -eq 0 ]; then

            echo
            echo "[DRY-RUN] Akan memeriksa apakah pool sudah kosong."
            echo "[DRY-RUN] Jika kosong, pool akan dihapus."
            echo "[DRY-RUN] User kemudian akan dihapus."

            continue

        fi


        # ====================================================
        # BACA ULANG POOL SETELAH CT DIHAPUS
        # ====================================================

        if ! pool_exists "$POOL"; then

            echo "Pool sudah tidak ditemukan."

        else

            POOL_JSON=$(get_pool_json "$POOL")

            # ------------------------------------------------
            # Hitung semua member
            #
            # Tidak hanya LXC.
            #
            # Ini untuk mencegah VM lain ikut terdampak.
            # ------------------------------------------------

            TOTAL_MEMBER=$(

                echo "$POOL_JSON" \
                    | jq '[.members[]?] | length'

            )


            if [ "$TOTAL_MEMBER" -gt 0 ]; then

                echo
                echo "PERINGATAN!"
                echo
                echo "Pool $POOL masih memiliki $TOTAL_MEMBER resource."
                echo
                echo "Isi pool yang tersisa:"
                echo

                echo "$POOL_JSON" \
                    | jq -r '
                        .members[]?
                        | "    type=\(.type) vmid=\(.vmid) name=\(.name // "-")"
                    '

                echo
                echo "Demi keamanan:"
                echo
                echo "  - Pool TIDAK dihapus"
                echo "  - User TIDAK dihapus"
                echo

                TOTAL_GAGAL=$((TOTAL_GAGAL + 1))

                continue

            fi


            # =================================================
            # HAPUS POOL
            # =================================================

            echo
            echo "Menghapus pool $POOL..."

            if pveum pool delete "$POOL"; then

                echo "OK: Pool $POOL berhasil dihapus."

                TOTAL_POOL=$((TOTAL_POOL + 1))

            else

                echo
                echo "ERROR:"
                echo "Pool $POOL gagal dihapus."
                echo "User tidak akan dihapus."
                echo

                TOTAL_GAGAL=$((TOTAL_GAGAL + 1))

                continue

            fi

        fi


    else

        echo
        echo "Pool tidak ditemukan."

    fi


    # ========================================================
    # HAPUS USER
    # ========================================================

    if user_exists "$USERID"; then

        if [ "$EXECUTE" -eq 0 ]; then

            echo "[DRY-RUN] Akan menghapus user: $USERID"

        else

            echo
            echo "Menghapus user $USERID..."

            if pveum user delete "$USERID"; then

                echo "OK: User $USERID berhasil dihapus."

                TOTAL_USER=$((TOTAL_USER + 1))

            else

                echo
                echo "ERROR:"
                echo "Gagal menghapus user $USERID."
                echo

                TOTAL_GAGAL=$((TOTAL_GAGAL + 1))

            fi

        fi

    else

        echo "User sudah tidak ditemukan."

    fi

done


# ============================================================
# PASSWORD FILE
# ============================================================

echo
echo
echo "============================================================"
echo " FILE PASSWORD"
echo "============================================================"

if [ -f "$PASSWORD_FILE" ]; then

    if [ "$EXECUTE" -eq 0 ]; then

        echo
        echo "[DRY-RUN] Akan menghapus:"
        echo
        echo "    $PASSWORD_FILE"

    else

        echo
        echo "Menghapus $PASSWORD_FILE..."

        if rm -f "$PASSWORD_FILE"; then

            echo "OK: file password dihapus."

        else

            echo "ERROR: gagal menghapus file password."
            TOTAL_GAGAL=$((TOTAL_GAGAL + 1))

        fi

    fi

else

    echo
    echo "File password tidak ditemukan."

fi


# ============================================================
# OPTIONAL: HAPUS CUSTOM ROLE
# ============================================================

if [ "$DELETE_ROLES" -eq 1 ]; then

    echo
    echo
    echo "============================================================"
    echo " CUSTOM ROLE LAB"
    echo "============================================================"


    for ROLE in "${ROLE_LIST[@]}"
    do

        if role_exists "$ROLE"; then

            if [ "$EXECUTE" -eq 0 ]; then

                echo
                echo "[DRY-RUN] Akan mencoba menghapus role:"
                echo
                echo "    $ROLE"

            else

                echo
                echo "Menghapus role $ROLE..."

                if pveum role delete "$ROLE"; then

                    echo "OK: $ROLE dihapus."

                else

                    echo "PERINGATAN:"
                    echo "$ROLE tidak dapat dihapus."
                    echo "Kemungkinan masih digunakan ACL lain."

                    TOTAL_GAGAL=$((TOTAL_GAGAL + 1))

                fi

            fi

        else

            echo
            echo "Role tidak ditemukan: $ROLE"

        fi

    done

fi


# ============================================================
# HASIL
# ============================================================

echo
echo
echo "============================================================"

if [ "$EXECUTE" -eq 0 ]; then

    echo " DRY-RUN SELESAI"

else

    echo " CLEANUP SELESAI"

fi

echo "============================================================"


if [ "$EXECUTE" -eq 0 ]; then

    echo
    echo "BELUM ADA DATA YANG DIHAPUS."
    echo
    echo "Periksa daftar di atas."
    echo
    echo "Jika sudah benar, jalankan:"
    echo
    echo "    $0 --execute"

    echo
    echo "Jika sekaligus ingin menghapus seluruh custom role Lab:"
    echo
    echo "    $0 --execute --delete-roles"

else

    echo
    echo "Container dihapus : $TOTAL_CT"
    echo "Pool dihapus      : $TOTAL_POOL"
    echo "User dihapus      : $TOTAL_USER"
    echo "Peringatan/gagal  : $TOTAL_GAGAL"

fi

echo
echo "============================================================"
echo
