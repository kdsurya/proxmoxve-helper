# Panduan Pemula: Lab Siswa dengan Proxmox VE 9.x

Panduan ini dibuat untuk pengguna yang **masih baru menggunakan Proxmox VE**, termasuk yang belum terbiasa dengan:

- antarmuka web Proxmox;
- istilah seperti **Node, Storage, Resource Pool, CT, LXC, Bridge, ACL, Role**;
- terminal Linux;
- menjalankan skrip Bash;
- membuat dan menghapus container melalui Proxmox.

Panduan menggunakan dua skrip:

```text
setup-siswa-proxmox.sh
hapus-siswa-proxmox.sh
```

Fungsi keduanya:

```text
setup-siswa-proxmox.sh
    ↓
membuat akun siswa
    ↓
membuat pool masing-masing siswa
    ↓
memberikan hak akses yang diperlukan
    ↓
siswa dapat membuat LXC sendiri


hapus-siswa-proxmox.sh
    ↓
menghapus LXC siswa
    ↓
menghapus pool siswa
    ↓
menghapus akun siswa
    ↓
mengembalikan lab menjadi bersih
```

---

# 1. Gambaran Sistem yang Akan Dibuat

Misalnya terdapat 30 siswa.

Skrip akan membuat:

```text
siswa01@pve
siswa02@pve
siswa03@pve
...
siswa30@pve
```

Masing-masing siswa mendapat Resource Pool sendiri:

```text
pool-siswa01
pool-siswa02
pool-siswa03
...
pool-siswa30
```

Contoh hasilnya:

```text
Proxmox VE
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
└── siswa03@pve
    └── pool-siswa03
        └── CT 104
```

Tujuan utamanya adalah:

```text
siswa01
hanya boleh mengakses
pool-siswa01

siswa02
hanya boleh mengakses
pool-siswa02
```

Dengan demikian siswa tidak dapat mengelola container milik siswa lain.

---

# 2. Istilah Dasar Proxmox yang Perlu Dipahami

Sebelum mulai, kenali beberapa istilah berikut.

## Node

**Node** adalah komputer/server yang menjalankan Proxmox VE.

Contoh nama node:

```text
pve1
```

Di tampilan web Proxmox biasanya terlihat pada sisi kiri:

```text
Datacenter
└── pve1
```

---

## CT / LXC Container

CT adalah singkatan dari:

```text
Container
```

Proxmox menggunakan teknologi **LXC** untuk container Linux.

Contohnya:

```text
CT 101
CT 102
CT 108
```

Container lebih ringan dibanding VM biasa.

---

## VM

VM adalah Virtual Machine berbasis QEMU/KVM.

Contohnya:

```text
VM 200
VM 201
```

Panduan ini berfokus pada **LXC Container**, bukan VM.

---

## Storage

Storage adalah tempat Proxmox menyimpan data.

Pada instalasi Proxmox standar biasanya tersedia:

```text
local
local-lvm
```

Dalam panduan ini:

```text
local
```

digunakan untuk menyimpan template LXC.

Sedangkan:

```text
local-lvm
```

digunakan untuk menyimpan disk/root filesystem container siswa.

---

## Template

Template adalah sistem operasi dasar yang dipakai untuk membuat LXC.

Contoh:

```text
Debian
Ubuntu
Alpine
```

Siswa hanya boleh memilih template yang sudah disediakan administrator.

---

## Resource Pool

Resource Pool adalah kelompok resource di Proxmox.

Dalam lab ini setiap siswa mempunyai satu pool.

Contoh:

```text
pool-siswa01
```

Semua container siswa01 harus dimasukkan ke pool tersebut.

---

## Bridge

Bridge adalah interface jaringan virtual Proxmox.

Dalam panduan ini digunakan:

```text
vmbr0
```

Container siswa akan terhubung ke jaringan melalui bridge ini.

---

## User

User adalah akun untuk login ke Proxmox.

Contoh:

```text
siswa01@pve
```

Bagian:

```text
@pve
```

menunjukkan bahwa akun menggunakan:

```text
Proxmox VE Authentication Server
```

---

## Role

Role adalah kumpulan hak akses.

Contoh role yang digunakan:

