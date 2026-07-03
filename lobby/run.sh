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
