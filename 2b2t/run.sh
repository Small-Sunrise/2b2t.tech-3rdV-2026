#!/bin/bash

# Resolve this script's own directory. Deliberately via `dirname` rather than
# "${BASH_SOURCE[0]%/*}": that expansion returns the string unchanged when it
# contains no slash, so invoking this as `bash run.sh` from inside the server
# directory made every path below resolve against "run.sh/..", silently
# skipping .env (an empty forwarding secret then only fails later, at login)
# and failing to source service-loop.sh at all. `dirname` returns "." here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env if present
if [ -f "${SCRIPT_DIR}/../.env" ]; then
  set -a
  source "${SCRIPT_DIR}/../.env"
  set +a
fi

# Paper reads the modern-forwarding secret from the environment, keeping it
# out of the git-tracked paper-global.yml.
if [ -n "${FORWARDING_SECRET:-}" ]; then
  export PAPER_VELOCITY_SECRET="${FORWARDING_SECRET}"
fi

# Paper rewrites these source-controlled configs even when their settings do
# not change. Run against disposable copies, as the lobby launcher does.
SURVIVAL_RUNTIME_CONFIG="$(mktemp -d "${TMPDIR:-/tmp}/2b2t-survival-config.XXXXXX")"
trap 'rm -rf "${SURVIVAL_RUNTIME_CONFIG}"' EXIT
cp -a config/. "${SURVIVAL_RUNTIME_CONFIG}/"
cp -a server.properties bukkit.yml commands.yml spigot.yml "${SURVIVAL_RUNTIME_CONFIG}/"

# Inject runtime credentials from .env via the shared helper script
if [ -f "../scripts/inject-db-secrets.sh" ]; then
  LOBBY_DIR="" SURVIVAL_DIR="." bash "../scripts/inject-db-secrets.sh" || exit 1
fi

source "${SCRIPT_DIR}/../scripts/service-loop.sh"

# Heap sizing via .env; unset falls back to the historical hardcoded
# 8G/8G/6G values (production defaults are unchanged).
SURVIVAL_JAVA_XMS="${SURVIVAL_JAVA_XMS:-8G}"
SURVIVAL_JAVA_XMX="${SURVIVAL_JAVA_XMX:-8G}"
SURVIVAL_JAVA_SOFT_MAX="${SURVIVAL_JAVA_SOFT_MAX:-6G}"

# AlwaysPreTouch is unconditional in production. It is actively harmful when
# Xmx exceeds physical RAM (forces every heap page to be committed up
# front), so make it opt-out via .env: set JAVA_ALWAYS_PRE_TOUCH=0 to disable
# it. Leaving it unset preserves today's production behavior. Mirrors the
# .bat launchers' PRETOUCH_FLAG. Held in an array so a disabled flag needs
# no unquoted expansion to vanish from the command line.
PRETOUCH_FLAG=(-XX:+AlwaysPreTouch)
if [ "${JAVA_ALWAYS_PRE_TOUCH:-}" = "0" ]; then
  PRETOUCH_FLAG=()
fi

# Leaf (Paper-based)'s console stop command is "stop" (Velocity uses "end").
run_with_restart "2b2t server" "${RESTART_DELAY_SECONDS:-300}" "stop" \
  java \
    -Xms"${SURVIVAL_JAVA_XMS}" -Xmx"${SURVIVAL_JAVA_XMX}" \
    -XX:SoftMaxHeapSize="${SURVIVAL_JAVA_SOFT_MAX}" \
    -XX:+IgnoreUnrecognizedVMOptions \
    -XX:+UnlockExperimentalVMOptions \
    -Dfile.encoding=UTF-8 \
    "${PRETOUCH_FLAG[@]}" \
    -XX:+DisableExplicitGC \
    -XX:-UseG1GC \
    -XX:+UseZGC \
    -XX:-ZProactive \
    -XX:ZCollectionIntervalMinor=0.95 \
    -XX:ZUncommitDelay=5 \
    --add-modules jdk.incubator.vector \
    -Xlog:gc*:logs/gc.log:time,level,tags:filecount=5,filesize=20M \
    -jar leaf-26.2-37.jar \
    --paper-dir "${SURVIVAL_RUNTIME_CONFIG}" \
    --config "${SURVIVAL_RUNTIME_CONFIG}/server.properties" \
    --bukkit-settings "${SURVIVAL_RUNTIME_CONFIG}/bukkit.yml" \
    --commands-settings "${SURVIVAL_RUNTIME_CONFIG}/commands.yml" \
    --spigot-settings "${SURVIVAL_RUNTIME_CONFIG}/spigot.yml" \
    --nogui