```text
LabStudentCT
LabTemplateRead
LabCTStorage
LabNodeView
LabNetworkAudit
LabNetworkUse
```

---

## ACL

ACL adalah aturan yang menentukan:

```text
siapa
boleh melakukan apa
pada resource mana
```

Contohnya:

```text
siswa01@pve

boleh mengelola

/pool/pool-siswa01
```

tetapi tidak diberikan hak pada:

```text
/pool/pool-siswa02
```

---

# 3. Mengenal Tampilan Web Proxmox

Buka browser pada komputer administrator.

Masukkan alamat:

```text
https://IP-PROXMOX:8006
```

Contoh:

```text
https://192.168.1.10:8006
```

Browser mungkin menampilkan peringatan sertifikat.

Untuk lab lokal, pilih opsi untuk melanjutkan ke halaman Proxmox.

Kemudian login.

Biasanya:

```text
User name : root
Password  : password root Proxmox
Realm     : Linux PAM standard authentication
```

Jika menulis lengkap:

```text
root@pam
```

---

# 4. Bagian Penting pada Web UI Proxmox

Setelah login, pada sisi kiri akan terlihat struktur seperti:

```text
Datacenter
└── pve1
    ├── local
    └── local-lvm
```

## Datacenter

Klik:

```text
Datacenter
```

untuk mengatur:

- Users;
- Groups;
- Permissions;
- Pools;
- HA;
- SDN;
- konfigurasi tingkat cluster.

---

## Node

Klik:

```text
pve1
```

untuk melihat:

- Summary;
- Shell;
- Network;
- Disks;
- System;
- Updates.

---

## Shell

Untuk membuka terminal langsung dari browser:

1. Klik node, misalnya:

```text
pve1
```

2. Pilih:

```text
Shell
```

Terminal akan muncul di browser.

Semua perintah pada panduan ini dapat dijalankan dari menu **Shell** tersebut.

Jadi pengguna pemula **tidak wajib menggunakan SSH dari komputer lain**.

---

# 5. Persiapan Sebelum Menjalankan Skrip

Pastikan:

- Proxmox VE 9.x sudah berjalan;
- Anda login sebagai `root@pam`;
- storage `local` tersedia;
- storage `local-lvm` tersedia;
- bridge `vmbr0` tersedia;
- minimal satu template LXC sudah tersedia.

---

# 6. Mengecek Storage Melalui Web UI

Pada sisi kiri klik:

```text
Datacenter
└── pve1
```

Biasanya akan terlihat:

```text
local (pve1)
local-lvm (pve1)
```

Jika keduanya ada, konfigurasi default script kemungkinan dapat digunakan.

---

# 7. Mengecek Storage dari Terminal

Buka:

```text
pve1
→ Shell
```

Jalankan:

```bash
pvesm status
```

Contoh:

```text
Name       Type     Status
local      dir      active
local-lvm  lvmthin  active
```

Yang penting adalah:

```text
local
local-lvm
```

berstatus aktif.

---

# 8. Mengecek Bridge vmbr0 dari Web UI

Klik:

```text
pve1
→ System
→ Network
```

Cari:

```text
vmbr0
```

Jika ada, berarti bridge tersedia.

---

# 9. Mengecek Bridge dari Terminal

Jalankan:

```bash
ip -br link show vmbr0
```

Contoh:

```text
vmbr0    UP
```

Jika `vmbr0` tidak ada, jangan jalankan setup dahulu sebelum konfigurasi network diperiksa.

---

# 10. Menyiapkan Template LXC dari Web UI

Administrator harus menyediakan template terlebih dahulu.

Klik:

```text
pve1
→ local
→ CT Templates
```

Kemudian klik:

```text
Templates
```

Akan muncul daftar template.

Contoh:

```text
Debian
Ubuntu
Alpine
```

Pilih salah satu, kemudian klik:

```text
Download
```

Tunggu hingga proses selesai.

---

# 11. Menyiapkan Template dari Terminal

Alternatif melalui terminal:

```bash
pveam update
```

Lihat daftar:

```bash
pveam available
```

Cari Debian:

```bash
pveam available | grep debian
```

Kemudian download sesuai nama template yang tersedia.

Contoh:

```bash
pveam download local debian-13-standard_13.1-1_amd64.tar.zst
```

