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

VC_JAR="${VC_JAR:-velocity-3.5.0-SNAPSHOT-605.jar}"
LOBBY_JAR="${LOBBY_JAR:-paper.jar}"
SURVIVAL_JAR="${SURVIVAL_JAR:-leaf-26.2-14.jar}"

VC_JAVA_OPTS="${VC_JAVA_OPTS:- -Xms1G -Xmx1G}"
LOBBY_JAVA_OPTS="${LOBBY_JAVA_OPTS:- -Xms1G -Xmx2G}"
SURVIVAL_JAVA_OPTS="${SURVIVAL_JAVA_OPTS:- -Xms4G -Xmx6G -XX:+UnlockExperimentalVMOptions -XX:+UseZGC -XX:+ZGenerational -XX:+AlwaysPreTouch -XX:+DisableExplicitGC}"

write_vc_secrets() {
  if [ -n "${FORWARDING_SECRET:-}" ]; then
    printf '%s' "${FORWARDING_SECRET}" > "${VC_DIR}/forwarding.secret"
  fi

  if [ -n "${FLOODGATE_KEY_PEM:-}" ]; then
    mkdir -p "${VC_DIR}/plugins/floodgate"
    printf '%b' "${FLOODGATE_KEY_PEM}" > "${VC_DIR}/plugins/floodgate/key.pem"
  fi
}

start_service() {
  local name="$1"
  local dir="$2"
  local jar="$3"
  local opts="$4"
  local extra_args="$5"
  local pid_file="${PID_DIR}/${name}.pid"
  local log_file="${LOG_DIR}/${name}.log"

  if [ -f "${pid_file}" ] && kill -0 "$(cat "${pid_file}")" 2>/dev/null; then
    echo "${name} already running (pid $(cat "${pid_file}"))."
    return 0
  fi

  if [ ! -f "${dir}/${jar}" ]; then
    echo "${name} jar missing: ${dir}/${jar}"
    return 1
  fi

  (
    cd "${dir}"
    nohup java ${opts} -jar "${jar}" ${extra_args} > "${log_file}" 2>&1 &
    echo $! > "${pid_file}"
  )

  echo "Started ${name} (pid $(cat "${pid_file}"))."
}

write_vc_secrets

start_service "vc" "${VC_DIR}" "${VC_JAR}" "${VC_JAVA_OPTS}" ""
start_service "lobby" "${LOBBY_DIR}" "${LOBBY_JAR}" "${LOBBY_JAVA_OPTS}" "--nogui"
start_service "2b2t" "${SURVIVAL_DIR}" "${SURVIVAL_JAR}" "${SURVIVAL_JAVA_OPTS}" "--nogui"
