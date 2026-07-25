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
  LOBBY_DIR="" SURVIVAL_DIR="." bash "../scripts/inject-db-secrets.sh" || exit 1
fi


while true
do
  echo "启动 2b2t 服务器..."
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
    -jar leaf-26.2-14.jar --paper-dir "${PAPER_RUNTIME_CONFIG}" --nogui &
  JAVA_PID=$!
  mkdir -p ../pids
  echo ${JAVA_PID} > ../pids/2b2t.pid
  wait ${JAVA_PID}
  echo "服务器已关闭，5 分钟后重启..."
  sleep 300
done
