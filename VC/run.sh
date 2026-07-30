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

if [ -n "${FORWARDING_SECRET}" ]; then
    printf '%s' "${FORWARDING_SECRET}" > forwarding.secret
fi

if [ -n "${FLOODGATE_KEY_PEM}" ]; then
    mkdir -p plugins/floodgate
    printf '%b' "${FLOODGATE_KEY_PEM}" > plugins/floodgate/key.pem
fi

# Inject runtime credentials from .env via the shared helper script
if [ -f "../scripts/inject-db-secrets.sh" ]; then
  VC_DIR="." bash "../scripts/inject-db-secrets.sh" || exit 1
fi

source "${SCRIPT_DIR}/../scripts/service-loop.sh"

# Heap sizing via .env; unset falls back to the historical hardcoded 1G/1G
# values (production defaults are unchanged).
VELOCITY_JAVA_XMS="${VELOCITY_JAVA_XMS:-1G}"
VELOCITY_JAVA_XMX="${VELOCITY_JAVA_XMX:-1G}"

# AlwaysPreTouch is unconditional in production. It is actively harmful when
# Xmx exceeds physical RAM (forces every heap page to be committed up
# front), so make it opt-out via .env: set JAVA_ALWAYS_PRE_TOUCH=0 to disable
# it. Leaving it unset preserves today's production behavior. Mirrors the
# .bat launchers' PRETOUCH_FLAG. Held in an array (rather than a bare
# variable expanded unquoted) so an empty/disabled flag does not require an
# unquoted expansion to vanish from the command line.
PRETOUCH_FLAG=(-XX:+AlwaysPreTouch)
if [ "${JAVA_ALWAYS_PRE_TOUCH:-}" = "0" ]; then
  PRETOUCH_FLAG=()
fi

# Velocity speaks its own console commands; "end" is Velocity's stop command
# (Paper/Leaf use "stop" -- see lobby/run.sh and 2b2t/run.sh).
run_with_restart "Velocity proxy" "${RESTART_DELAY_SECONDS:-300}" "end" \
  java \
      -Xms"${VELOCITY_JAVA_XMS}" -Xmx"${VELOCITY_JAVA_XMX}" \
      -XX:+UnlockExperimentalVMOptions \
      -XX:+IgnoreUnrecognizedVMOptions \
      -XX:+UseZGC \
      -XX:+DisableExplicitGC \
      -XX:+PerfDisableSharedMem \
      -XX:+UseStringDeduplication \
      -XX:+UseDynamicNumberOfGCThreads \
      -Dfile.encoding=UTF-8 \
      "${PRETOUCH_FLAG[@]}" \
      -jar velocity-3.5.0-SNAPSHOT-605.jar
