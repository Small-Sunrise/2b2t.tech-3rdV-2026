#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from .env if present
if [ -f "${BASH_SOURCE[0]%/*}/.env" ]; then
  set -a
  source "${BASH_SOURCE[0]%/*}/.env"
  set +a
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${ROOT_DIR}/logs"
PID_DIR="${ROOT_DIR}/pids"

mkdir -p "${LOG_DIR}" "${PID_DIR}"

VC_DIR="${ROOT_DIR}/VC"
LOBBY_DIR="${ROOT_DIR}/lobby"
SURVIVAL_DIR="${ROOT_DIR}/2b2t"

# JVM options are defined in each server's own run.sh for consistency.
# Each run.sh also writes its PID to ../pids/<name>.pid for healthcheck.

write_vc_secrets() {
  if [ -n "${FORWARDING_SECRET:-}" ]; then
    printf '%s' "${FORWARDING_SECRET}" > "${VC_DIR}/forwarding.secret"
  fi

  if [ -n "${FLOODGATE_KEY_PEM:-}" ]; then
    mkdir -p "${VC_DIR}/plugins/floodgate"
    printf '%b' "${FLOODGATE_KEY_PEM}" > "${VC_DIR}/plugins/floodgate/key.pem"
  fi

  # Write BungeeGuard token to backend servers for bungeeguard forwarding
  if [ -n "${FORWARDING_SECRET:-}" ]; then
    mkdir -p "${LOBBY_DIR}/plugins/BungeeGuard"
    printf '%s' "${FORWARDING_SECRET}" > "${LOBBY_DIR}/plugins/BungeeGuard/token.txt"
    mkdir -p "${SURVIVAL_DIR}/plugins/BungeeGuard"
    printf '%s' "${FORWARDING_SECRET}" > "${SURVIVAL_DIR}/plugins/BungeeGuard/token.txt"
  fi
}

write_db_secrets() {
  # Delegate to shared injection script for safe credential handling
  if [ -f "${ROOT_DIR}/scripts/inject-db-secrets.sh" ]; then
    LOBBY_DIR="${LOBBY_DIR}" SURVIVAL_DIR="${SURVIVAL_DIR}"       bash "${ROOT_DIR}/scripts/inject-db-secrets.sh"
  fi
}


start_service() {
  local name="$1"
  local dir="$2"
  local script="$3"
  local pid_file="${PID_DIR}/${name}.pid"
  local log_file="${LOG_DIR}/${name}.log"

  if [ -f "${pid_file}" ] && kill -0 "$(cat "${pid_file}")" 2>/dev/null; then
    echo "${name} already running (pid $(cat "${pid_file}"))."
    return 0
  fi

  if [ ! -x "${script}" ]; then
    echo "${name} run script missing or not executable: ${script}"
    return 1
  fi

  (
    cd "${dir}"
    exec nohup bash "${script}"
  ) > "${log_file}" 2>&1 &

  local supervisor_pid=$!
  local pid_tmp="${pid_file}.tmp"
  printf '%s\n' "${supervisor_pid}" > "${pid_tmp}"
  mv "${pid_tmp}" "${pid_file}"

  echo "Started ${name} supervisor (pid ${supervisor_pid})."
}

write_vc_secrets
write_db_secrets

start_service "vc" "${VC_DIR}" "${VC_DIR}/run.sh"
start_service "lobby" "${LOBBY_DIR}" "${LOBBY_DIR}/run.sh"
start_service "2b2t" "${SURVIVAL_DIR}" "${SURVIVAL_DIR}/run.sh"
