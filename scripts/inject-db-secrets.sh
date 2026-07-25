#!/usr/bin/env bash
# Inject runtime credentials from environment variables into plugin configs.
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


def atomic_write(path, content):
    directory = os.path.dirname(os.path.abspath(path))
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, delete=False) as output:
        output.writelines(content)
        temp_path = output.name
    os.chmod(temp_path, os.stat(path).st_mode)
    os.replace(temp_path, path)


atomic_write(config_path, lines)
PY
}

inject_tab() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${TAB_DB_PASSWORD:-}" ] || return 0

  python3 - "${config}" <<'PY'
import os
import re
import sys
import tempfile

config_path = sys.argv[1]
with open(config_path, encoding="utf-8") as config_file:
    content = config_file.read()
def yaml_string(value):
    return "'" + value.replace("'", "''") + "'"


content = re.sub(r"^  password:.*", "  password: " + yaml_string(os.environ.get("TAB_DB_PASSWORD", "")), content, count=1, flags=re.M)
content = re.sub(r"^  username:.*", "  username: " + yaml_string(os.environ.get("TAB_DB_USER", "user")), content, count=1, flags=re.M)
content = re.sub(r"^  database:.*", "  database: " + yaml_string(os.environ.get("TAB_DB_NAME", "tab")), content, count=1, flags=re.M)

directory = os.path.dirname(os.path.abspath(config_path))
with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, delete=False) as output:
    output.write(content)
    temp_path = output.name
os.chmod(temp_path, os.stat(config_path).st_mode)
os.replace(temp_path, config_path)
PY
}

inject_authme() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${AUTHME_DB_PASSWORD:-}" ] || return 0

  python3 - "${config}" <<'PY'
import os
import re
import sys
import tempfile

config_path = sys.argv[1]


def yaml_string(value):
    return "'" + value.replace("'", "''") + "'"


with open(config_path, encoding="utf-8") as config_file:
    content = config_file.read()

password = yaml_string(os.environ.get("AUTHME_DB_PASSWORD", ""))
username = os.environ.get("AUTHME_DB_USER", "authme")
host = os.environ.get("AUTHME_DB_HOST", "127.0.0.1")
database = os.environ.get("AUTHME_DB_NAME", "authme")

content = re.sub(r"^    mySQLPassword:.*$", "    mySQLPassword: " + password, content, count=1, flags=re.M)
content = re.sub(r"^    mySQLUsername:.*$", "    mySQLUsername: " + username, content, count=1, flags=re.M)
content = re.sub(r"^    mySQLHost:.*$", "    mySQLHost: " + host, content, count=1, flags=re.M)
content = re.sub(r"^    mySQLDatabase:.*$", "    mySQLDatabase: " + database, content, count=1, flags=re.M)

directory = os.path.dirname(os.path.abspath(config_path))
with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, delete=False) as output:
    output.write(content)
    temp_path = output.name
os.chmod(temp_path, os.stat(config_path).st_mode)
os.replace(temp_path, config_path)
PY
}

inject_queqiao() {
  local config="$1"
  [ -f "${config}" ] || return 0
  if [ -z "${QUEQIAO_ACCESS_TOKEN:-}" ]; then
    echo "QUEQIAO_ACCESS_TOKEN is required while QueQiao is installed" >&2
    return 1
  fi

  python3 - "${config}" <<'PY'
import os
import re
import sys
import tempfile

config_path = sys.argv[1]
token = os.environ["QUEQIAO_ACCESS_TOKEN"]


def yaml_double_quoted(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


with open(config_path, encoding="utf-8") as config_file:
    lines = config_file.readlines()

for index, line in enumerate(lines):
    if line.startswith("access_token:"):
        newline = "\r\n" if line.endswith("\r\n") else "\n"
        rest = line[len("access_token:"):].rstrip("\r\n")
        comment_index = rest.find(" #")
        suffix = rest[comment_index:] if comment_index >= 0 else ""
        lines[index] = "access_token: " + yaml_double_quoted(token) + suffix + newline
        break

directory = os.path.dirname(os.path.abspath(config_path))
with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, delete=False) as output:
    output.writelines(lines)
    temp_path = output.name
os.chmod(temp_path, os.stat(config_path).st_mode)
os.replace(temp_path, config_path)
PY
}

for dir in "${LOBBY_DIR:-}" "${SURVIVAL_DIR:-}"; do
  [ -d "${dir}" ] || continue
  inject_luckperms "${dir}/plugins/LuckPerms/config.yml"
done

if [ -n "${VC_DIR:-}" ]; then
  # Velocity uses a lowercase LuckPerms directory, unlike the backends.
  inject_luckperms "${VC_DIR}/plugins/luckperms/config.yml"
  inject_queqiao "${VC_DIR}/plugins/QueQiao/config.yml"
fi

if [ -n "${LOBBY_DIR:-}" ]; then
  inject_authme "${LOBBY_DIR}/plugins/AuthMe/config.yml"
fi

if [ -n "${SURVIVAL_DIR:-}" ]; then
  inject_tab "${SURVIVAL_DIR}/plugins/TAB/config.yml"
fi
