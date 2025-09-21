#!/usr/bin/env bash
# audit-privesc.sh — Read-only audit untuk peluang privilege escalation (tanpa exploit)
# Fokus: sudo/suid/sgid/capabilities/PATH/cron/systemd/permissions/mount/Docker/NFS/kernel hardening vars

set -uo pipefail

START_TS="$(date +'%Y-%m-%d_%H-%M-%S')"
HOST="$(hostname -f 2>/dev/null || hostname)"
OUTDIR="/tmp/privesc_audit_${HOST}_${START_TS}"
REPORT="${OUTDIR}/report.txt"
JSON="${OUTDIR}/summary.json"
mkdir -p "$OUTDIR"

BOLD="$(tput bold 2>/dev/null || true)"; RESET="$(tput sgr0 2>/dev/null || true)"
RED="$(tput setaf 1 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
CYAN="$(tput setaf 6 2>/dev/null || true)"

log()  { echo -e "$@" | tee -a "$REPORT"; }
sec()  { log "\n${BOLD}## $*${RESET}"; }
ok()   { log "${GREEN}[OK]${RESET} $*"; }
warn() { log "${YELLOW}[WARN]${RESET} $*"; }
bad()  { log "${RED}[RISK]${RESET} $*"; }
info() { log "${CYAN}[INFO]${RESET} $*"; }

has()  { command -v "$1" >/dev/null 2>&1; }
perm() { stat -c "%A %U:%G %a %n" "$@" 2>/dev/null; }

# ---------- Header ----------
echo "===================================================" | tee "$REPORT"
echo "  PrivEsc Surface Audit (read-only)                " | tee -a "$REPORT"
echo "  Host : $HOST" | tee -a "$REPORT"
echo "  Time : $(date)" | tee -a "$REPORT"
echo "  Out  : $OUTDIR" | tee -a "$REPORT"
echo "===================================================" | tee -a "$REPORT"

# ---------- 1) System / Kernel ----------
sec "System & kernel"
OS="unknown"
if [ -r /etc/os-release ]; then . /etc/os-release; OS="${PRETTY_NAME:-$NAME}"; fi
KVER="$(uname -r)"
log "OS       : ${OS}"
log "Kernel   : $(uname -a)"
log "Arch     : $(uname -m)"
log "Uptime   : $(uptime -p 2>/dev/null || true)"
log "User     : $(id 2>/dev/null || true)"

case "$KVER" in
  2.*|3.*) warn "Kernel $KVER tergolong tua—banyak CVE historis pernah relevan. Pastikan patch/backport terbaru sudah terpasang." ;;
  4.*)     info "Kernel 4.x: tetap update; beberapa isu BPF/nftables pernah signifikan." ;;
  5.*|6.*) ok "Kernel relatif modern ($KVER)." ;;
esac

# Hardening sysctls yang berpengaruh pada eksploit lokal
sec "Kernel hardening toggles (indikatif)"
for p in \
  /proc/sys/kernel/kptr_restrict \
  /proc/sys/kernel/dmesg_restrict \
  /proc/sys/kernel/yama/ptrace_scope \
  /proc/sys/kernel/unprivileged_bpf_disabled \
  /proc/sys/user/max_user_namespaces \
  /proc/sys/fs/protected_hardlinks \
  /proc/sys/fs/protected_symlinks \
  /proc/sys/fs/protected_fifos \
  /proc/sys/fs/protected_regular; do
  [ -r "$p" ] && printf "  %-45s : %s\n" "$p" "$(cat "$p" 2>/dev/null)" | tee -a "$REPORT"
done

# ---------- 2) SELinux/AppArmor ----------
sec "MAC (SELinux/AppArmor)"
if command -v getenforce >/dev/null 2>&1; then
  ENF="$(getenforce 2>/dev/null || true)"
  log "SELinux: $ENF"
  [ "$ENF" = "Enforcing" ] && ok "SELinux Enforcing" || warn "SELinux bukan Enforcing (mode: $ENF)"
elif [ -d /sys/kernel/security/apparmor ]; then
  info "AppArmor terdeteksi (detail profil tidak diekstrak)."
else
  warn "SELinux/AppArmor tidak terdeteksi (atau tools tidak ada)."
fi

