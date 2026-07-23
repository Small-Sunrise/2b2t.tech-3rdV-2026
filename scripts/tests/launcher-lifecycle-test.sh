#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$(mktemp -d)"

cleanup() {
  STOP_TIMEOUT_SECONDS=2 bash "${TEST_DIR}/stop-all.sh" >/dev/null 2>&1 || true
  rm -rf "${TEST_DIR}"
}
trap cleanup EXIT

mkdir -p "${TEST_DIR}/scripts" "${TEST_DIR}/VC" "${TEST_DIR}/lobby" "${TEST_DIR}/2b2t"
cp "${ROOT_DIR}/run-all.sh" "${ROOT_DIR}/stop-all.sh" "${TEST_DIR}/"
cp "${ROOT_DIR}/scripts/service-loop.sh" "${TEST_DIR}/scripts/"

for service in VC lobby 2b2t; do
  cat > "${TEST_DIR}/${service}/run.sh" <<'SH'
#!/usr/bin/env bash
source "../scripts/service-loop.sh"
EVENT_FILE="${PWD}/events" run_with_restart "fake service" 1 bash -c '
  echo started >> "${EVENT_FILE}"
  trap "echo stopped >> \"${EVENT_FILE}\"; exit 0" TERM INT
  while true; do sleep 0.1; done
'
SH
  chmod +x "${TEST_DIR}/${service}/run.sh"
done

bash "${TEST_DIR}/run-all.sh"

for service in VC lobby 2b2t; do
  for _ in $(seq 1 50); do
    [ -f "${TEST_DIR}/${service}/events" ] && break
    sleep 0.1
  done
  grep -Fqx "started" "${TEST_DIR}/${service}/events"
done

STOP_TIMEOUT_SECONDS=5 bash "${TEST_DIR}/stop-all.sh"
sleep 1.2

for service in VC lobby 2b2t; do
  [ "$(grep -Fxc "started" "${TEST_DIR}/${service}/events")" -eq 1 ]
  [ "$(grep -Fxc "stopped" "${TEST_DIR}/${service}/events")" -eq 1 ]
done

[ ! -e "${TEST_DIR}/pids/vc.pid" ]
[ ! -e "${TEST_DIR}/pids/lobby.pid" ]
[ ! -e "${TEST_DIR}/pids/2b2t.pid" ]

# Verify upgrades from pid files that contain the Java child rather than the
# run.sh supervisor do not leave the old restart loop alive.
ln -s /bin/sleep "${TEST_DIR}/2b2t/leaf-26.2-14.jar"
cat > "${TEST_DIR}/2b2t/run.sh" <<SH
#!/usr/bin/env bash
while true; do
  "${TEST_DIR}/2b2t/leaf-26.2-14.jar" 30 &
  child_pid=\$!
  printf '%s\n' "\${child_pid}" > "${TEST_DIR}/pids/2b2t.pid"
  wait "\${child_pid}"
  sleep 1
done
SH
chmod +x "${TEST_DIR}/2b2t/run.sh"
bash "${TEST_DIR}/2b2t/run.sh" &
LEGACY_SUPERVISOR_PID=$!

for _ in $(seq 1 50); do
  [ -f "${TEST_DIR}/pids/2b2t.pid" ] && break
  sleep 0.1
done
STOP_TIMEOUT_SECONDS=5 bash "${TEST_DIR}/stop-all.sh"
wait "${LEGACY_SUPERVISOR_PID}" 2>/dev/null || true
sleep 1.2
[ ! -e "${TEST_DIR}/pids/2b2t.pid" ]
if kill -0 "${LEGACY_SUPERVISOR_PID}" 2>/dev/null; then
  echo "legacy supervisor is still running"
  exit 1
fi

echo "launcher lifecycle test: OK"
