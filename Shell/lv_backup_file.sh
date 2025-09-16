#!/usr/bin/env bash
# homelabvg_backup_files_paranoid.sh
# Paranoid-safe file-level LVM backup: mounts each LV read-only, rsyncs files over SSH, resumable, verified with SHA256
set -euo pipefail

# -------------------------
# CONFIG - edit these
# -------------------------
REMOTE_USER="abhil"
REMOTE_HOST="192.168.1.10"
REMOTE_DIR="/nexusbackup"
VG_NAME="homelabvg"
LOG_DIR="/var/log"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=8"
# -------------------------

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
LOGFILE="${LOG_DIR}/lv_backup_files_${VG_NAME}_${TIMESTAMP}.log"
SUMMARY_TMP=$(mktemp)
trap 'rc=$?; rm -f "$SUMMARY_TMP"; exit $rc' EXIT

mkdir -p "$(dirname "$LOGFILE")"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== FILE-LEVEL LVM BACKUP START: ${TIMESTAMP} (UTC) ==="
echo "CONFIG: REMOTE=${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}  VG=${VG_NAME}"
echo

# -------------------------
# Local command checks
# -------------------------
for cmd in lvs lsblk mount umount rsync sha256sum ssh awk numfmt df stat find mkdir; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[FATAL] Missing required local command: $cmd"
    exit 2
  fi
done

# -------------------------
# Remote checks
# -------------------------
echo "[1/10] Checking remote reachability..."
if ! ping -c1 -W2 "$REMOTE_HOST" >/dev/null 2>&1; then
  echo "[FATAL] Remote host $REMOTE_HOST not reachable."
  exit 3
fi

echo "[2/10] Checking remote tools & write access..."
REMOTE_CHECK="
  command -v rsync >/dev/null 2>&1 || { echo 'RSYNC_MISSING'; exit 10; }
  command -v sha256sum >/dev/null 2>&1 || { echo 'SHA_MISSING'; exit 11; }
  command -v find >/dev/null 2>&1 || { echo 'FIND_MISSING'; exit 12; }
  mkdir -p '${REMOTE_DIR}' >/dev/null 2>&1 || { echo 'MKDIR_FAIL'; exit 13; }
  test -w '${REMOTE_DIR}' || { echo 'NO_WRITE'; exit 14; }
  # check free space
  if df -B1 --output=avail '${REMOTE_DIR}' >/dev/null 2>&1; then
    df -B1 --output=avail '${REMOTE_DIR}' | tail -n1
  else
    df -Pk '${REMOTE_DIR}' | tail -n1 | awk '{print \$4 * 1024}'
  fi
"
REMOTE_DF_OUT=$(ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "$REMOTE_CHECK" 2>&1 || true)
REMOTE_FREE_BYTES=$(printf "%s\n" "$REMOTE_DF_OUT" | tail -n1 | tr -cd '0-9')
if [[ -z "$REMOTE_FREE_BYTES" ]]; then
  echo "[FATAL] Could not determine remote free space; output:"
  echo "$REMOTE_DF_OUT"
  exit 5
fi
echo "Remote free bytes: $REMOTE_FREE_BYTES ($(numfmt --to=iec --suffix=B $REMOTE_FREE_BYTES))"