Nama versi dapat berubah mengikuti repository Proxmox.

---

# 12. Dua Skrip yang Digunakan

Letakkan file berikut pada:

```text
/root/setup-siswa-proxmox.sh
/root/hapus-siswa-proxmox.sh
```

---

# 13. Cara Membuat File Skrip untuk Pemula

Buka:

```text
pve1
→ Shell
```

Kemudian:

```bash
nano /root/setup-siswa-proxmox.sh
```

Tempel isi skrip setup.

Untuk menyimpan di Nano:

```text
Ctrl + O
```

tekan:

```text
Enter
```

kemudian keluar:

```text
Ctrl + X
```

Lakukan hal yang sama untuk script cleanup:

```bash
nano /root/hapus-siswa-proxmox.sh
```

---

# 14. Memberikan Hak Eksekusi pada Skrip

Setelah kedua file dibuat:

```bash
chmod +x /root/setup-siswa-proxmox.sh
```

dan:

```bash
chmod +x /root/hapus-siswa-proxmox.sh
```

Cek:

```bash
ls -l /root/*siswa-proxmox.sh
```

---

# 15. Konfigurasi Utama Script Setup

Pada awal `setup-siswa-proxmox.sh` terdapat:

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

Jika hanya 10 siswa:

```bash
JUMLAH_SISWA=10
```

---

# 16. Menjalankan Setup

Jalankan:

```bash
/root/setup-siswa-proxmox.sh
```

Script akan otomatis:

1. memeriksa command Proxmox;
2. memeriksa storage;
3. memeriksa bridge;
4. membuat custom role;
5. membuat user siswa;
6. membuat Resource Pool;
7. memasang ACL;
8. membuat file password.

---

# 17. Custom Role yang Dibuat

Skrip membuat:

```text
LabStudentCT
LabTemplateRead
LabCTStorage
LabNodeView
LabNetworkAudit
LabNetworkUse
```

Fungsinya:

| Role | Fungsi |
|---|---|
| `LabStudentCT` | membuat dan mengelola CT di pool sendiri |
| `LabTemplateRead` | melihat template |
| `LabCTStorage` | membuat rootfs/disk CT |
| `LabNodeView` | melihat node |
| `LabNetworkAudit` | melihat jaringan/bridge |
| `LabNetworkUse` | memakai `vmbr0` |

---

# 18. Permission Penting yang Digunakan

Untuk CT:

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

Untuk template:

```text
Datastore.Audit
```

Untuk storage:

```text
Datastore.Audit
Datastore.AllocateSpace
```

Untuk node:

```text
Sys.Audit
```

Untuk bridge:

```text
SDN.Audit
SDN.Use
```

---

# 19. Kenapa Pool.Audit Penting?

Tanpa:

```text
Pool.Audit
```

dropdown **Resource Pool** pada wizard `Create CT` dapat kosong.

Akibatnya siswa tidak dapat memilih:

```text
pool-siswa01
```

dan pembuatan container dapat berakhir:

```text
Permission check failed (403)
```

---

# 20. Kenapa SDN.Audit dan SDN.Use Penting?

Tanpa hak tersebut, pilihan bridge:

```text
vmbr0
```

dapat tidak muncul pada tab:

```text
Create CT
→ Network
```

Konfigurasi yang digunakan:

```text
/sdn/zones/localnetwork
    SDN.Audit

/sdn/zones/localnetwork/vmbr0
    SDN.Use
```

---

# 21. Melihat Hasil Setup dari Web UI

Setelah script selesai, refresh browser Proxmox.

Kemudian klik:

```text
Datacenter
→ Permissions
→ Users
```

Anda seharusnya melihat:

```text
siswa01@pve
siswa02@pve
...
siswa30@pve
```

---

# 22. Melihat Resource Pool dari Web UI

Klik:

```text
Datacenter
→ Permissions
→ Pools
```

atau menu pool yang tersedia pada versi Proxmox Anda.

Akan terlihat:

```text
pool-siswa01
pool-siswa02
...
pool-siswa30
```

---

# 23. Melihat Password Siswa

Di Shell:

```bash
cat /root/password-siswa-proxmox.csv
```

Contoh:

