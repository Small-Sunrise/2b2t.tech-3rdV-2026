#!/bin/bash

# Load environment variables from .env if present
if [ -f "${BASH_SOURCE[0]%/*}/../.env" ]; then
  set -a
  source "${BASH_SOURCE[0]%/*}/../.env"
  set +a
fi

# Paper reads the modern-forwarding secret from the environment, keeping it
# out of the git-tracked paper-global.yml.
if [ -n "${FORWARDING_SECRET:-}" ]; then
  export PAPER_VELOCITY_SECRET="${FORWARDING_SECRET}"
fi

PAPER_RUNTIME_CONFIG="$(mktemp -d "${TMPDIR:-/tmp}/2b2t-paper-config.XXXXXX")"
trap 'rm -rf "${PAPER_RUNTIME_CONFIG}"' EXIT
cp -a config/. "${PAPER_RUNTIME_CONFIG}/"

# Inject runtime credentials from .env via the shared helper script
if [ -f "../scripts/inject-db-secrets.sh" ]; then
  LOBBY_DIR="." SURVIVAL_DIR="" bash "../scripts/inject-db-secrets.sh" || exit 1
fi

source "${BASH_SOURCE[0]%/*}/../scripts/service-loop.sh"

# Heap sizing via .env; unset falls back to the historical hardcoded
# 1G/1G/700M values (production defaults are unchanged).
LOBBY_JAVA_XMS="${LOBBY_JAVA_XMS:-1G}"
LOBBY_JAVA_XMX="${LOBBY_JAVA_XMX:-1G}"
LOBBY_JAVA_SOFT_MAX="${LOBBY_JAVA_SOFT_MAX:-700M}"

run_with_restart "Lobby server" "${RESTART_DELAY_SECONDS:-300}" \
  java \
    -Xms"${LOBBY_JAVA_XMS}" -Xmx"${LOBBY_JAVA_XMX}" \
    -XX:SoftMaxHeapSize="${LOBBY_JAVA_SOFT_MAX}" \
    -XX:+IgnoreUnrecognizedVMOptions \
    -XX:+UnlockExperimentalVMOptions \
    -Dfile.encoding=UTF-8 \
    -XX:+AlwaysPreTouch \
    -XX:+DisableExplicitGC \
    -XX:-UseCompressedClassPointers \
    -XX:+UseZGC \
    -XX:+ZGenerational \
    -XX:-ZProactive \
    -XX:ZCollectionIntervalMinor=0.98 \
    -XX:ZUncommitDelay=5 \
    --add-modules jdk.incubator.vector \
    -jar paper.jar --paper-dir "${PAPER_RUNTIME_CONFIG}" --nogui
