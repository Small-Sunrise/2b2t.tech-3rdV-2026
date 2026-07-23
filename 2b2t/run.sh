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

run_with_restart "2b2t server" "${RESTART_DELAY_SECONDS:-300}" \
  java \
    -Xms8G -Xmx8G \
    -XX:SoftMaxHeapSize=6G \
    -XX:+IgnoreUnrecognizedVMOptions \
    -XX:+UnlockExperimentalVMOptions \
    -Dfile.encoding=UTF-8 \
    -XX:+AlwaysPreTouch \
    -XX:+DisableExplicitGC \
    -XX:-UseCompressedClassPointers \
    -XX:-UseG1GC \
    -XX:+UseZGC \
    -XX:+ZGenerational \
    -XX:-ZProactive \
    -XX:ZCollectionIntervalMinor=0.95 \
    -XX:ZUncommitDelay=5 \
    --add-modules jdk.incubator.vector \
    -Xlog:gc*:logs/gc.log:time,level,tags:filecount=5,filesize=20M \
    -jar leaf-26.2-14.jar --nogui