# ---------- 3) Sudo misconfig ----------
sec "Sudo configuration (surface check)"
if has sudo; then
  if sudo -n true 2>/dev/null; then
    bad "User ini dapat menjalankan sudo tanpa password untuk sebagian/perintah—cek 'sudo -l' dan batasi."
  else
    info "Sudo non-interaktif tidak diizinkan (butuh password/tiada akses)."
  fi
  [ -r /etc/sudoers ] && { perm /etc/sudoers | tee -a "$REPORT"; grep -E "NOPASSWD|!authenticate|ALL\s*=\s*\(ALL\)\s*ALL" /etc/sudoers 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"; }
  if [ -d /etc/sudoers.d ]; then
    for f in /etc/sudoers.d/*; do
      [ -f "$f" ] || continue
      perm "$f" | tee -a "$REPORT"
      grep -E "NOPASSWD|!authenticate|ALL\s*=\s*\(ALL\)\s*ALL" "$f" 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"
    done
  fi
else
  info "sudo tidak terpasang."
fi

# ---------- 4) SUID/SGID & “abusable” binaries ----------
sec "SUID/SGID binaries (indikator klasik)"
# daftar biner yang sering bisa disalahgunakan bila SUID
ABUSABLE="bash sh zsh dash vi vim nano less more cp mv chmod chown tar rsync find awk sed perl python python3 php ruby nmap mount umount env tee teehee busybox pkexec ping "
SUID_LIST="$(mktemp)"; SGID_LIST="$(mktemp)"
find / -perm -4000 -type f 2>/dev/null | sort | tee "$SUID_LIST" | head -n 70 | sed 's/^/  /' | tee -a "$REPORT" >/dev/null
log "Total SUID: $(wc -l < "$SUID_LIST" 2>/dev/null)"
find / -perm -2000 -type f 2>/dev/null | sort | tee "$SGID_LIST" | head -n 50 | sed 's/^/  /' | tee -a "$REPORT" >/dev/null
log "Total SGID: $(wc -l < "$SGID_LIST" 2>/dev/null)"

# Laporkan SUID yang cocok dengan daftar “abusable”
sec "SUID berpotensi disalahgunakan (pencocokan nama)"
while read -r p; do
  b="$(basename "$p")"
  if echo "$ABUSABLE" | grep -qw -- "$b"; then
    bad "SUID abusable: $(perm "$p")"
  fi
done < "$SUID_LIST"

# ---------- 5) File capabilities ----------
sec "File capabilities (cap_setuid/…)"
if has getcap; then
  getcap -r / 2>/dev/null | tee "${OUTDIR}/getcap.txt" >/dev/null
  head -n 200 "${OUTDIR}/getcap.txt" | sed 's/^/  /' | tee -a "$REPORT"
  grep -E "cap_setuid|cap_setgid|cap_sys_admin|cap_dac_override|cap_fowner|cap_net_admin" "${OUTDIR}/getcap.txt" 2>/dev/null \
    | sed 's/^/  [SENSITIF] /' | tee -a "$REPORT"
else
  info "getcap tidak ditemukan."
fi

# ---------- 6) PATH hijack & executable writable ----------
sec "PATH hijacking"
CURPATH="$PATH"
log "PATH: $CURPATH"
echo "$CURPATH" | grep -qE '(^|:)\.(|:|$)' && bad "PATH berisi '.' (bahaya)."
echo "$CURPATH" | grep -q '::' && warn "PATH memiliki entri kosong (::)."

# Dir PATH yang writeable & executable writeable
sec "Executable di PATH yang writeable oleh user saat ini (maks 120)"
COUNT=0
IFS=':' read -r -a P_ARR <<< "$CURPATH"
for d in "${P_ARR[@]}"; do
  [ -d "$d" ] || continue
  # Direktori PATH yang group/other-writeable
  if [ -w "$d" ] || [ -w "$(dirname "$d")" ]; then
    warn "Direktori PATH writeable: $(perm "$d")"
  fi
  while IFS= read -r -d '' f; do
    [ -w "$f" ] || continue
    echo "  $(perm "$f")" | tee -a "$REPORT"
    COUNT=$((COUNT+1)); [ $COUNT -ge 120 ] && break
  done < <(find "$d" -maxdepth 1 -type f -perm -111 -print0 2>/dev/null)
  [ $COUNT -ge 120 ] && break
done
[ $COUNT -eq 0 ] && ok "Tidak ada executable di PATH yang writeable oleh user ini."

# ---------- 7) Cron / systemd ----------
sec "Cron & systemd (writeability surface)"
log "Cron files writeable/non-root owner:"
find /etc/cron* -type f \( -perm -002 -o ! -user root \) -ls 2>/dev/null | tee -a "$REPORT"
log "User crontab (jika ada):"
crontab -l 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"

if [ -d /etc/systemd/system ]; then
  log "Unit file writeable/non-root (maxdepth 2):"
  find /etc/systemd/system -maxdepth 2 -type f \( -perm -002 -o ! -user root \) -ls 2>/dev/null | tee -a "$REPORT"
  # Eksekusi unit yang menunjuk ke lokasi writeable?
  sec "ExecStart target yang berada di lokasi berisiko (writeable)"
  while IFS= read -r line; do
    target="$(echo "$line" | sed -E 's/.*ExecStart=\S*\s*//; s/^ExecStart=//; s/".*//; s/\s.*//')"
    [ -n "$target" ] && [ -e "$target" ] && [ -w "$target" ] && bad "ExecStart writeable: $(perm "$target")"
  done < <(grep -RIsn "^ExecStart=" /etc/systemd/system 2>/dev/null | cut -d: -f1-3)
fi

# ---------- 8) World-writable dirs & sticky bit ----------
sec "World-writable directories tanpa sticky bit (+t)"
find / -type d -perm -0002 ! -perm -1000 2>/dev/null | head -n 150 | sed 's/^/  /' | tee -a "$REPORT"

# ---------- 9) Root-owned tapi writable oleh non-root ----------
sec "File root-owned namun writable oleh group/other (subset)"
find / -xdev -type f -user root \( -perm -002 -o -perm -020 \) -printf '%M %U:%G %p\n' 2>/dev/null \
  | head -n 120 | sed 's/^/  /' | tee -a "$REPORT"

# ---------- 10) Mount & fstab ----------
sec "Mount options (noexec,nosuid,nodev)"
mount | sed 's/^/  /' | tee -a "$REPORT"
for MP in / /tmp /var/tmp /home /dev/shm; do
  LINE="$(mount | awk -v mp="$MP" '$3==mp{print $0}')"
  [ -n "$LINE" ] || continue
  case "$LINE" in
    *noexec*) : ;; *) warn "$MP tidak dipasang dengan noexec (pertimbangkan untuk temp dirs)";;
  esac
  case "$LINE" in
    *nosuid*) : ;; *) warn "$MP tidak dipasang dengan nosuid (pertimbangkan untuk temp dirs)";;
  esac
  case "$LINE" in
    *nodev*)  : ;; *) warn "$MP tidak dipasang dengan nodev (pertimbangkan untuk temp dirs)";;
  esac
