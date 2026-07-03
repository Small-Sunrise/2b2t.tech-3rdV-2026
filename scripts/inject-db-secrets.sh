#!/usr/bin/env bash
# Inject database credentials from environment into plugin config files.
# Call from server startup scripts after sourcing .env.
set -euo pipefail

inject_luckperms() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${LUCKPERMS_DB_PASSWORD:-}" ] || return 0

  python3 -c "
import os, re, sys
config_path = sys.argv[1]
with open(config_path, 'r') as f:
    c = f.read()
c = re.sub(r'^  password:.*', \"  password: '\" + os.environ.get('LUCKPERMS_DB_PASSWORD','') + \"'\", c, flags=re.M)
c = re.sub(r'^  username:.*', '  username: ' + os.environ.get('LUCKPERMS_DB_USER','lpsql'), c, flags=re.M)
c = re.sub(r'^  address:.*', '  address: ' + os.environ.get('LUCKPERMS_DB_HOST','127.0.0.1:3306'), c, flags=re.M)
c = re.sub(r'^  database:.*', '  database: ' + os.environ.get('LUCKPERMS_DB_NAME','luckperms_2b2t'), c, flags=re.M)
with open(config_path, 'w') as f:
    f.write(c)
" "${config}"
}

inject_tab() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${TAB_DB_PASSWORD:-}" ] || return 0

  python3 -c "
import os, re, sys
config_path = sys.argv[1]
with open(config_path, 'r') as f:
    c = f.read()
c = re.sub(r'^  password:.*', '  password: ' + os.environ.get('TAB_DB_PASSWORD',''), c, flags=re.M)
c = re.sub(r'^  username:.*', '  username: ' + os.environ.get('TAB_DB_USER','user'), c, flags=re.M)
c = re.sub(r'^  database:.*', '  database: ' + os.environ.get('TAB_DB_NAME','tab'), c, flags=re.M)
with open(config_path, 'w') as f:
    f.write(c)
" "${config}"
}

# Inject into all applicable configs
for dir in "${LOBBY_DIR:-}" "${SURVIVAL_DIR:-}" "."; do
  [ -d "${dir}" ] || continue
  inject_luckperms "${dir}/plugins/LuckPerms/config.yml"
done

if [ -n "${SURVIVAL_DIR:-}" ]; then
  inject_tab "${SURVIVAL_DIR}/plugins/TAB/config.yml"
fi
