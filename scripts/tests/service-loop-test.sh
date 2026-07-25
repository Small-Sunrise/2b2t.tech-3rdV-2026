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
    "test service" 1 "${TEST_DIR}/fake-service.sh"
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
