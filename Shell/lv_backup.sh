#!/usr/bin/env bash
# homelabvg_backup_dd.sh
# Paranoid-safe LVM backup: streams each LV via dd over SSH, resumable, verified with SHA256
# Must be run as root (reads raw block devices)
set -euo pipefail

# -------------------------
# CONFIG - edit these
# -------------------------
REMOTE_USER="abhil"                # remote account with write access to REMOTE_DIR
REMOTE_HOST="192.168.1.10"              # remote host IP/FQDN
REMOTE_DIR="/nexusbackup"               # remote directory to store .img files
VG_NAME="homelabvg"                     # LVM volume group to backup
LOG_DIR="/var/log"                      # where to store log
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=8"
# blocksize to use for streaming & resume units (1MiB recommended for portability)
BS_BYTES=1048576
BS="1M"
# -------------------------

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
LOGFILE="${LOG_DIR}/lv_backup_${VG_NAME}_${TIMESTAMP}.log"
SUMMARY_TMP=$(mktemp)
trap 'rc=$?; echo "Exiting with $rc"; rm -f "$SUMMARY_TMP"; exit $rc' EXIT

mkdir -p "$(dirname "$LOGFILE")"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== LVM BACKUP START: ${TIMESTAMP} (UTC) ==="
echo "CONFIG: REMOTE=${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}  VG=${VG_NAME}  BS=${BS}"
echo

# -------------------------
# Local command checks
# -------------------------
for cmd in lvs lsblk dd sha256sum ssh awk numfmt df stat; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[FATAL] Missing required local command: $cmd"
    exit 2
  fi
done

# -------------------------
# Remote checks (reachability, tools, write access)
# -------------------------
echo "[1/10] Checking remote reachability..."
if ! ping -c1 -W2 "$REMOTE_HOST" >/dev/null 2>&1; then
  echo "[FATAL] Remote host $REMOTE_HOST not reachable (ping failed)."
  exit 3
fi

echo "[2/10] Checking remote tools & write access..."
REMOTE_CHECKS="
  command -v dd >/dev/null 2>&1 || { echo 'DD_MISSING'; exit 10; }
  command -v sha256sum >/dev/null 2>&1 || { echo 'SHA_MISSING'; exit 11; }
  mkdir -p '${REMOTE_DIR}' >/dev/null 2>&1 || { echo 'MKDIR_FAIL'; exit 12; }
  test -w '${REMOTE_DIR}' || { echo 'NO_WRITE'; exit 13; }
  # portable df: try GNU, fallback to POSIX
  if df -B1 --output=avail '${REMOTE_DIR}' >/dev/null 2>&1; then
    df -B1 --output=avail '${REMOTE_DIR}' | tail -n1
  else
    df -Pk '${REMOTE_DIR}' | tail -n1 | awk '{print \$4 * 1024}'
  fi
"
REMOTE_DF_OUT=""
if ! REMOTE_DF_OUT=$(ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "$REMOTE_CHECKS" 2>&1); then
  echo "[FATAL] Remote prechecks failed. Output:"
  echo "$REMOTE_DF_OUT"
  exit 4
fi
# remote free bytes is last line of REMOTE_DF_OUT (strip non-digits)
REMOTE_FREE_BYTES=$(printf "%s\n" "$REMOTE_DF_OUT" | tail -n1 | tr -cd '0-9')
if [[ -z "$REMOTE_FREE_BYTES" ]]; then
  echo "[FATAL] Could not determine remote free space; output was:"
  printf "%s\n" "$REMOTE_DF_OUT"
  exit 5
fi
echo "Remote free bytes: $REMOTE_FREE_BYTES ($(numfmt --to=iec --suffix=B $REMOTE_FREE_BYTES))"