done

# ---------- 11) Docker / LXC / NFS ----------
sec "Containers & NFS"
if [ -S /var/run/docker.sock ]; then
  bad "docker.sock terdeteksi: $(stat -c '%A %U:%G %n' /var/run/docker.sock 2>/dev/null). Akses ini ≈ akses root."
else
  ok "Tidak ada docker.sock."
fi
if [ -r /etc/exports ]; then
  if grep -q "no_root_squash" /etc/exports 2>/dev/null; then
    bad "/etc/exports mengandung no_root_squash (privilege leakage via NFS)."
  else
    ok "Tidak ditemukan no_root_squash pada /etc/exports."
  fi
fi

# ---------- 12) Creds & secrets yang umum bocor ----------
sec "Creds/secrets umum (hanya pointer)"
for f in /root/.ssh /home/*/.ssh /etc/shadow /etc/passwd /etc/sudoers /etc/sudoers.d; do
  [ -e "$f" ] && perm "$f" | tee -a "$REPORT"
done
for f in /root/.my.cnf /etc/mysql/debian.cnf; do
  [ -r "$f" ] && bad "File kredensial mungkin: $(perm "$f")"
done

# ---------- 13) Ringkasan JSON ----------
SUID_CNT=$(wc -l < "$SUID_LIST" 2>/dev/null || echo 0)
SGID_CNT=$(wc -l < "$SGID_LIST" 2>/dev/null || echo 0)
DOCKER_SOCK=$( [ -S /var/run/docker.sock ] && echo true || echo false )
PTR_SCOPE=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo "na")
KPTR=$(cat /proc/sys/kernel/kptr_restrict 2>/dev/null || echo "na")
DMESG=$(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null || echo "na")

cat > "$JSON" <<EOF
{
  "host": "$HOST",
  "time": "$(date --iso-8601=seconds 2>/dev/null || date)",
  "os": "$(echo "$OS" | sed 's/"/\\"/g')",
  "kernel": "$KVER",
  "suid_count": $SUID_CNT,
  "sgid_count": $SGID_CNT,
  "docker_sock": $DOCKER_SOCK,
  "ptrace_scope": "$(echo "$PTR_SCOPE")",
  "kptr_restrict": "$(echo "$KPTR")",
  "dmesg_restrict": "$(echo "$DMESG")"
}
EOF

# ---------- 14) Rekomendasi ringkas ----------
sec "Rekomendasi cepat (hardening privesc)"
log "- Minimalkan SUID/SGID; hapus paket/biner tidak perlu."
log "- Perketat sudoers; hindari NOPASSWD luas; audit 'sudo -l' per user."
log "- Harden PATH: hilangkan '.' dan '::'; pastikan direktori PATH tidak writeable umum."
log "- Temp dirs (/tmp,/var/tmp,/dev/shm) gunakan noexec,nosuid,nodev bila kompatibel."
log "- Tinjau file root-owned yang writeable oleh group/other."
log "- Audit cron/systemd: pastikan unit/skrip tidak berasal dari lokasi writeable user."
log "- Tinjau capabilities sensitif (cap_setuid, cap_sys_admin, dll)."
log "- Nonaktifkan akses docker.sock dari user non-root; pakai rootless/container policies."
log "- Aktifkan SELinux/AppArmor (Enforcing) bila memungkinkan."
log "- Patch OS & kernel secara rutin; gunakan channel LTS/stable distro."

echo
echo "${BOLD}Selesai.${RESET} Laporan: ${BOLD}$REPORT${RESET}"
echo "Ringkasan JSON: ${BOLD}$JSON${RESET}"
echo "Folder output : ${BOLD}$OUTDIR${RESET}"
