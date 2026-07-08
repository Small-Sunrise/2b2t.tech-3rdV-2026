#!/usr/bin/env bash
# Automated backup for 2b2t.tech Minecraft network
# Usage: bash scripts/backup.sh [world|config|db|all]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS="${KEEP_DAYS:-7}"

# Load .env if present
if [ -f "${ROOT_DIR}/.env" ]; then
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

mkdir -p "${BACKUP_DIR}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ---- World backup ----
backup_world() {
  log "Backing up 2b2t world..."
  local world_dir="${ROOT_DIR}/2b2t/world"
  if [ ! -d "${world_dir}" ]; then
    log "WARN: world directory not found at ${world_dir}"
    return 0
  fi
  local out="${BACKUP_DIR}/world_${TIMESTAMP}.tar.gz"
  tar -czf "${out}" -C "${ROOT_DIR}/2b2t" world world_nether world_the_end 2>/dev/null || {
    log "WARN: Some world dimensions missing, backing up what exists"
    tar -czf "${out}" -C "${ROOT_DIR}/2b2t" world 2>/dev/null
  }
  log "OK: World backup saved to ${out}"
}

# ---- Config backup ----
backup_config() {
  log "Backing up plugin configs..."
  local out="${BACKUP_DIR}/config_${TIMESTAMP}.tar.gz"
  tar -czf "${out}" \
    -C "${ROOT_DIR}" \
    --exclude='*.jar' \
    --exclude='logs' \
    --exclude='world' \
    --exclude='world_nether' \
    --exclude='world_the_end' \
    --exclude='cache' \
    --exclude='libraries' \
    --exclude='versions' \
    --exclude='pids' \
    --exclude='backups' \
    2b2t/plugins lobby/plugins VC/plugins .env 2>/dev/null || true
  log "OK: Config backup saved to ${out}"
}

# ---- Database backup (mysqldump) ----
backup_db() {
  log "Backing up MariaDB..."
  if ! command -v mysqldump &>/dev/null; then
    log "SKIP: mysqldump not installed"
    return 0
  fi
  local db_host=$(echo "${LUCKPERMS_DB_HOST:-127.0.0.1:3306}" | cut -d: -f1)
  local db_port=$(echo "${LUCKPERMS_DB_HOST:-127.0.0.1:3306}" | cut -d: -f2)
  local out="${BACKUP_DIR}/db_luckperms_${TIMESTAMP}.sql.gz"

  mysqldump -h "${db_host}" -P "${db_port}" \
    -u "${LUCKPERMS_DB_USER:-lpsql}" \
    -p"${LUCKPERMS_DB_PASSWORD:-}" \
    "${LUCKPERMS_DB_NAME:-luckperms_2b2t}" 2>/dev/null | gzip > "${out}" || {
    log "FAIL: Database backup failed (check credentials in .env)"
    return 1
  }
  log "OK: Database backup saved to ${out}"
}

# ---- Cleanup old backups ----
cleanup_old() {
  log "Removing backups older than ${KEEP_DAYS} days..."
  find "${BACKUP_DIR}" -type f -mtime "+${KEEP_DAYS}" -delete 2>/dev/null || true
  log "OK: Cleanup complete"
}

# ---- Main ----
MODE="${1:-all}"

case "${MODE}" in
  world)  backup_world ;;
  config) backup_config ;;
  db)     backup_db ;;
  all)
    backup_world
    backup_config
    backup_db
    cleanup_old
    ;;
  *)
    echo "Usage: $0 [world|config|db|all]"
    exit 1
    ;;
esac

log "Backup complete. Files in ${BACKUP_DIR}:"
ls -lh "${BACKUP_DIR}"/*${TIMESTAMP}* 2>/dev/null || true