```csv
username,password,pool
siswa01@pve,112233aabbccdd44,pool-siswa01
siswa02@pve,aabbcc1122334455,pool-siswa02
```

File ini bersifat sensitif.

Jangan dibagikan seluruh isinya kepada semua siswa.

Berikan masing-masing siswa hanya akun miliknya.

---

# 24. Cara Login Sebagai Siswa

Logout dari akun root.

Buka halaman Proxmox:

```text
https://IP-PROXMOX:8006
```

Login contoh:

```text
User name : siswa01
Password  : sesuai CSV
Realm     : Proxmox VE authentication server
```

Atau jika menggunakan format lengkap:

```text
siswa01@pve
```

---

# 25. Tampilan yang Diharapkan untuk Siswa

Siswa tidak akan melihat seluruh resource seperti administrator.

Hal ini normal.

Siswa hanya melihat resource yang memang diberikan permission.

Tujuannya agar:

```text
siswa01
tidak melihat/mengelola
CT milik siswa02
```

---

# 26. Panduan Membuat LXC untuk Siswa

Setelah login sebagai siswa klik tombol:

```text
Create CT
```

Biasanya berada di kanan atas antarmuka Proxmox.

Wizard akan terdiri dari:

```text
General
Template
Disks
CPU
Memory
Network
DNS
Confirm
```

---

# 27. Tab General

Contoh:

```text
Node:
pve1
```

CT ID biasanya sudah otomatis.

Contoh:

```text
CT ID:
108
```

Hostname:

```text
debian-siswa01
```

Pastikan:

```text
Unprivileged container
```

aktif.

Resource Pool harus dipilih:

```text
pool-siswa01
```

Untuk siswa01 seharusnya tidak muncul pool siswa lain.

Password adalah password root **di dalam container**, bukan password login Proxmox.

Contoh:

```text
Password:
PasswordContainer123!
```

---

# 28. Tentang Nesting

Pada halaman General dapat muncul:

```text
Nesting
```

Untuk praktik dasar, nesting tidak wajib.

Jika tidak diperlukan, biarkan tidak dicentang.

Nesting biasanya diperlukan jika container akan menjalankan teknologi tertentu yang membutuhkan namespace tambahan.

---

# 29. Tab Template

Pilih storage:

```text
local
```

Kemudian pilih template yang disediakan guru.

Contoh:

```text
debian-13-standard
```

---

# 30. Tab Disks

Pilih:

```text
Storage:
local-lvm
```

Contoh ukuran:

```text
8 GB
```

Untuk praktikum ringan biasanya 8–16 GB sudah cukup, tergantung kebutuhan.

---

# 31. Tab CPU

Contoh:

```text
Cores:
1
```

atau:

```text
2
```

Jangan memberikan resource terlalu besar jika server digunakan banyak siswa.

---

# 32. Tab Memory

Contoh:

```text
Memory:
1024 MB

Swap:
512 MB
```

Untuk container sederhana, 512 MB sampai 2 GB biasanya cukup tergantung aplikasi.

---

# 33. Tab Network

Pada:

```text
Name
```

biarkan:

```text
eth0
```

Pada:

```text
Bridge
```

pilih:

```text
vmbr0
```

Untuk IPv4, jika jaringan menyediakan DHCP:

```text
DHCP
```

dapat dipilih.

Jika menggunakan IP statis, isi sesuai jaringan sekolah/lab.

---

# 34. Tab DNS

Untuk pemula biasanya dapat menggunakan konfigurasi default.

Jika perlu, isi DNS server sesuai jaringan.

Contoh:

```text
8.8.8.8
```

atau DNS lokal sekolah.

---

# 35. Tab Confirm

Ini adalah tahap penting.

Periksa bahwa ada:

```text
pool      pool-siswa01
```

Kemudian:

```text
rootfs    local-lvm:...
```

Dan network mengandung:

```text
bridge=vmbr0
```

Contoh:

```text
net0:
name=eth0,bridge=vmbr0,...
```

Jika semuanya benar, klik:

```text
Finish
```

---

# 36. Setelah Container Dibuat

Container akan muncul pada panel kiri.

Klik CT tersebut.

Contoh:

```text
108 (debian-siswa01)
```

