#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="${ROOT_DIR}/pids"

stop_service() {
  local name="$1"
  local pid_file="${PID_DIR}/${name}.pid"

  if [ ! -f "${pid_file}" ]; then
    echo "${name} not running (pid file missing)."
    return 0
  fi

  local pid
  pid="$(cat "${pid_file}")"
  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}"
    echo "Stopped ${name} (pid ${pid})."
  else
    echo "${name} already stopped (pid ${pid})."
  fi

  rm -f "${pid_file}"
}

stop_service "2b2t"
stop_service "lobby"
stop_service "vc"
