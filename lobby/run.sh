#!/bin/bash

# Load environment variables from .env if present
if [ -f "${BASH_SOURCE[0]%/*}/../.env" ]; then
  set -a
  source "${BASH_SOURCE[0]%/*}/../.env"
  set +a
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
    -jar paper.jar --nogui
  echo "大厅关闭，5分钟后自动重启..."
  sleep 300
done
