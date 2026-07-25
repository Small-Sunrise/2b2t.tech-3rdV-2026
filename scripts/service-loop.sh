#!/usr/bin/env bash

# Run a service command with crash restarts while allowing the supervisor to
# terminate the active child cleanly when it receives SIGTERM or SIGINT.
run_with_restart() {
  local label="$1"
  local restart_delay="$2"
  shift 2

  local child_pid=""
  local stopping=0
  local exit_code=0

  request_service_stop() {
    stopping=1
    if [ -n "${child_pid}" ] && kill -0 "${child_pid}" 2>/dev/null; then
      kill -TERM "${child_pid}" 2>/dev/null || true
    fi
  }
  trap request_service_stop TERM INT

  while [ "${stopping}" -eq 0 ]; do
    echo "Starting ${label}..."
    "$@" &
    child_pid=$!

    if wait "${child_pid}"; then
      exit_code=0
    else
      exit_code=$?
    fi

    if [ "${stopping}" -ne 0 ]; then
      # A signal can interrupt wait before the child has finished shutdown.
      wait "${child_pid}" 2>/dev/null || true
      break
    fi

    echo "${label} exited with status ${exit_code}; restarting in ${restart_delay} seconds..."
    sleep "${restart_delay}" &
    child_pid=$!
    wait "${child_pid}" 2>/dev/null || true
  done

  child_pid=""
  trap - TERM INT
  echo "${label} stopped."
}
