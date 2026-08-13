# Panduan Lab Siswa Proxmox VE 9.x

Panduan ini menjelaskan penggunaan dua skrip:

- `setup-siswa-proxmox.sh` — membuat akun siswa, resource pool, dan ACL yang diperlukan agar setiap siswa dapat membuat serta mengelola container LXC miliknya sendiri.
- `hapus-siswa-proxmox.sh` — membersihkan container, resource pool, akun siswa, file password, dan secara opsional custom role yang dibuat untuk lab.

> **Perhatian:** Jalankan kedua skrip sebagai `root` pada host Proxmox VE.  
> Skrip penghapusan dapat menghapus container beserta seluruh data di dalamnya secara permanen.

---

## 1. Tujuan Konfigurasi

Konfigurasi ini dibuat agar:

- setiap siswa memiliki akun Proxmox sendiri;
- setiap siswa memiliki resource pool sendiri;
- siswa dapat membuat LXC Container dari template yang disediakan administrator;
- siswa hanya dapat mengelola container yang berada di pool miliknya;
- siswa tidak dapat mengakses container siswa lain;
- siswa dapat menggunakan storage `local-lvm`;
- siswa dapat memilih bridge `vmbr0`;
- siswa tidak diberi hak administrator terhadap host Proxmox.

Contoh:

```text
siswa01@pve
└── pool-siswa01
    ├── CT 101
    └── CT 102

siswa02@pve
└── pool-siswa02
    └── CT 103
```

---

# 2. Persyaratan

Sebelum menjalankan skrip, pastikan:

- Proxmox VE 9.x sudah terpasang;
- login sebagai `root`;
- storage template tersedia, default: `local`;
- storage container tersedia, default: `local-lvm`;
- bridge jaringan tersedia, default: `vmbr0`;
- template LXC yang akan digunakan siswa sudah diunduh oleh administrator.

Cek versi Proxmox:

```bash
pveversion
```

Cek storage:

```bash
pvesm status
```

Cek bridge:

```bash
ip -br link
```

Cek template LXC:

```bash
pveam list local
```

Jika belum ada template:

```bash
pveam update
pveam available
```

Contoh mengunduh template:

```bash
pveam download local debian-13-standard_13.1-1_amd64.tar.zst
```

Nama template dapat berubah sesuai repository Proxmox yang tersedia saat itu.

---

# 3. File yang Digunakan

Letakkan kedua skrip di:

```text
/root/setup-siswa-proxmox.sh
/root/hapus-siswa-proxmox.sh
```

File password siswa akan dibuat otomatis di:

```text
/root/password-siswa-proxmox.csv
```

Permission file password dibuat terbatas untuk root.

---

# 4. Konfigurasi `setup-siswa-proxmox.sh`

Bagian konfigurasi utama:

```bash
JUMLAH_SISWA=30

USER_PREFIX="siswa"
REALM="pve"

TEMPLATE_STORAGE="local"
CT_STORAGE="local-lvm"

BRIDGE="vmbr0"

PASSWORD_FILE="/root/password-siswa-proxmox.csv"
```

Jika jumlah siswa 36:

```bash
JUMLAH_SISWA=36
```

Hasil akun:

```text
siswa01@pve
siswa02@pve
...
siswa36@pve
```

Hasil pool:

```text
pool-siswa01
pool-siswa02
...
pool-siswa36
```

---

# 5. Custom Role yang Dibuat

Skrip membuat role berikut:

```text
LabStudentCT
LabTemplateRead
LabCTStorage
LabNodeView
LabNetworkAudit
LabNetworkUse
```

## `LabStudentCT`

Hak untuk mengelola container dalam pool milik siswa:

```text
Pool.Audit
VM.Allocate
VM.Audit
VM.Console
VM.PowerMgmt
VM.Config.CPU
VM.Config.Memory
VM.Config.Network
VM.Config.Disk
VM.Config.Options
```

`Pool.Audit` diperlukan agar nama resource pool muncul pada wizard **Create CT**.

## `LabTemplateRead`

```text
Datastore.Audit
```

Digunakan agar siswa dapat melihat template yang tersedia di storage `local`.

Siswa tidak diberikan hak upload template.

