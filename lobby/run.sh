#!/bin/bash

# Load environment variables from .env if present
if [ -f "${BASH_SOURCE[0]%/*}/../.env" ]; then
  set -a
  source "${BASH_SOURCE[0]%/*}/../.env"
  set +a
fi

# Write BungeeGuard token from FORWARDING_SECRET for bungeeguard forwarding
if [ -n "${FORWARDING_SECRET:-}" ]; then
  mkdir -p plugins/BungeeGuard
  printf "%s" "${FORWARDING_SECRET}" > plugins/BungeeGuard/token.txt
fi

# Inject database credentials from .env via shared helper script
if [ -f "../scripts/inject-db-secrets.sh" ]; then
  LOBBY_DIR="." SURVIVAL_DIR="." bash "../scripts/inject-db-secrets.sh"
fi

source "${BASH_SOURCE[0]%/*}/../scripts/service-loop.sh"

run_with_restart "Lobby server" "${RESTART_DELAY_SECONDS:-300}" \
  java \
    -Xms1G -Xmx1G \
    -XX:SoftMaxHeapSize=700M \
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
    -jar paper.jar --nogui