Menu yang sering digunakan:

```text
Summary
Console
Resources
Network
DNS
Options
```

---

# 37. Menyalakan Container

Klik container, kemudian:

```text
Start
```

Tunggu beberapa detik.

Status akan berubah menjadi:

```text
running
```

---

# 38. Membuka Console Container

Klik:

```text
Console
```

Login menggunakan user/password Linux yang sesuai dengan template/container.

Untuk banyak template LXC, administrator menentukan password root pada wizard Create CT.

---

# 39. Mematikan Container

Klik:

```text
Shutdown
```

atau:

```text
Stop
```

Perbedaan sederhananya:

```text
Shutdown
```

meminta sistem operasi di dalam container berhenti dengan normal.

Sedangkan:

```text
Stop
```

lebih langsung.

Gunakan `Shutdown` jika memungkinkan.

---

# 40. Mengecek Permission Siswa dari Terminal

Sebagai root:

```bash
pveum user permissions siswa01@pve
```

Hasil ideal kira-kira:

```text
/nodes
    Sys.Audit

/pool/pool-siswa01
    Pool.Audit
    VM.Allocate
    VM.Audit
    VM.Config.CPU
    VM.Config.Disk
    VM.Config.Memory
    VM.Config.Network
    VM.Config.Options
    VM.Console
    VM.PowerMgmt

/sdn/zones/localnetwork
    SDN.Audit

/sdn/zones/localnetwork/vmbr0
    SDN.Use

/storage/local
    Datastore.Audit

/storage/local-lvm
    Datastore.AllocateSpace
    Datastore.Audit
```

---

# 41. Jika Resource Pool Tidak Muncul

Gejala:

```text
Create CT
→ General
→ Resource Pool
```

dropdown kosong.

Cek:

```bash
pveum user permissions siswa01@pve
```

Pastikan ada:

```text
/pool/pool-siswa01
    Pool.Audit
```

Jika tidak ada, periksa role:

```bash
pveum role list | grep LabStudentCT
```

---

# 42. Jika vmbr0 Tidak Muncul

Gejala:

```text
Create CT
→ Network
→ Bridge
```

kosong.

Cek:

```bash
pveum user permissions siswa01@pve | grep -i sdn
```

Harus terdapat:

```text
/sdn/zones/localnetwork
    SDN.Audit

/sdn/zones/localnetwork/vmbr0
    SDN.Use
```

Kemudian logout siswa dan login kembali.

---

# 43. Jika Muncul Permission Check Failed (403)

Pesan:

```text
Permission check failed (403)
```

Periksa tiga hal utama.

## A. Resource Pool

Harus ada:

```text
Resource Pool:
pool-siswa01
```

## B. Storage

Harus ada permission:

```text
Datastore.AllocateSpace
```

pada:

```text
/storage/local-lvm
```

## C. Bridge

Harus ada:

```text
SDN.Use
```

pada:

```text
/sdn/zones/localnetwork/vmbr0
```

Cek semuanya:

```bash
pveum user permissions siswa01@pve
```

---

# 44. Setelah Mengubah Permission, Login Ulang

Jika administrator baru saja mengubah role atau ACL:

1. logout akun siswa;
2. login kembali;
3. buka lagi `Create CT`.

Jangan hanya menutup wizard.

Session GUI bisa menyimpan informasi permission lama.

---

# 45. Menjalankan Setup Ulang

Script setup dapat dijalankan ulang:

```bash
/root/setup-siswa-proxmox.sh
```

Jika user sudah ada:

```text
tidak dibuat ulang
```

Jika pool sudah ada:

```text
tidak dibuat ulang
```

Role dan ACL akan diperbarui.

Ini berguna ketika melakukan perbaikan konfigurasi.

---

# 46. Sebelum Menghapus Lab

Pastikan tidak ada data siswa yang masih dibutuhkan.

Cleanup dapat menghapus:

```text
container
root filesystem
data di dalam container
```

secara permanen.

Jika ada data penting, backup terlebih dahulu.

---

# 47. Mode DRY-RUN pada Script Hapus

Jangan langsung menggunakan opsi `--execute`.

Jalankan dahulu:

```bash
/root/hapus-siswa-proxmox.sh
```

