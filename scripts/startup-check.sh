#!/usr/bin/env bash
# Pre-flight startup check for 2b2t.tech Minecraft network
# Validates that all required files and configurations are in place
# before starting the servers. Run: bash scripts/startup-check.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load .env if present
if [ -f "${ROOT_DIR}/.env" ]; then
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

PASS=0
FAIL=0

check() {
  local desc="$1" condition="$2"
  if eval "${condition}"; then
    echo "  ✓ ${desc}"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== 2b2t.tech Pre-flight Startup Check ==="
echo ""

# ---- .env ----
echo "[.env Configuration]"
check ".env file exists" '[ -f "${ROOT_DIR}/.env" ]'
check "FORWARDING_SECRET is set" '[ -n "${FORWARDING_SECRET:-}" ]'
check "LUCKPERMS_DB_PASSWORD is set" '[ -n "${LUCKPERMS_DB_PASSWORD:-}" ]'

# ---- Server JARs ----
echo ""
echo "[Server JARs]"
check "VC: velocity jar exists" '[ -f "${ROOT_DIR}/VC/velocity-3.5.0-SNAPSHOT-605.jar" ]'
check "lobby: paper.jar exists" '[ -f "${ROOT_DIR}/lobby/paper.jar" ]'
check "2b2t: leaf-26.2-14.jar exists" '[ -f "${ROOT_DIR}/2b2t/leaf-26.2-14.jar" ]'

# ---- EULA ----
echo ""
echo "[EULA Acceptance]"
check "lobby: eula.txt accepted" 'grep -q "eula=true" "${ROOT_DIR}/lobby/eula.txt" 2>/dev/null'
check "2b2t: eula.txt accepted" 'grep -q "eula=true" "${ROOT_DIR}/2b2t/eula.txt" 2>/dev/null'

# ---- Run scripts ----
echo ""
echo "[Run Scripts]"
check "VC run.sh executable" '[ -x "${ROOT_DIR}/VC/run.sh" ]'
check "lobby run.sh executable" '[ -x "${ROOT_DIR}/lobby/run.sh" ]'
check "2b2t run.sh executable" '[ -x "${ROOT_DIR}/2b2t/run.sh" ]'

# ---- Java ----
echo ""
echo "[Java Runtime]"
JAVA_VER=$(java -version 2>&1 | head -1 | grep -oE '\d+\.\d+\.\d+' || echo "unknown")
check "Java 21+ installed (found: ${JAVA_VER})" 'java -version 2>&1 | grep -qE "version \"2[1-9]\."'

# ---- Plugin dirs exist ----
echo ""
echo "[Plugin Directories]"
check "VC plugins dir exists" '[ -d "${ROOT_DIR}/VC/plugins" ]'
check "lobby plugins dir exists" '[ -d "${ROOT_DIR}/lobby/plugins" ]'
check "2b2t plugins dir exists" '[ -d "${ROOT_DIR}/2b2t/plugins" ]'

# ---- LuckPerms config ----
echo ""
echo "[LuckPerms MySQL Config]"
for dir in "lobby" "2b2t"; do
  LP_CONFIG="${ROOT_DIR}/${dir}/plugins/LuckPerms/config.yml"
  if [ -f "${LP_CONFIG}" ]; then
    check "${dir}: LuckPerms config.yml exists" 'true'
    if grep -q "storage-method.*MySQL" "${LP_CONFIG}" 2>/dev/null; then
      check "${dir}: storage-method is MySQL" 'true'
    else
      check "${dir}: storage-method is MySQL" 'false'
    fi
  else
    check "${dir}: LuckPerms config.yml exists" 'false'
  fi
done

# ---- Key plugins present ----
echo ""
echo "[Key Plugins]"
check "lobby: AuthMe.jar exists" '[ -f "${ROOT_DIR}/lobby/plugins/AuthMe-6.0.0.jar" ]'
check "lobby: ZNPCsPlus-2.0.0.jar exists" '[ -f "${ROOT_DIR}/lobby/plugins/ZNPCsPlus-2.0.0.jar" ]'
check "lobby: MinePay.jar exists" '[ -f "${ROOT_DIR}/lobby/plugins/MinePay.jar" ]'
check "lobby: BungeeGuard.jar exists" '[ -f "${ROOT_DIR}/lobby/plugins/BungeeGuard.jar" ]'
check "2b2t: BungeeGuard.jar exists" '[ -f "${ROOT_DIR}/2b2t/plugins/BungeeGuard.jar" ]'
check "2b2t: spark plugin exists" 'ls "${ROOT_DIR}/2b2t/plugins/spark-"*.jar >/dev/null 2>&1'

# ---- No stale disabled plugins ----
echo ""
echo "[Cleanup Verification]"
check "No CommandSync .jar.disabled" '[ ! -f "${ROOT_DIR}/2b2t/plugins/CommandSync-2.8.4.jar.disabled" ]'
check "No CommandSync config dir (2b2t)" '[ ! -d "${ROOT_DIR}/2b2t/plugins/CommandSync" ]'
check "No CommandSync config dir (lobby)" '[ ! -d "${ROOT_DIR}/lobby/plugins/CommandSync" ]'
check "No CommandSync config dir (VC)" '[ ! -d "${ROOT_DIR}/VC/plugins/commandsync" ]'
check "No ServersNPC dir (lobby)" '[ ! -d "${ROOT_DIR}/lobby/plugins/ServersNPC" ]'
check "No ServersNPC dir (2b2t)" '[ ! -d "${ROOT_DIR}/2b2t/plugins/ServersNPC" ]'
check "No Srepay dir (lobby)" '[ ! -d "${ROOT_DIR}/lobby/plugins/Srepay" ]'

# ---- Summary ----
echo ""
echo "=============================="
echo "Total: $((PASS + FAIL)) checks, ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -eq 0 ]; then
  echo "Status: READY - all checks passed."
  exit 0
else
  echo "Status: NOT READY - fix the ${FAIL} failing checks above."
  exit 1
fi
