#!/usr/bin/env bash
# Health check / monitoring for 2b2t.tech Minecraft network
# Usage: bash scripts/healthcheck.sh [--json]
# Designed to be run from cron or a monitoring system.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_DIR="${ROOT_DIR}/pids"
JSON_MODE=false

[ "${1:-}" = "--json" ] && JSON_MODE=true

# ---- Helpers ----
check_tcp() {
  local host="$1" port="$2"
  if command -v nc &>/dev/null; then
    nc -z -w3 "${host}" "${port}" 2>/dev/null && return 0 || return 1
  else
    timeout 3 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null && return 0 || return 1
  fi
}

check_process() {
  local name="$1"
  local pid_file="${PID_DIR}/${name}.pid"
  if [ -f "${pid_file}" ] && kill -0 "$(cat "${pid_file}")" 2>/dev/null; then
    return 0
  fi
  return 1
}

# ---- Services to check ----
SERVICES=(
  "vc:Velocity:127.0.0.1:50016"
  "lobby:Lobby:127.0.0.1:60001"
  "2b2t:Survival:127.0.0.1:60003"
)

FAIL=0
RESULTS=()

for svc in "${SERVICES[@]}"; do
  IFS=':' read -r pid_name label host port <<< "${svc}"
  status="OK"
  detail=""

  if check_process "${pid_name}"; then
    if check_tcp "${host}" "${port}"; then
      status="OK"
      detail="pid=$(cat "${PID_DIR}/${pid_name}.pid") port=${port} open"
    else
      status="WARN"
      detail="pid=$(cat "${PID_DIR}/${pid_name}.pid") but port ${port} not responding"
      FAIL=1
    fi
  else
    status="DOWN"
    detail="process not running"
    FAIL=1
  fi

  RESULTS+=("${label}:${status}:${detail}")
done

# ---- Check MariaDB ----
DB_HOST=$(echo "${LUCKPERMS_DB_HOST:-127.0.0.1:3306}" | cut -d: -f1)
DB_PORT=$(echo "${LUCKPERMS_DB_HOST:-127.0.0.1:3306}" | cut -d: -f2)
DB_STATUS="OK"
DB_DETAIL=""

if check_tcp "${DB_HOST}" "${DB_PORT}"; then
  DB_STATUS="OK"
  DB_DETAIL="${DB_HOST}:${DB_PORT} reachable"
else
  DB_STATUS="DOWN"
  DB_DETAIL="${DB_HOST}:${DB_PORT} not reachable"
  FAIL=1
fi

# ---- Check disk space ----
DISK_STATUS="OK"
DISK_DETAIL=""
DISK_USAGE=$(df -h "${ROOT_DIR}" | awk 'NR==2 {print $5}' | tr -d '%')
if [ "${DISK_USAGE}" -gt 90 ]; then
  DISK_STATUS="WARN"
  DISK_DETAIL="disk ${DISK_USAGE}% full"
  FAIL=1
else
  DISK_DETAIL="${DISK_USAGE}% used"
fi

# ---- Output ----
if ${JSON_MODE}; then
  echo "{"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"healthy\": $([ "${FAIL}" -eq 0 ] && echo "true" || echo "false"),"
  echo "  \"services\": {"
  for i in "${!RESULTS[@]}"; do
    IFS=':' read -r label status detail <<< "${RESULTS[$i]}"
    comma=","
    [ "$((i+1))" -eq "${#RESULTS[@]}" ] && comma=""
    echo "    \"${label}\": {\"status\": \"${status}\", \"detail\": \"${detail}\"}${comma}"
  done
  echo "  },"
  echo "  \"mariadb\": {\"status\": \"${DB_STATUS}\", \"detail\": \"${DB_DETAIL}\"},"
  echo "  \"disk\": {\"status\": \"${DISK_STATUS}\", \"detail\": \"${DISK_DETAIL}\"}"
  echo "}"
else
  echo "=== 2b2t.tech Health Check [$(date)] ==="
  echo ""
  for result in "${RESULTS[@]}"; do
    IFS=':' read -r label status detail <<< "${result}"
    icon="✓"
    [ "${status}" != "OK" ] && icon="✗"
    echo "  ${icon} ${label}: ${status} (${detail})"
  done
  echo "  - MariaDB: ${DB_STATUS} (${DB_DETAIL})"
  echo "  - Disk: ${DISK_STATUS} (${DISK_DETAIL})"
  echo ""
  if [ "${FAIL}" -eq 0 ]; then
    echo "All systems healthy."
  else
    echo "WARNING: Some services are unhealthy (see above)."
  fi
fi

exit "${FAIL}"
