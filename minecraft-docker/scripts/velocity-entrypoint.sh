#!/usr/bin/env bash
set -euo pipefail

: "${FORWARDING_SECRET:?FORWARDING_SECRET is required}"

cd /
rm -rf /runtime
mkdir -p /runtime/plugins
cd /runtime
sed \
  -e 's#lobby = "127\.0\.0\.1:50015"#lobby = "lobby:50015"#' \
  -e 's#2b2t = "127\.0\.0\.1:50013"#2b2t = "survival:50013"#' \
  /config/velocity.toml > /runtime/velocity.toml

grep -Fq 'lobby = "lobby:50015"' /runtime/velocity.toml
grep -Fq '2b2t = "survival:50013"' /runtime/velocity.toml
printf '%s' "${FORWARDING_SECRET}" > /runtime/forwarding.secret
if [ -n "${FLOODGATE_KEY_PEM:-}" ]; then
  mkdir -p /config/plugins/floodgate
  printf '%b' "${FLOODGATE_KEY_PEM}" > /config/plugins/floodgate/key.pem
fi

for path in /config/plugins/*; do
  [ -e "${path}" ] || continue
  name="$(basename "${path}")"
  case "${name}" in
    QueQiao|luckperms)
      if [ -d "${path}" ]; then
        cp -a "${path}" "/runtime/plugins/${name}"
      else
        ln -s "${path}" "/runtime/plugins/${name}"
      fi
      ;;
    *) ln -s "${path}" "/runtime/plugins/${name}" ;;
  esac
done
for path in lang server-icon.png; do
  if [ -e "/config/${path}" ]; then
    ln -s "/config/${path}" "/runtime/${path}"
  fi
done

VC_DIR=/runtime LOBBY_DIR='' SURVIVAL_DIR='' /usr/local/bin/inject-runtime-credentials

exec java \
  "-Xms${JAVA_XMS:-512M}" "-Xmx${JAVA_XMX:-1G}" \
  -XX:+UseZGC -XX:+AlwaysPreTouch -XX:+DisableExplicitGC \
  -jar /app/velocity.jar