# -------------------------
# Gather LV list and sizes
# -------------------------
echo "[3/10] Gathering LVs in VG '${VG_NAME}'..."
mapfile -t LV_NAMES < <(lvs --noheadings -o lv_name,vg_name --separator '|' | awk -F'|' -v vg="$VG_NAME" '$2==vg{gsub(/^[ \t]+|[ \t]+$/,"",$1); print $1}')
if [[ ${#LV_NAMES[@]} -eq 0 ]]; then
  echo "[FATAL] No LVs found in VG '${VG_NAME}'."
  exit 6
fi
echo "Found LVs: ${LV_NAMES[*]}"

declare -A LV_SIZES_BYTES
TOTAL_BYTES_REQ=0
for lv in "${LV_NAMES[@]}"; do
  DEV="/dev/${VG_NAME}/${lv}"
  if [[ ! -b "$DEV" ]]; then
    echo "[WARN] Device $DEV not present; skipping."
    LV_SIZES_BYTES["$lv"]=0
    continue
  fi
  bytes=$(lsblk -bno SIZE "$DEV" | awk '{print $1}')
  LV_SIZES_BYTES["$lv"]=$bytes
  TOTAL_BYTES_REQ=$((TOTAL_BYTES_REQ + bytes))
done

echo "[4/10] Total bytes required: $TOTAL_BYTES_REQ ($(numfmt --to=iec --suffix=B $TOTAL_BYTES_REQ))"
if (( REMOTE_FREE_BYTES < TOTAL_BYTES_REQ )); then
  echo "[FATAL] Remote does not have enough free space. Need $(numfmt --to=iec --suffix=B $TOTAL_BYTES_REQ), have $(numfmt --to=iec --suffix=B $REMOTE_FREE_BYTES)"
  exit 7
fi

# -------------------------
# Summary header
# -------------------------
printf "%-12s %-12s %-64s %-64s %-6s\n" "LV" "Size" "Local_SHA256" "Remote_SHA256" "MATCH" > "$SUMMARY_TMP"

# -------------------------
# Per-LV transfer & verification
# -------------------------
echo "[5/10] Starting per-LV transfer & verification..."
for lv in "${LV_NAMES[@]}"; do
  SRC_DEV="/dev/${VG_NAME}/${lv}"
  if [[ ! -b "$SRC_DEV" ]]; then
    printf "%-12s %-12s %-64s %-64s %-6s\n" "$lv" "MISSING" "-" "-" "SKIP" >> "$SUMMARY_TMP"
    continue
  fi
  SIZE_BYTES=${LV_SIZES_BYTES[$lv]}
  SIZE_HR=$(numfmt --to=iec --suffix=B $SIZE_BYTES)
  DEST_FILE="${REMOTE_DIR}/${lv}.img"
  echo
  echo "----"
  echo "[LV] $lv    size=$SIZE_HR"
  echo " source: $SRC_DEV"
  echo " dest:   ${REMOTE_USER}@${REMOTE_HOST}:$DEST_FILE"

  # get remote file size if exists
  REM_REMOTE_SIZE=0
  if ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "[ -f '${DEST_FILE}' ] && stat -c%s '${DEST_FILE}' || echo 0" >/dev/null 2>&1; then
    REM_REMOTE_SIZE=$(ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "if [ -f '${DEST_FILE}' ]; then stat -c%s '${DEST_FILE}'; else echo 0; fi")
    REM_REMOTE_SIZE=${REM_REMOTE_SIZE:-0}
  fi
  REM_REMOTE_SIZE=$(printf "%s\n" "$REM_REMOTE_SIZE" | tr -cd '0-9')
  echo "Remote existing size: $REM_REMOTE_SIZE bytes ($(numfmt --to=iec --suffix=B $REM_REMOTE_SIZE))"

  if (( REM_REMOTE_SIZE == SIZE_BYTES )); then
    echo "[INFO] Remote file already same size. Will verify hashes."
  elif (( REM_REMOTE_SIZE > SIZE_BYTES )); then
    echo "[WARN] Remote file is larger than source. Aborting transfer for $lv to avoid corruption."
    printf "%-12s %-12s %-64s %-64s %-6s\n" "$lv" "$SIZE_HR" "-" "-" "REMOTE_TOO_BIG" >> "$SUMMARY_TMP"
    continue
  fi

  # If partial exists, verify prefix hash matches before resuming
  if (( REM_REMOTE_SIZE > 0 && REM_REMOTE_SIZE < SIZE_BYTES )); then
    echo "[RESUME] Partial remote file detected. Verifying prefix integrity before resuming..."
    # ensure REM_REMOTE_SIZE is a multiple of blocksize, otherwise abort (safer)
    REM_BLOCKS=$(( REM_REMOTE_SIZE / BS_BYTES ))
    REM_OFFSET=$(( REM_BLOCKS * BS_BYTES ))
    if (( REM_OFFSET != REM_REMOTE_SIZE )); then
      echo "[FATAL] Remote partial file size ($REM_REMOTE_SIZE) not aligned to ${BS} blocks. Please remove partial file manually: ${DEST_FILE}"
      exit 9
    fi
    echo "Comparing prefix hash for first $REM_OFFSET bytes..."
    LOCAL_PREFIX_HASH=$(dd if="$SRC_DEV" bs=$BS count=$REM_BLOCKS iflag=fullblock 2>/dev/null | sha256sum | awk '{print $1}')
    REMOTE_PREFIX_HASH=$(ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "dd if='${DEST_FILE}' bs=$BS count=$REM_BLOCKS iflag=fullblock 2>/dev/null | sha256sum" | awk '{print $1}' || true)
    if [[ -z "$LOCAL_PREFIX_HASH" || -z "$REMOTE_PREFIX_HASH" ]]; then
      echo "[FATAL] Could not compute prefix hashes for resume check."
      exit 10
    fi
    if [[ "$LOCAL_PREFIX_HASH" != "$REMOTE_PREFIX_HASH" ]]; then
      echo "[FATAL] Prefix hash mismatch. Remote partial file does not match source. Do NOT resume. Remove remote partial file or move it aside, then re-run."
      echo " local-prefix:  $LOCAL_PREFIX_HASH"
      echo " remote-prefix: $REMOTE_PREFIX_HASH"
      exit 11
    fi
    echo "[OK] Prefix matches; safe to resume from ${REM_OFFSET} bytes."
  fi

  # Start streaming using dd with skip/seek to resume
  # compute skip blocks: number of BS blocks already on remote
  SKIP_BLOCKS=$(( REM_REMOTE_SIZE / BS_BYTES ))
  SEEK_BLOCKS=$SKIP_BLOCKS
  echo "[TRANSFER] Streaming from offset ${REM_REMOTE_SIZE} bytes (skip=${SKIP_BLOCKS} blocks)."
  set -o pipefail
  if ! ( dd if="$SRC_DEV" bs=$BS iflag=fullblock skip=$SKIP_BLOCKS 2>/tmp/dd_${lv}_in.err | \
         ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "dd of='${DEST_FILE}' bs=$BS seek=$SEEK_BLOCKS oflag=direct 2>/tmp/dd_${lv}_out.err" ); then
    echo "[ERROR] dd/ssh transfer failed for $lv. Check $LOGFILE and remote /tmp/dd_${lv}_*.err"
    printf "%-12s %-12s %-64s %-64s %-6s\n" "$lv" "$SIZE_HR" "-" "-" "TRANSFER_FAIL" >> "$SUMMARY_TMP"
    continue
  fi
  set +o pipefail

  # After transfer, compute full sha256 local & remote
  echo "[HASH] Computing local full SHA256 (this reads the entire LV)..."
  LOCAL_HASH=$(sha256sum "$SRC_DEV" | awk '{print $1}')
  echo "[HASH] Computing remote full SHA256..."
  REMOTE_HASH=$(ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "sha256sum '${DEST_FILE}'" | awk '{print $1}' || true)

  MATCH="FAIL"
  if [[ -n "$LOCAL_HASH" && -n "$REMOTE_HASH" && "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
    MATCH="OK"
    echo "[OK] Hash match for $lv"
  else
    echo "[FAIL] Hash mismatch for $lv"
    echo " local:  ${LOCAL_HASH:-<missing>}"
    echo " remote: ${REMOTE_HASH:-<missing>}"
  fi

  printf "%-12s %-12s %-64s %-64s %-6s\n" "$lv" "$SIZE_HR" "${LOCAL_HASH:-}" "${REMOTE_HASH:-}" "$MATCH" >> "$SUMMARY_TMP"
done

# -------------------------
# Final summary
# -------------------------
echo
echo "================ BACKUP SUMMARY ================"
column -t -s $'\t' <(cat "$SUMMARY_TMP") 2>/dev/null || cat "$SUMMARY_TMP"
echo "==============================================="

if grep -qE "FAIL|TRANSFER_FAIL|REMOTE_TOO_BIG|RSYNC_FAIL" "$SUMMARY_TMP"; then
  echo "[RESULT] One or more LVs failed verification or transfer. DO NOT wipe sources."
  exit 12
fi

echo "[RESULT] All LVs transferred and verified OK."
echo "Log: $LOGFILE"
echo "=== Complete: $(date -u +"%Y-%m-%dT%H:%M:%SZ") ==="
