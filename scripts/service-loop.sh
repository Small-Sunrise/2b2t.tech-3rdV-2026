#!/usr/bin/env bash

# Run a service command with crash restarts while allowing the supervisor to
# terminate the active child cleanly when it receives SIGTERM or SIGINT.
#
# --- Why a plain `kill -TERM` is not enough on Windows ---
# On Linux, `kill -TERM` reaches the JVM and its shutdown hook saves the
# world before exiting. On Windows, MSYS/Git-Bash `kill -TERM` against a
# *native* (non-MSYS) process such as java.exe delivers no POSIX signal at
# all: MSYS's `kill` falls back to TerminateProcess(), which kills the JVM
# instantly with NO shutdown hook and NO world save (measured: java gone in
# well under a second, with none of "Saving chunks"/"All dimensions are
# saved" in the log). The only proven way to shut a native Windows JVM down
# cleanly is to feed its console the server's own stop command ("stop" for
# Paper/Leaf, "end" for Velocity) on stdin, exactly as if an operator had
# typed it, and let the JVM exit on its own -- this is exactly how the old
# `.bat` launchers' "stop" delivery worked.
#
# --- Getting a command onto the child's stdin ---
# A Cygwin/MSYS FIFO (mkfifo) is emulated in user space; a native process
# generally cannot open/read one, so it cannot be used here. A Cygwin/MSYS
# *pipe* -- the kind created by pipe(2), i.e. an ordinary shell pipeline or
# bash's `coproc` -- is backed by a real Windows anonymous pipe object, and
# native processes read from it exactly like the `.bat` driver's "stop" did.
# So when a stop command is supplied, the child is started with `coproc`
# instead of a bare `"$@" &`: that wires a real pipe straight to its stdin,
# giving us a writable fd to send the stop command through on demand.
# `coproc`'s fds must be re-exec'd onto fixed descriptors immediately
# (`exec {fd}<&"${COPROC[0]}"`) -- bash is known to close its own
# higher-numbered coproc fds across forks otherwise, which silently breaks
# any redirection that references `${COPROC[0]}`/`${COPROC[1]}` directly in
# a later command (confirmed: without this, `<&"${COPROC[0]}"` in a
# subsequent command fails with "Bad file descriptor").
#
# `coproc` also redirects the child's *stdout* into a second pipe, which we
# must drain ourselves (a background `cat`) or a chatty child would fill the
# pipe buffer and block forever trying to write to its own console. The
# child's stderr is untouched by coproc and keeps flowing through normally.
#
# --- Interactive use is preserved ---
# An operator running `run.sh` directly at a terminal can type `stop`/`say
# ...` into java today because java inherits the tty. `run-all.sh` never
# gives the supervised services a tty (`nohup ... > log 2>&1 &`; confirmed
# empirically that `[ -t 0 ]` is false all the way down that chain), while a
# human at an interactive prompt has a real tty on fd 0. So the pipe/coproc
# path is only used when a stop command was supplied AND stdin is not a
# tty; running run.sh by hand is unaffected and java keeps the real console.
run_with_restart() {
  local label="$1"
  local restart_delay="$2"
  local stop_command="$3"
  shift 3

  local child_pid=""
  local child_stdin_fd=""
  local child_stdout_fd=""
  local relay_pid=""
  local stopping=0
  local exit_code=0

  local use_pipe=0
  if [ -n "${stop_command}" ] && [ ! -t 0 ]; then
    use_pipe=1
  fi

  # Once the console stop command has been sent, wait up to
  # STOP_TIMEOUT_SECONDS (the same variable/default stop-all.sh already
  # exposes) for the child to exit on its own, then TERM, then KILL as a
  # last resort -- the two fallbacks that were always in place, kept as a
  # safety net for a stuck/unresponsive child.
  escalate_stop() {
    local timeout="${STOP_TIMEOUT_SECONDS:-120}"
    local waited=0
    while kill -0 "${child_pid}" 2>/dev/null; do
      if [ "${waited}" -ge "${timeout}" ]; then
        echo "${label}: did not stop within ${timeout}s of the console stop command; sending TERM."
        kill -TERM "${child_pid}" 2>/dev/null || true
        local term_waited=0
        while kill -0 "${child_pid}" 2>/dev/null; do
          if [ "${term_waited}" -ge 10 ]; then
            echo "${label}: did not stop within 10s of TERM; sending KILL."
            kill -KILL "${child_pid}" 2>/dev/null || true
            break
          fi
          sleep 1
          term_waited=$((term_waited + 1))
        done
        break
      fi
      sleep 1
      waited=$((waited + 1))
    done
  }

  request_service_stop() {
    stopping=1
    if [ -z "${child_pid}" ] || ! kill -0 "${child_pid}" 2>/dev/null; then
      return
    fi
    if [ -n "${child_stdin_fd}" ]; then
      echo "${label}: sending console stop command (${stop_command})..."
      { printf '%s\n' "${stop_command}" >&"${child_stdin_fd}"; } 2>/dev/null || true
      escalate_stop
    else
      # No pipe for this run (no stop command configured, or this child is
      # actually the restart-delay `sleep`, not the service) -- TERM it
      # directly, same as before.
      kill -TERM "${child_pid}" 2>/dev/null || true
    fi
  }
  trap request_service_stop TERM INT

  while [ "${stopping}" -eq 0 ]; do
    echo "Starting ${label}..."
    child_stdin_fd=""
    child_stdout_fd=""
    relay_pid=""

    if [ "${use_pipe}" -eq 1 ]; then
      coproc "$@"
      child_pid=${COPROC_PID}
      exec {child_stdin_fd}>&"${COPROC[1]}"
      exec {child_stdout_fd}<&"${COPROC[0]}"
      cat <&"${child_stdout_fd}" &
      relay_pid=$!
    else
      "$@" &
      child_pid=$!
    fi

    if wait "${child_pid}"; then
      exit_code=0
    else
      exit_code=$?
    fi

    if [ -n "${child_stdin_fd}" ]; then
      exec {child_stdin_fd}>&- 2>/dev/null || true
      exec {child_stdout_fd}<&- 2>/dev/null || true
      wait "${relay_pid}" 2>/dev/null || true
      child_stdin_fd=""
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