Script berada dalam mode:

```text
DRY-RUN
```

Artinya:

```text
tidak ada data yang benar-benar dihapus
```

Script hanya menunjukkan apa yang akan dihapus.

---

# 48. Contoh Output DRY-RUN

Contoh:

```text
SISWA : siswa01@pve
POOL  : pool-siswa01

Container LXC ditemukan:
    CT 108 - debian-siswa01

[DRY-RUN] Akan menghapus CT 108
[DRY-RUN] Akan menghapus pool pool-siswa01
[DRY-RUN] Akan menghapus user siswa01@pve
```

Periksa hasilnya dengan teliti.

---

# 49. Menghapus Lab Siswa

Jika dry-run sudah benar:

```bash
/root/hapus-siswa-proxmox.sh --execute
```

Akan muncul peringatan.

Script meminta:

```text
Ketik HAPUS untuk melanjutkan:
```

Ketik:

```text
HAPUS
```

---

# 50. Urutan Penghapusan

Script bekerja dengan urutan:

```text
container siswa
    ↓
stop
    ↓
destroy --purge
    ↓
cek pool
    ↓
jika kosong
    ↓
hapus pool
    ↓
hapus user
```

---

# 51. Menghapus Custom Role Sekaligus

Jika seluruh konfigurasi lab ingin dibersihkan:

```bash
/root/hapus-siswa-proxmox.sh --execute --delete-roles
```

Role berikut akan dicoba dihapus:

```text
LabStudentCT
LabTemplateRead
LabCTStorage
LabNodeView
LabNetworkAudit
LabNetworkUse
```

Gunakan opsi ini hanya jika role tersebut memang tidak dipakai untuk kelas atau konfigurasi lain.

---

# 52. Pengaman pada Script Cleanup

Misalnya secara tidak sengaja:

```text
pool-siswa01
├── CT 108
└── VM 900
```

Script hanya menghapus LXC target.

Setelah itu script melihat:

```text
VM 900
```

masih ada.

Maka:

```text
pool-siswa01 tidak dihapus
siswa01@pve tidak dihapus
VM 900 tidak dihapus
```

Ini dibuat agar resource lain tidak terhapus tanpa sengaja.

---

# 53. Resource yang Tidak Dihapus oleh Cleanup

Script tidak menghapus:

```text
vmbr0
local
local-lvm
template LXC
root@pam
user administrator lain
VM QEMU di luar target
```

---

# 54. Mengecek Apakah User Sudah Terhapus

Jalankan:

```bash
pveum user list
```

Filter:

```bash
pveum user list | grep siswa
```

Jika tidak ada hasil, berarti user siswa sudah bersih.

---

# 55. Mengecek Pool

Jalankan:

```bash
pveum pool list
```

Filter:

```bash
pveum pool list | grep pool-siswa
```

---

# 56. Mengecek Container

Jalankan:

```bash
pct list
```

Pastikan CT siswa sudah tidak ada.

---

# 57. Workflow untuk Guru/Administrator

## Sebelum praktikum

Jalankan:

```bash
/root/setup-siswa-proxmox.sh
```

Kemudian lihat akun:

```bash
cat /root/password-siswa-proxmox.csv
```

Bagikan satu akun kepada satu siswa.

---

## Saat praktikum

Siswa login.

Kemudian:

```text
Create CT
→ pilih pool sendiri
→ pilih template
→ local-lvm
→ CPU
→ Memory
→ vmbr0
→ Finish
```

---

## Setelah praktikum

Pertama:

```bash
/root/hapus-siswa-proxmox.sh
```

Periksa dry-run.

Jika benar:

```bash
/root/hapus-siswa-proxmox.sh --execute
```

---

# 58. Saran Resource untuk Praktikum Dasar

Untuk server yang dipakai banyak siswa, jangan memberikan resource terlalu besar.

Contoh awal:

```text
CPU    : 1 core
RAM    : 512 MB – 1 GB
Disk   : 8 GB
Swap   : 512 MB
```

Sesuaikan dengan kapasitas server dan jumlah siswa.

---

# 59. Hal yang Belum Dibatasi oleh Script

Script saat ini mengatur **hak akses**, bukan kuota.

Belum ada pembatasan otomatis seperti:

