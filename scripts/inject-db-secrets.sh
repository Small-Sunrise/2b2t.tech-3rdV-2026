#!/usr/bin/env bash
# Inject database credentials from environment into plugin config files.
# Call from server startup scripts after sourcing .env.
set -euo pipefail

inject_luckperms() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${LUCKPERMS_DB_PASSWORD:-}" ] || return 0

  python3 - "${config}" <<'PY'
import os
import sys
import tempfile

config_path = sys.argv[1]
values = {
    "address": os.environ.get("LUCKPERMS_DB_HOST", "127.0.0.1:3306"),
    "database": os.environ.get("LUCKPERMS_DB_NAME", "luckperms_2b2t"),
    "username": os.environ.get("LUCKPERMS_DB_USER", "lpsql"),
    "password": os.environ.get("LUCKPERMS_DB_PASSWORD", ""),
}


def yaml_string(value):
    return "'" + value.replace("'", "''") + "'"


with open(config_path, encoding="utf-8") as config_file:
    lines = config_file.readlines()

in_data = False
for index, line in enumerate(lines):
    if line.rstrip("\r\n") == "data:":
        in_data = True
        continue
    if in_data and line.strip() and not line.startswith((" ", "\t", "#")):
        break
    if not in_data:
        continue
    for key, value in values.items():
        if line.startswith(f"  {key}:"):
            newline = "\r\n" if line.endswith("\r\n") else "\n"
            lines[index] = f"  {key}: {yaml_string(value)}{newline}"
            break

directory = os.path.dirname(os.path.abspath(config_path))
with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, delete=False) as output:
    output.writelines(lines)
    temp_path = output.name
os.chmod(temp_path, os.stat(config_path).st_mode)
os.replace(temp_path, config_path)
PY
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


inject_authme() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${AUTHME_DB_PASSWORD:-}" ] || return 0

  python3 -c "
import os, re, sys
config_path = sys.argv[1]
with open(config_path, 'r') as f:
    c = f.read()
c = re.sub(r'^    mySQLPassword:.*', "    mySQLPassword: '" + os.environ.get('AUTHME_DB_PASSWORD','') + "'", c, flags=re.M)
c = re.sub(r'^    mySQLUsername:.*', '    mySQLUsername: ' + os.environ.get('AUTHME_DB_USER','authme'), c, flags=re.M)
c = re.sub(r'^    mySQLHost:.*', '    mySQLHost: ' + os.environ.get('AUTHME_DB_HOST','127.0.0.1'), c, flags=re.M)
c = re.sub(r'^    mySQLDatabase:.*', '    mySQLDatabase: ' + os.environ.get('AUTHME_DB_NAME','authme'), c, flags=re.M)
with open(config_path, 'w') as f:
    f.write(c)
" "${config}"
}

# Inject into all applicable configs
for dir in "${LOBBY_DIR:-}" "${SURVIVAL_DIR:-}" "."; do
  [ -d "${dir}" ] || continue
  inject_luckperms "${dir}/plugins/LuckPerms/config.yml"
done

if [ -n "${LOBBY_DIR:-}" ]; then
  inject_authme "${LOBBY_DIR}/plugins/AuthMe/config.yml"
fi

if [ -n "${SURVIVAL_DIR:-}" ]; then
  inject_tab "${SURVIVAL_DIR}/plugins/TAB/config.yml"
fi
