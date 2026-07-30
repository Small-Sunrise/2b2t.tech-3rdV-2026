#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="${ROOT_DIR}/pids"
STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-120}"

# Portable process introspection. procps (Linux) supports `-o command=` /
# `-o ppid=` directly. MSYS/Git-Bash `ps` (Windows) has no `-o` at all --
# `ps --help` there lists only `[-aefls] [-u UID] [-p PID]` -- and instead
# always prints a column layout via `-f` with a header row naming each
# column (observed on this host: "UID PID PPID TTY STIME COMMAND"; other
# MSYS/Cygwin builds have been seen with "PID PPID PGID WINPID TTY UID
# STIME COMMAND" -- the column set/order is not something to hardcode).
# PID/PPID/COMMAND are all still available, just not selectable by name, so
# the fallback parses the header row itself to find where "COMMAND" starts
# and where "PPID" lives, rather than assuming a fixed field count/order.
# Probed once so every call below is a plain conditional rather than a
# per-call fallback-on-error dance. This only changes *how* we read process
# info; the safety property (refuse to touch a pid that doesn't belong to
# this service) is unchanged and still enforced below.
PS_SUPPORTS_O=0
if ps -p "$$" -o command= >/dev/null 2>&1; then
  PS_SUPPORTS_O=1
fi

ps_command_for_pid() {
  local pid="$1"
  if [ "${PS_SUPPORTS_O}" -eq 1 ]; then
    ps -p "${pid}" -o command= 2>/dev/null || true
    return
  fi
  # `ps -p PID -f` prints a header row plus at most one data row (already
  # filtered to this pid), so the second line -- with the columns the
  # header said precede COMMAND blanked out -- is exactly the command.
  ps -p "${pid}" -f 2>/dev/null | awk '
    NR == 1 { n = NF - 1; next }
    NR == 2 {
      for (i = 1; i <= n; i++) $i = ""
      sub(/^[[:space:]]+/, "")
      print
    }
  ' || true
}

ps_ppid_for_pid() {
  local pid="$1"
  if [ "${PS_SUPPORTS_O}" -eq 1 ]; then
    ps -p "${pid}" -o ppid= 2>/dev/null | tr -d '[:space:]' || true
    return
  fi
  ps -p "${pid}" -f 2>/dev/null | awk '
    NR == 1 { for (i = 1; i <= NF; i++) if ($i == "PPID") idx = i; next }
    NR == 2 { print $idx }
  ' || true
}

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
      server_jar="leaf-26.2-37.jar"
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
  command="$(ps_command_for_pid "${pid}")"

  if [[ "${command}" != *"${run_script}"* ]]; then
    # Before supervisor PIDs were introduced, run.sh stored the Java child PID.
    # Stop both processes so an in-place upgrade cannot trigger another restart.
    if [[ "${command}" != *"${server_jar}"* ]]; then
      echo "Refusing to stop ${name}: pid ${pid} does not belong to this service."
      return 1
    fi

    child_pid="${pid}"
    supervisor_pid="$(ps_ppid_for_pid "${child_pid}")"
    local supervisor_command
    supervisor_command="$(ps_command_for_pid "${supervisor_pid}")"
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
