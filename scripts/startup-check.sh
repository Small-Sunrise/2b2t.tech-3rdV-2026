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
check "AUTHME_DB_PASSWORD is set" '[ -n "${AUTHME_DB_PASSWORD:-}" ]'
check "QUEQIAO_ACCESS_TOKEN is set" '[ -n "${QUEQIAO_ACCESS_TOKEN:-}" ]'

# ---- Server JARs ----
echo ""
echo "[Server JARs]"
check "VC: velocity jar exists" '[ -f "${ROOT_DIR}/VC/velocity-3.5.0-SNAPSHOT-605.jar" ]'
check "lobby: paper.jar exists" '[ -f "${ROOT_DIR}/lobby/paper.jar" ]'
check "2b2t: leaf-26.2-37.jar exists" '[ -f "${ROOT_DIR}/2b2t/leaf-26.2-37.jar" ]'

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
# GNU grep ERE has no \d; the previous pattern never matched anything and
# always fell through to "unknown". This only affects the *displayed*
# version string below -- the actual gate on the next line already used a
# correct ERE ([0-9], not \d) and is left untouched.
JAVA_VER=$(java -version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
check "Java 25+ installed (found: ${JAVA_VER})" 'java -version 2>&1 | grep -qE "version \"(2[5-9]|[3-9][0-9])\."'

# ---- Plugin dirs exist ----
echo ""
echo "[Plugin Directories]"
check "VC plugins dir exists" '[ -d "${ROOT_DIR}/VC/plugins" ]'
check "lobby plugins dir exists" '[ -d "${ROOT_DIR}/lobby/plugins" ]'
check "2b2t plugins dir exists" '[ -d "${ROOT_DIR}/2b2t/plugins" ]'

# ---- ViaVersion suite ----
# lobby speaks protocol 775 and 2b2t speaks 776. Without Via on every hop no
# single client protocol can reach both backends, so these are hard requirements
# rather than optional plugins. Matched by prefix so a version bump does not
# silently turn these checks into false negatives.
echo ""
echo "[ViaVersion Suite (protocol bridge)]"
for dir in "VC" "lobby" "2b2t"; do
  for plugin in "ViaVersion" "ViaBackwards" "ViaRewind"; do
    check "${dir}: ${plugin} jar exists" \
      "find \"\${ROOT_DIR}/${dir}/plugins\" -maxdepth 1 -iname '${plugin}-*.jar' -print -quit | grep -q ."
  done
done

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
# Prefix-matched, like the Via checks: upstream AuthMe 6.0.0 does not publish a
# plain "AuthMe-6.0.0.jar" at all -- its release assets are per-platform
# ("AuthMe-6.0.0-Paper.jar", "-Spigot-1.21", "-Folia", ...), so the old exact
# filename could never be satisfied by an official download. Prefix matching
# also survives a version bump instead of turning into a false negative.
check "lobby: AuthMe jar exists" \
  'find "${ROOT_DIR}/lobby/plugins" -maxdepth 1 -iname "AuthMe-*.jar" -print -quit | grep -q .'
check "lobby: MinePay.jar exists" '[ -f "${ROOT_DIR}/lobby/plugins/MinePay.jar" ]'
check "VC: Floodgate plugin exists for Geyser floodgate auth" 'find "${ROOT_DIR}/VC/plugins" -maxdepth 1 -iname "floodgate*.jar" -print -quit | grep -q .'

# Inverted on purpose: ZNPCsPlus 2.0.0 (the newest upstream release) cannot run
# on this stack at all. Its bundled PacketEvents blows up in onLoad with
# "Version string must be in the format 'major.minor[.patch][+commit]
# [-SNAPSHOT]', found '26.1.2.build.72' instead", so installing the jar buys an
# ERROR on every lobby start and a plugin that does nothing. See the
# compatibility table in PLUGINS.md.
check "lobby: no ZNPCsPlus jar (incompatible with 26.x, see PLUGINS.md)" \
  '! find "${ROOT_DIR}/lobby/plugins" -maxdepth 1 -iname "ZNPCsPlus-*.jar" -print -quit | grep -q .'

# spark is NOT a plugin jar to install here: Paper and Leaf both ship it inside
# the server jar (META-INF/libraries/me/lucko/spark-paper/...), and announce it
# at startup with "This server bundles the spark profiler". Dropping a separate
# spark-*.jar into plugins/ on top of that is a duplicate load, so the check is
# inverted: assert the bundled copy is really there, and that nobody added a
# redundant jar next to it.
for pair in "lobby:paper.jar" "2b2t:leaf-26.2-37.jar"; do
  dir="${pair%%:*}"
  jar="${pair##*:}"
  check "${dir}: spark is bundled in ${jar}" \
    "grep -aq 'spark-paper' \"\${ROOT_DIR}/${dir}/${jar}\" 2>/dev/null"
  check "${dir}: no redundant spark jar in plugins/" \
    "! find \"\${ROOT_DIR}/${dir}/plugins\" -maxdepth 1 -iname 'spark-*.jar' -print -quit | grep -q ."
done

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
check "No BungeeGuard config dir (lobby)" '[ ! -d "${ROOT_DIR}/lobby/plugins/BungeeGuard" ]'
check "No BungeeGuard config dir (2b2t)" '[ ! -d "${ROOT_DIR}/2b2t/plugins/BungeeGuard" ]'
check "No BungeeGuard.jar (lobby, manual removal required if present)" '[ ! -f "${ROOT_DIR}/lobby/plugins/BungeeGuard.jar" ]'
check "No BungeeGuard.jar (2b2t, manual removal required if present)" '[ ! -f "${ROOT_DIR}/2b2t/plugins/BungeeGuard.jar" ]'

# ---- Velocity forwarding ----
echo ""
echo "[Velocity Forwarding]"
check "VC: player-info-forwarding-mode is modern" 'grep -qE "^player-info-forwarding-mode = \"modern\"" "${ROOT_DIR}/VC/velocity.toml"'
check "lobby: proxies.velocity.online-mode is false" 'grep -A2 "  velocity:" "${ROOT_DIR}/lobby/config/paper-global.yml" | grep -q "online-mode: false"'
check "2b2t: proxies.velocity.online-mode is false" 'grep -A2 "  velocity:" "${ROOT_DIR}/2b2t/config/paper-global.yml" | grep -q "online-mode: false"'
check "lobby: spigot.yml bungeecord is false" 'grep -q "^  bungeecord: false" "${ROOT_DIR}/lobby/spigot.yml"'
check "2b2t: spigot.yml bungeecord is false" 'grep -q "^  bungeecord: false" "${ROOT_DIR}/2b2t/spigot.yml"'

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
