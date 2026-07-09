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

while true
do
  echo "启动 Velocity 代理..."
  java \
      -Xms1G -Xmx1G \
      -XX:+UnlockExperimentalVMOptions \
      -XX:+IgnoreUnrecognizedVMOptions \
      -XX:+UseZGC \
      -XX:+ZGenerational \
      -XX:+AlwaysPreTouch \
      -XX:+DisableExplicitGC \
      -XX:+PerfDisableSharedMem \
      -XX:+UseStringDeduplication \
      -XX:+UseDynamicNumberOfGCThreads \
      -jar velocity-3.5.0-SNAPSHOT-605.jar &
  JAVA_PID=$!
  mkdir -p ../pids
  echo ${JAVA_PID} > ../pids/vc.pid
  wait ${JAVA_PID}
  echo "Velocity 已关闭，5 分钟后重启..."
  sleep 300
done