```text
maksimal 1 CT per siswa
maksimal 2 CPU
maksimal RAM 2 GB
maksimal disk 10 GB
```

Jadi guru tetap perlu memberikan aturan praktikum.

---

# 60. Saran Keamanan

Untuk lab siswa:

- jangan berikan role Administrator;
- jangan memberikan `Sys.Modify`;
- jangan memberikan `VM.Allocate` global pada `/vms`;
- gunakan unprivileged container;
- template dikelola administrator;
- siswa hanya menggunakan pool masing-masing;
- siswa hanya menggunakan bridge yang ditentukan;
- lakukan cleanup setelah praktik jika container tidak lagi diperlukan;
- lakukan dry-run sebelum cleanup.

---

# 61. Perintah Cepat

## Setup

```bash
chmod +x /root/setup-siswa-proxmox.sh
/root/setup-siswa-proxmox.sh
```

## Lihat password

```bash
cat /root/password-siswa-proxmox.csv
```

## Cek permission siswa

```bash
pveum user permissions siswa01@pve
```

## Lihat container

```bash
pct list
```

## Dry-run cleanup

```bash
/root/hapus-siswa-proxmox.sh
```

## Cleanup

```bash
/root/hapus-siswa-proxmox.sh --execute
```

## Cleanup + hapus custom role

```bash
/root/hapus-siswa-proxmox.sh --execute --delete-roles
```

---

# 62. Checklist Sebelum Praktikum

- [ ] Proxmox VE dapat dibuka dari browser.
- [ ] Login `root@pam` berhasil.
- [ ] Node `pve1` terlihat.
- [ ] Storage `local` aktif.
- [ ] Storage `local-lvm` aktif.
- [ ] Bridge `vmbr0` tersedia.
- [ ] Template LXC sudah tersedia.
- [ ] `setup-siswa-proxmox.sh` sudah dibuat.
- [ ] `hapus-siswa-proxmox.sh` sudah dibuat.
- [ ] Kedua script sudah executable.
- [ ] Script setup berhasil dijalankan.
- [ ] File password siswa sudah dibuat.
- [ ] Login `siswa01@pve` sudah diuji.
- [ ] `pool-siswa01` muncul.
- [ ] `vmbr0` muncul.
- [ ] Test Create CT berhasil.
- [ ] Siswa01 tidak dapat mengakses CT siswa lain.

---

# 63. Checklist Setelah Praktikum

- [ ] Data penting siswa sudah disimpan jika diperlukan.
- [ ] Dry-run cleanup sudah diperiksa.
- [ ] Tidak ada VM administrator yang masuk pool siswa.
- [ ] Cleanup dijalankan.
- [ ] User siswa sudah terhapus.
- [ ] Pool siswa sudah terhapus.
- [ ] CT siswa sudah terhapus.
- [ ] `vmbr0`, `local`, dan `local-lvm` tetap tersedia.
- [ ] Custom role dihapus hanya jika memang tidak akan digunakan lagi.

---

# 64. Ringkasan Paling Sederhana

Untuk pengguna yang benar-benar baru, urutan minimalnya adalah:

```text
1. Login ke Proxmox sebagai root@pam

2. Buka:
   pve1 → Shell

3. Pastikan template sudah ada

4. Jalankan:
   /root/setup-siswa-proxmox.sh

5. Lihat password:
   cat /root/password-siswa-proxmox.csv

6. Login sebagai siswa01

7. Klik:
   Create CT

8. Pilih:
   pool-siswa01
   local
   local-lvm
   vmbr0

9. Finish

10. Setelah praktik, sebagai root jalankan:
    /root/hapus-siswa-proxmox.sh

11. Jika dry-run benar:
    /root/hapus-siswa-proxmox.sh --execute
```

---

## Catatan Akhir

Konfigurasi ini ditujukan untuk **lab pembelajaran**, di mana administrator/guru tetap mengendalikan:

```text
node
storage
template
network
ACL
role
```

sementara siswa hanya mengelola container miliknya sendiri.

Untuk penggunaan produksi, sebaiknya tambahkan kebijakan backup, firewall, kuota resource, monitoring, dan pengamanan jaringan sesuai kebutuhan organisasi.
