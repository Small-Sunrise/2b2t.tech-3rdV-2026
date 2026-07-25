#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="${ROOT_DIR}/pids"
STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-120}"

stop_service() {
  local name="$1"
  local pid_file="${PID_DIR}/${name}.pid"
  local run_script
  local server_jar

  case "${name}" in
    vc)
      run_script="${ROOT_DIR}/VC/run.sh"
      server_jar="velocity-3.5.0-SNAPSHOT-605.jar"
      ;;
    lobby)
      run_script="${ROOT_DIR}/lobby/run.sh"
      server_jar="paper.jar"
      ;;
    2b2t)
      run_script="${ROOT_DIR}/2b2t/run.sh"
      server_jar="leaf-26.2-14.jar"
      ;;
    *)
      echo "Unknown service: ${name}"
      return 1
      ;;
  esac

  if [ ! -f "${pid_file}" ]; then
    echo "${name} not running (pid file missing)."
    return 0
  fi

  local pid
  pid="$(cat "${pid_file}")"
  if ! [[ "${pid}" =~ ^[0-9]+$ ]]; then
    echo "${name} has an invalid pid file: ${pid_file}"
    rm -f "${pid_file}"
    return 1
  fi

  if ! kill -0 "${pid}" 2>/dev/null; then
    echo "${name} already stopped (pid ${pid})."
    rm -f "${pid_file}"
    return 0
  fi

  local command
  local supervisor_pid="${pid}"
  local child_pid=""
  command="$(ps -p "${pid}" -o command= 2>/dev/null || true)"

  if [[ "${command}" != *"${run_script}"* ]]; then
    # Before supervisor PIDs were introduced, run.sh stored the Java child PID.
    # Stop both processes so an in-place upgrade cannot trigger another restart.
    if [[ "${command}" != *"${server_jar}"* ]]; then
      echo "Refusing to stop ${name}: pid ${pid} does not belong to this service."
      return 1
    fi

    child_pid="${pid}"
    supervisor_pid="$(ps -p "${child_pid}" -o ppid= 2>/dev/null | tr -d '[:space:]' || true)"
    local supervisor_command
    supervisor_command="$(ps -p "${supervisor_pid}" -o command= 2>/dev/null || true)"
    if [ -z "${supervisor_pid}" ] || [[ "${supervisor_command}" != *"${run_script}"* ]]; then
      echo "Refusing to stop ${name}: cannot verify legacy supervisor ownership."
      return 1
    fi
    echo "Detected legacy ${name} pid file; stopping supervisor ${supervisor_pid} and child ${child_pid}."
  fi

  kill -TERM "${supervisor_pid}" 2>/dev/null || true
  if [ -n "${child_pid}" ]; then
    kill -TERM "${child_pid}" 2>/dev/null || true
  fi
  echo "Stopping ${name} supervisor (pid ${supervisor_pid})..."

  local waited=0
  while kill -0 "${supervisor_pid}" 2>/dev/null || {
    [ -n "${child_pid}" ] && kill -0 "${child_pid}" 2>/dev/null
  }; do
    if [ "${waited}" -ge "${STOP_TIMEOUT_SECONDS}" ]; then
      echo "Timed out waiting for ${name} to stop after ${STOP_TIMEOUT_SECONDS} seconds."
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done

  rm -f "${pid_file}"
  echo "Stopped ${name}."
}

FAIL=0
stop_service "2b2t" || FAIL=1
stop_service "lobby" || FAIL=1
stop_service "vc" || FAIL=1
exit "${FAIL}"
