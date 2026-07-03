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

# Inject database credentials from .env into plugin configs
if [ -n "${LUCKPERMS_DB_PASSWORD:-}" ] && [ -f "plugins/LuckPerms/config.yml" ]; then
  sed -i '' "s/^  password:.*/  password: '${LUCKPERMS_DB_PASSWORD}'/" plugins/LuckPerms/config.yml
  sed -i '' "s/^  username:.*/  username: ${LUCKPERMS_DB_USER:-lpsql}/" plugins/LuckPerms/config.yml
  sed -i '' "s|^  address:.*|  address: ${LUCKPERMS_DB_HOST:-127.0.0.1:3306}|" plugins/LuckPerms/config.yml
  sed -i '' "s/^  database:.*/  database: ${LUCKPERMS_DB_NAME:-luckperms_2b2t}/" plugins/LuckPerms/config.yml
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
    -jar leaf-26.2-14.jar --nogui
  echo "服务器已关闭，5 分钟后重启..."
  sleep 300
done
