#!/usr/bin/env bash
set -euo pipefail

: "${FORWARDING_SECRET:?FORWARDING_SECRET is required}"
: "${SERVER_ROLE:?SERVER_ROLE must be lobby or survival}"
export PAPER_VELOCITY_SECRET="${FORWARDING_SECRET}"

# Paper serializes environment overrides back to its configuration. Use a
# container-local copy so runtime secrets never enter the bind-mounted repo.
rm -rf /runtime-server
mkdir -p /runtime-server/paper-config /runtime-server/plugins
if [ -d /data/config ]; then
  cp -a /data/config/. /runtime-server/paper-config/
fi

# Keep ordinary plugin data persistent, but isolate configs that receive
# credentials at startup so injected values never enter the host checkout.
for path in /data/plugins/*; do
  [ -e "${path}" ] || continue
  name="$(basename "${path}")"
  sensitive=false
  case "${name}" in
    LuckPerms) sensitive=true ;;
    AuthMe) [ "${SERVER_ROLE}" = lobby ] && sensitive=true ;;
    TAB) [ "${SERVER_ROLE}" = survival ] && sensitive=true ;;
  esac
  if [ "${sensitive}" = true ] && [ -d "${path}" ]; then
    cp -a "${path}" "/runtime-server/plugins/${name}"
  else
    ln -s "${path}" "/runtime-server/plugins/${name}"
  fi
done

case "${SERVER_ROLE}" in
  lobby)
    LOBBY_DIR=/runtime-server SURVIVAL_DIR='' /usr/local/bin/inject-runtime-credentials
    ;;
  survival)
    LOBBY_DIR='' SURVIVAL_DIR=/runtime-server /usr/local/bin/inject-runtime-credentials
    ;;
  *)
    echo "Unsupported SERVER_ROLE: ${SERVER_ROLE}" >&2
    exit 2
    ;;
esac

java_args=("-Xms${JAVA_XMS:-1G}" "-Xmx${JAVA_XMX:-1G}")
if [ -n "${JAVA_SOFT_MAX:-}" ]; then
  java_args+=("-XX:SoftMaxHeapSize=${JAVA_SOFT_MAX}")
fi
java_args+=(
  -XX:+UseZGC -XX:+AlwaysPreTouch -XX:+DisableExplicitGC
  -Dfile.encoding=UTF-8 --add-modules jdk.incubator.vector
  -jar /app/server.jar
  --paper-dir /runtime-server/paper-config
  --plugins /runtime-server/plugins
  --nogui
)
exec java "${java_args[@]}"
