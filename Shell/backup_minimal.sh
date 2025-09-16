#!/usr/bin/env bash
# homelabvg_backup_files_rsync_resumable.sh
set -euo pipefail

# CONFIG
REMOTE_USER="abhil"
REMOTE_HOST="192.168.1.10"
REMOTE_DIR="/nexusbackup"
VG_NAME="homelabvg"
LOG_DIR="/var/log"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=8"

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
LOGFILE="${LOG_DIR}/lv_backup_${VG_NAME}_${TIMESTAMP}.log"

mkdir -p "$(dirname "$LOGFILE")"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== FILE-LEVEL LVM BACKUP START: $TIMESTAMP (UTC) ==="

# Local commands check
for cmd in lvs mount umount rsync ssh mkdir ping blockdev; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[FATAL] Missing $cmd"; exit 1; }
done

# Remote checks
echo "[1] Checking remote host..."
ping -c1 -W2 "$REMOTE_HOST" >/dev/null 2>&1 || { echo "[FATAL] Remote host unreachable"; exit 2; }

echo "[2] Checking remote directory & rsync..."
ssh $SSH_OPTS "$REMOTE_USER@$REMOTE_HOST" "command -v rsync >/dev/null && mkdir -p '$REMOTE_DIR' && test -w '$REMOTE_DIR'" \
  || { echo "[FATAL] Remote not ready"; exit 3; }

# Gather LVs
echo "[3] Gathering LVs..."
mapfile -t LV_NAMES < <(lvs --noheadings -o lv_name,vg_name --separator '|' | awk -F'|' -v vg="$VG_NAME" '$2==vg{gsub(/^[ \t]+|[ \t]+$/,"",$1); print $1}')
if [[ ${#LV_NAMES[@]} -eq 0 ]]; then echo "[FATAL] No LVs found"; exit 4; fi
echo "Found LVs: ${LV_NAMES[*]}"

# Backup LVs
echo "[4] Starting backup..."
for lv in "${LV_NAMES[@]}"; do
  SRC_DEV="/dev/${VG_NAME}/${lv}"
  DEST_DIR="${REMOTE_DIR}/${lv}"
  DONE_MARKER="${LOG_DIR}/.${lv}.done"

  if [[ -f "$DONE_MARKER" ]]; then
    echo "[SKIP] LV $lv already backed up previously"
    continue
  fi

  if [[ ! -b "$SRC_DEV" ]]; then
    echo "[SKIP] LV $lv missing"
    continue
  fi

  MOUNT_POINT="/mnt/${lv}_backup"
  mkdir -p "$MOUNT_POINT"
  mount -o ro "$SRC_DEV" "$MOUNT_POINT"

  mkdir -p "$DEST_DIR"
  echo "[LV] $lv -> $DEST_DIR"

  RSYNC_OPTS="-ah --info=progress2 --append-verify --inplace --no-perms --no-owner --no-group --checksum -S"
  
  until rsync $RSYNC_OPTS "$MOUNT_POINT/" "${REMOTE_USER}@${REMOTE_HOST}:$DEST_DIR/"; do
    echo "[WARN] Rsync failed for $lv, retrying in 10s..."
    sleep 10
  done

  umount "$MOUNT_POINT"
  touch "$DONE_MARKER"  # mark LV as successfully backed up
  echo "[OK] LV $lv backed up successfully"
done

echo "=== Backup complete: $(date -u +"%Y-%m-%dT%H:%M:%SZ") ==="
echo "Log: $LOGFILE"
