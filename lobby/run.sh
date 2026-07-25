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

# Inject runtime credentials from .env via the shared helper script
if [ -f "../scripts/inject-db-secrets.sh" ]; then
  LOBBY_DIR="." SURVIVAL_DIR="" bash "../scripts/inject-db-secrets.sh"
fi


while true
do
  echo "启动大厅服务器..."
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
    -jar paper.jar --nogui &
  JAVA_PID=$!
  mkdir -p ../pids
  echo ${JAVA_PID} > ../pids/lobby.pid
  wait ${JAVA_PID}
  echo "大厅关闭，5分钟后自动重启..."
  sleep 300
done
