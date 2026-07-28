#!/bin/bash

# Load environment variables from .env if present
if [ -f "${BASH_SOURCE[0]%/*}/../.env" ]; then
  set -a
  source "${BASH_SOURCE[0]%/*}/../.env"
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

source "${BASH_SOURCE[0]%/*}/../scripts/service-loop.sh"

# Heap sizing via .env; unset falls back to the historical hardcoded 1G/1G
# values (production defaults are unchanged).
VELOCITY_JAVA_XMS="${VELOCITY_JAVA_XMS:-1G}"
VELOCITY_JAVA_XMX="${VELOCITY_JAVA_XMX:-1G}"

run_with_restart "Velocity proxy" "${RESTART_DELAY_SECONDS:-300}" \
  java \
      -Xms"${VELOCITY_JAVA_XMS}" -Xmx"${VELOCITY_JAVA_XMX}" \
      -XX:+UnlockExperimentalVMOptions \
      -XX:+IgnoreUnrecognizedVMOptions \
      -XX:+UseZGC \
      -XX:+ZGenerational \
      -XX:+AlwaysPreTouch \
      -XX:+DisableExplicitGC \
      -XX:+PerfDisableSharedMem \
      -XX:+UseStringDeduplication \
      -XX:+UseDynamicNumberOfGCThreads \
      -jar velocity-3.5.0-SNAPSHOT-605.jar