## `LabCTStorage`

```text
Datastore.Audit
Datastore.AllocateSpace
```

Digunakan agar siswa dapat membuat root filesystem container pada `local-lvm`.

## `LabNodeView`

```text
Sys.Audit
```

Digunakan agar node Proxmox dapat terlihat pada GUI.

## `LabNetworkAudit`

```text
SDN.Audit
```

Digunakan agar local network dapat terlihat pada wizard pembuatan container.

## `LabNetworkUse`

```text
SDN.Use
```

Digunakan agar siswa dapat memakai bridge `vmbr0`.

---

# 6. ACL Siswa

Contoh permission untuk `siswa01@pve`:

```text
/nodes
    Sys.Audit

/pool/pool-siswa01
    Pool.Audit
    VM.Allocate
    VM.Audit
    VM.Console
    VM.PowerMgmt
    VM.Config.CPU
    VM.Config.Memory
    VM.Config.Network
    VM.Config.Disk
    VM.Config.Options

/storage/local
    Datastore.Audit

/storage/local-lvm
    Datastore.Audit
    Datastore.AllocateSpace

/sdn/zones/localnetwork
    SDN.Audit

/sdn/zones/localnetwork/vmbr0
    SDN.Use
```

Dengan konfigurasi ini, `siswa01` tidak memiliki akses ke:

```text
/pool/pool-siswa02
/pool/pool-siswa03
...
```

---

# 7. Menjalankan `setup-siswa-proxmox.sh`

Beri permission executable:

```bash
chmod +x /root/setup-siswa-proxmox.sh
```

Jalankan:

```bash
/root/setup-siswa-proxmox.sh
```

Skrip akan:

1. memeriksa Proxmox;
2. memeriksa storage;
3. memeriksa bridge;
4. membuat atau memperbarui custom role;
5. membuat akun siswa;
6. membuat resource pool masing-masing siswa;
7. memberikan ACL pool;
8. memberikan ACL template;
9. memberikan ACL storage;
10. memberikan ACL node;
11. memberikan ACL network;
12. menyimpan password akun baru ke file CSV.

---

# 8. Melihat Password Siswa

Setelah setup selesai:

```bash
cat /root/password-siswa-proxmox.csv
```

Contoh:

```csv
username,password,pool
siswa01@pve,6e98bd45a83140aa,pool-siswa01
siswa02@pve,776354ad25ac31e2,pool-siswa02
```

Simpan file ini dengan aman.

Cek permission:

```bash
ls -l /root/password-siswa-proxmox.csv
```

---

# 9. Login Siswa

Buka:

```text
https://IP-PROXMOX:8006
```

Contoh:

```text
Username : siswa01
Password : password dari CSV
Realm    : Proxmox VE authentication server
```

Jika ditulis lengkap:

```text
siswa01@pve
```

---

# 10. Membuat Container sebagai Siswa

Klik:

```text
Create CT
```

## General

Contoh:

```text
Node                 : pve1
CT ID                : otomatis
Hostname             : debian-siswa01
Unprivileged         : aktif
Resource Pool        : pool-siswa01
```

Pastikan **Resource Pool** tidak kosong.

Untuk `siswa01`, seharusnya hanya muncul:

```text
pool-siswa01
```

## Template

Pilih template pada storage:

```text
local
```

## Disks

Pilih:

```text
Storage : local-lvm
```

Contoh:

```text
Disk size : 8 GB
```

## CPU

Contoh:

```text
Cores : 1
```

## Memory

Contoh:

```text
Memory : 1024 MB
Swap   : 512 MB
```

## Network

Pilih:

```text
Bridge : vmbr0
```

Contoh:

```text
IPv4 : DHCP
```

## Confirm

Sebelum klik **Finish**, periksa bahwa ada:

```text
pool     pool-siswa01
rootfs   local-lvm:8
net0     name=eth0,bridge=vmbr0,...
```

Lalu klik:

```text
Finish
```

---

# 11. Memeriksa Permission Siswa

Contoh:

```bash
pveum user permissions siswa01@pve
```

Cek bagian pool:

```bash
pveum user permissions siswa01@pve | grep -A15 pool-siswa01
```

Cek network:

```bash
pveum user permissions siswa01@pve | grep -i sdn
```

Cek ACL langsung:

```bash
pveum acl list | grep siswa01
```

---

# 12. Jika Resource Pool Tidak Muncul

Pastikan role `LabStudentCT` memiliki:

```text
Pool.Audit
```

Cek:

```bash
pveum role list | grep LabStudentCT
```

Jika perlu:

```bash
pveum role modify LabStudentCT \
-privs "Pool.Audit VM.Allocate VM.Audit VM.Console VM.PowerMgmt VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Disk VM.Config.Options"
```

Logout akun siswa dari GUI, lalu login kembali.

---

# 13. Jika `vmbr0` Tidak Muncul

Cek bridge:

```bash
ip -br link show vmbr0
```

Cek permission:

```bash
pveum user permissions siswa01@pve | grep -i sdn
```

Seharusnya ada:

```text
/sdn/zones/localnetwork
    SDN.Audit

/sdn/zones/localnetwork/vmbr0
    SDN.Use
```

Jika permission baru saja diubah, logout siswa lalu login kembali.

---

# 14. Jika Muncul Error 403 Saat Finish

Pesan:

```text
Permission check failed (403)
```

Periksa terlebih dahulu:

```bash
pveum user permissions siswa01@pve
```

Pastikan:

```text
/pool/pool-siswa01
    Pool.Audit
    VM.Allocate
```

dan:

```text
/storage/local-lvm
    Datastore.AllocateSpace
```

serta:

```text
/sdn/zones/localnetwork/vmbr0
    SDN.Use
```

Pastikan pada tab **General** siswa memilih:

```text
Resource Pool : pool-siswa01
```

Jika resource pool kosong, pembuatan CT dapat gagal karena siswa tidak memiliki hak `VM.Allocate` global pada seluruh `/vms`.

---

# 15. Menjalankan Ulang Setup

`setup-siswa-proxmox.sh` dapat dijalankan ulang.

Jika user dan pool sudah ada:

- user tidak dibuat ulang;
- password user lama tidak diubah;
- pool tidak dibuat ulang;
- role akan diperbarui;
- ACL akan diterapkan kembali.

Ini berguna jika konfigurasi role atau permission perlu diperbaiki.

---

# 16. Menghapus Lab Siswa

Gunakan:

```text
/root/hapus-siswa-proxmox.sh
```

Script cleanup dibuat agar hanya menargetkan:

```text
siswa01@pve ... siswa30@pve
pool-siswa01 ... pool-siswa30
```

serta container LXC yang menjadi anggota pool tersebut.

---

# 17. DRY-RUN Sebelum Menghapus

Sangat disarankan menjalankan:

```bash
/root/hapus-siswa-proxmox.sh
```

Mode default adalah:

```text
DRY-RUN
```

Artinya belum ada data yang dihapus.

Script hanya menunjukkan:

- user yang akan dihapus;
- pool yang akan dihapus;
- CT yang akan dihentikan dan dihapus;
- file password yang akan dibersihkan.

Periksa output dengan teliti.

---

# 18. Menghapus Container, Pool, dan User

Jika hasil dry-run sudah benar:

```bash
/root/hapus-siswa-proxmox.sh --execute
```

Script meminta konfirmasi:

```text
Ketik HAPUS untuk melanjutkan:
```

Ketik:

```text
HAPUS
```

Urutannya:

```text
CT siswa
   ↓
stop
   ↓
destroy --purge
   ↓
cek pool kosong
   ↓
hapus pool
   ↓
hapus user
```

---

# 19. Menghapus Custom Role Sekaligus

Jika ingin menghapus seluruh konfigurasi custom role Lab:

```bash
/root/hapus-siswa-proxmox.sh --execute --delete-roles
```

Role yang akan dicoba dihapus:

```text
LabStudentCT
LabTemplateRead
LabCTStorage
LabNodeView
LabNetworkAudit
LabNetworkUse
```

Gunakan opsi ini hanya jika role tersebut tidak dipakai konfigurasi lain.

---

# 20. Pengaman pada Script Cleanup

Script cleanup sengaja dibuat konservatif.

Misalnya:

```text
pool-siswa01
├── CT 108
└── VM 900
```