# -------------------------
# Gather LV list
# -------------------------
echo "[3/10] Gathering LVs in VG '${VG_NAME}'..."
mapfile -t LV_NAMES < <(lvs --noheadings -o lv_name,vg_name --separator '|' | awk -F'|' -v vg="$VG_NAME" '$2==vg{gsub(/^[ \t]+|[ \t]+$/,"",$1); print $1}')
if [[ ${#LV_NAMES[@]} -eq 0 ]]; then
  echo "[FATAL] No LVs found in VG '${VG_NAME}'"
  exit 6
fi
echo "Found LVs: ${LV_NAMES[*]}"

# -------------------------
# Calculate total LV size for remote space check
# -------------------------
TOTAL_BYTES_REQ=0
declare -A LV_SIZES_BYTES
for lv in "${LV_NAMES[@]}"; do
  DEV="/dev/${VG_NAME}/${lv}"
  if [[ ! -b "$DEV" ]]; then
    LV_SIZES_BYTES["$lv"]=0
    continue
  fi
  SIZE=$(lsblk -bno SIZE "$DEV" | awk '{print $1}')
  LV_SIZES_BYTES["$lv"]=$SIZE
  TOTAL_BYTES_REQ=$((TOTAL_BYTES_REQ + SIZE))
done

echo "[4/10] Total estimated LV size: $TOTAL_BYTES_REQ ($(numfmt --to=iec --suffix=B $TOTAL_BYTES_REQ))"
if (( REMOTE_FREE_BYTES < TOTAL_BYTES_REQ )); then
  echo "[FATAL] Remote does not have enough free space."
  exit 7
fi

# -------------------------
# Summary header
# -------------------------
printf "%-12s %-12s %-64s %-64s %-6s\n" "LV" "Files" "Local_SHA256" "Remote_SHA256" "MATCH" > "$SUMMARY_TMP"

# -------------------------
# Backup per LV
# -------------------------
echo "[5/10] Starting per-LV file-level backup..."
for lv in "${LV_NAMES[@]}"; do
  SRC_DEV="/dev/${VG_NAME}/${lv}"
  if [[ ! -b "$SRC_DEV" ]]; then
    printf "%-12s %-12s %-64s %-64s %-6s\n" "$lv" "MISSING" "-" "-" "SKIP" >> "$SUMMARY_TMP"
    continue
  fi

  # mount read-only
  MOUNT_POINT="/mnt/${lv}_backup"
  mkdir -p "$MOUNT_POINT"
  mount -o ro "$SRC_DEV" "$MOUNT_POINT"

  DEST_DIR="${REMOTE_DIR}/${lv}"
  echo
  echo "----"
  echo "[LV] $lv    src: $SRC_DEV  dest: ${REMOTE_USER}@${REMOTE_HOST}:$DEST_DIR"

  # rsync with resume & progress
  RSYNC_OPTS="-avh --progress --append-verify --inplace --no-perms --no-owner --no-group -S"
  if ! rsync $RSYNC_OPTS "$MOUNT_POINT/" "${REMOTE_USER}@${REMOTE_HOST}:$DEST_DIR/"; then
    echo "[ERROR] Rsync failed for LV $lv"
    umount "$MOUNT_POINT"
    printf "%-12s %-12s %-64s %-64s %-6s\n" "$lv" "ERROR" "-" "-" "RSYNC_FAIL" >> "$SUMMARY_TMP"
    continue
  fi

  # compute local & remote SHA256 recursively
  echo "[HASH] Computing local SHA256..."
  LOCAL_HASH=$(find "$MOUNT_POINT" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')

  echo "[HASH] Computing remote SHA256..."
  REMOTE_HASH=$(ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "find '$DEST_DIR' -type f -exec sha256sum {} + | sha256sum" | awk '{print $1}' || true)

  MATCH="FAIL"
  if [[ -n "$LOCAL_HASH" && -n "$REMOTE_HASH" && "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
    MATCH="OK"
    echo "[OK] Hash match for LV $lv"
  else
    echo "[FAIL] Hash mismatch for LV $lv"
  fi

  FILE_COUNT=$(find "$MOUNT_POINT" -type f | wc -l)
  printf "%-12s %-12s %-64s %-64s %-6s\n" "$lv" "$FILE_COUNT" "$LOCAL_HASH" "$REMOTE_HASH" "$MATCH" >> "$SUMMARY_TMP"

  umount "$MOUNT_POINT"
done

# -------------------------
# Final summary
# -------------------------
echo
echo "================ BACKUP SUMMARY ================"
column -t -s $'\t' <(cat "$SUMMARY_TMP") 2>/dev/null || cat "$SUMMARY_TMP"
echo "==============================================="

if grep -q "FAIL\|RSYNC_FAIL" "$SUMMARY_TMP"; then
  echo "[RESULT] One or more LVs failed verification. DO NOT wipe sources."
  exit 8
fi

echo "[RESULT] All LVs transferred and verified OK."
echo "Log: $LOGFILE"
echo "=== Complete: $(date -u +"%Y-%m-%dT%H:%M:%SZ") ==="
