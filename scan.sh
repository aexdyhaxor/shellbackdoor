#!/bin/bash
# ======================================================
# Script        : scan-dan-hapus.sh
# Author        : Smoky
# Tanggal       : 22 Juli 2025
# Deskripsi     : Mencari file yang mengandung string backdoor tertentu
#                 lalu otomatis menghapus file tersebut dan mencatat log-nya.
# ======================================================

# String yang mau dicari
TARGET="https://ampnih.xyz/beckdoor/bulix.txt"

# Lokasi folder yang mau discan (isi sesuai path lu dmana)
BASE_DIR="/home/innovas1"

# File list hasil pencarian
OUTPUT_LIST="smoky.txt"

# Langkah 1: cari dan simpan file yang mengandung string
echo "[+] Mencari file yang mengandung: $TARGET"
grep -rl "$TARGET" "$BASE_DIR" > "$OUTPUT_LIST"

# Cek kalau file list kosong
if [ ! -s "$OUTPUT_LIST" ]; then
    echo "[!] Tidak ditemukan file yang mengandung string tersebut."
    exit 0
fi

# Langkah 2: hapus semua file yang ditemukan
echo "[+] Menghapus file yang ditemukan..."
while read -r file; do
    echo "Menghapus: $file"
    rm -f "$file"
done < "$OUTPUT_LIST"

echo "[+] Selesai. File yang dihapus dicatat di: $OUTPUT_LIST"