Script hanya menargetkan LXC.

Setelah CT 108 dihapus, script menemukan VM 900 masih berada dalam pool.

Pada kondisi ini:

```text
pool-siswa01 TIDAK dihapus
siswa01@pve TIDAK dihapus
VM 900 TIDAK dihapus
```

Administrator harus memeriksa resource tersebut secara manual.

---

# 21. Yang Tidak Dihapus

Script cleanup tidak menghapus:

```text
vmbr0
local
local-lvm
template LXC
root@pam
user administrator lain
VM/QEMU di luar target
```

Storage dan bridge adalah bagian dari infrastruktur Proxmox dan tetap dipertahankan.

---

# 22. Melihat Daftar User

```bash
pveum user list
```

Filter siswa:

```bash
pveum user list | grep siswa
```

---

# 23. Melihat Resource Pool

```bash
pveum pool list
```

Contoh:

```text
pool-siswa01
pool-siswa02
pool-siswa03
```

---

# 24. Melihat Container

```bash
pct list
```

Cek salah satu container:

```bash
pct status 108
```

---

# 25. Struktur Akhir Lab

```text
Proxmox VE 9.x
│
├── Administrator
│   └── root@pam
│
├── siswa01@pve
│   └── pool-siswa01
│       ├── CT 101
│       └── CT 102
│
├── siswa02@pve
│   └── pool-siswa02
│       └── CT 103
│
└── siswa30@pve
    └── pool-siswa30
```

Resource bersama:

```text
Template : local
Disk     : local-lvm
Bridge   : vmbr0
```

---

# 26. Batasan Konfigurasi Saat Ini

Konfigurasi ACL ini membatasi **akses antar siswa**, tetapi belum membatasi kuota seperti:

- maksimal jumlah CT per siswa;
- maksimal CPU;
- maksimal RAM;
- maksimal disk;
- batas bandwidth;
- batas VLAN tertentu.

Artinya siswa masih dapat mencoba meminta resource yang cukup besar selama host mengizinkannya.

Untuk lingkungan kelas produksi, sebaiknya administrator menentukan kebijakan resource tambahan.

---

# 27. Workflow Praktikum yang Disarankan

Sebelum praktikum:

```bash
/root/setup-siswa-proxmox.sh
```

Guru membagikan akun dari:

```bash
cat /root/password-siswa-proxmox.csv
```

Siswa:

```text
Login
  ↓
Create CT
  ↓
pilih pool sendiri
  ↓
pilih template
  ↓
pilih local-lvm
  ↓
pilih vmbr0
  ↓
Finish
```

Setelah praktikum selesai:

```bash
/root/hapus-siswa-proxmox.sh
```

Periksa dry-run.

Kemudian:

```bash
/root/hapus-siswa-proxmox.sh --execute
```

Jika seluruh custom role juga ingin dibersihkan:

```bash
/root/hapus-siswa-proxmox.sh --execute --delete-roles
```

---

# 28. Catatan Keamanan

- Jangan memberikan role `Administrator` kepada siswa.
- Jangan memberikan `Sys.Modify` kepada siswa.
- Jangan memberikan `VM.Allocate` global pada `/vms`.
- Hak `VM.Allocate` sebaiknya hanya diberikan pada pool masing-masing.
- Jangan memberikan hak upload template jika siswa hanya perlu memakai template yang disediakan.
- Gunakan unprivileged container untuk praktik siswa.
- Jalankan dry-run sebelum melakukan cleanup.
- Lakukan backup jika container menyimpan data penting.

---

## Ringkasan Perintah

Setup:

```bash
chmod +x /root/setup-siswa-proxmox.sh
/root/setup-siswa-proxmox.sh
```

Lihat password:

```bash
cat /root/password-siswa-proxmox.csv
```

Cek permission:

```bash
pveum user permissions siswa01@pve
```

Dry-run cleanup:

```bash
chmod +x /root/hapus-siswa-proxmox.sh
/root/hapus-siswa-proxmox.sh
```

Cleanup:

```bash
/root/hapus-siswa-proxmox.sh --execute
```

Cleanup beserta custom role:

```bash
/root/hapus-siswa-proxmox.sh --execute --delete-roles
```
