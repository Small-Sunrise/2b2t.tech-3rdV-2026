#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$(mktemp -d)"
SUPERVISOR_PID=""

cleanup() {
  if [ -n "${SUPERVISOR_PID}" ] && kill -0 "${SUPERVISOR_PID}" 2>/dev/null; then
    kill -TERM "${SUPERVISOR_PID}" 2>/dev/null || true
    wait "${SUPERVISOR_PID}" 2>/dev/null || true
  fi
  rm -rf "${TEST_DIR}"
}
trap cleanup EXIT

cat > "${TEST_DIR}/fake-service.sh" <<'SH'
#!/usr/bin/env bash
set -u
echo "started" >> "${EVENT_FILE}"
trap 'echo "stopped" >> "${EVENT_FILE}"; exit 0' TERM INT
while true; do
  sleep 0.1
done
SH
chmod +x "${TEST_DIR}/fake-service.sh"

(
  source "${ROOT_DIR}/scripts/service-loop.sh"
  EVENT_FILE="${TEST_DIR}/events" run_with_restart \
    "test service" 1 "" "${TEST_DIR}/fake-service.sh"
) > "${TEST_DIR}/supervisor.log" 2>&1 &
SUPERVISOR_PID=$!

for _ in $(seq 1 50); do
  [ -f "${TEST_DIR}/events" ] && break
  sleep 0.1
done
grep -Fqx "started" "${TEST_DIR}/events"

kill -TERM "${SUPERVISOR_PID}"
wait "${SUPERVISOR_PID}"
SUPERVISOR_PID=""

# Waiting beyond the restart delay proves an intentional stop is not restarted.
sleep 1.2
[ "$(grep -Fxc "started" "${TEST_DIR}/events")" -eq 1 ]
[ "$(grep -Fxc "stopped" "${TEST_DIR}/events")" -eq 1 ]
grep -Fqx "test service stopped." "${TEST_DIR}/supervisor.log"

echo "service-loop test: OK"

# --- Console stop command (Defect 2 seam): a child that ignores TERM must
# still be asked to exit via its console stop command over stdin, and must
# do so quickly, without ever needing escalation to TERM/KILL. This is the
# seam that matters on Windows, where kill -TERM never reaches a native
# java.exe at all; a supervisor that only ever sent TERM would leave this
# fake service running until the (much later) KILL escalation fires.
cat > "${TEST_DIR}/console-service.sh" <<'SH'
#!/usr/bin/env bash
set -u
echo "started" >> "${EVENT_FILE}"
# Deliberately ignore TERM/INT so the test can prove the stop reached the
# child over stdin rather than via a signal.
trap '' TERM INT
read -r line
echo "got:${line}" >> "${EVENT_FILE}"
if [ "${line}" = "pretend-stop" ]; then
  echo "stopped" >> "${EVENT_FILE}"
  exit 0
fi
while true; do sleep 0.1; done
SH
chmod +x "${TEST_DIR}/console-service.sh"

(
  source "${ROOT_DIR}/scripts/service-loop.sh"
  EVENT_FILE="${TEST_DIR}/console-events" run_with_restart \
    "console test service" 1 "pretend-stop" "${TEST_DIR}/console-service.sh" \
    < /dev/null
) > "${TEST_DIR}/console-supervisor.log" 2>&1 &
SUPERVISOR_PID=$!

for _ in $(seq 1 50); do
  [ -f "${TEST_DIR}/console-events" ] && break
  sleep 0.1
done
grep -Fqx "started" "${TEST_DIR}/console-events"

kill -TERM "${SUPERVISOR_PID}"

# The child ignores TERM/INT outright, so a pass here proves the stop
# command reached it over stdin; STOP_TIMEOUT_SECONDS/TERM/KILL escalation
# (many seconds away) never had to fire.
for _ in $(seq 1 30); do
  ! kill -0 "${SUPERVISOR_PID}" 2>/dev/null && break
  sleep 0.1
done
wait "${SUPERVISOR_PID}"
SUPERVISOR_PID=""

grep -Fqx "got:pretend-stop" "${TEST_DIR}/console-events"
grep -Fqx "stopped" "${TEST_DIR}/console-events"

echo "service-loop console-stop test: OK"
