#!/usr/bin/env bash
set -euo pipefail

for name in LUCKPERMS_DB_NAME LUCKPERMS_DB_USER LUCKPERMS_DB_PASSWORD AUTHME_DB_NAME AUTHME_DB_USER AUTHME_DB_PASSWORD; do
  [ -n "${!name:-}" ] || { echo "${name} is required" >&2; exit 1; }
done
for identifier in "${LUCKPERMS_DB_NAME}" "${LUCKPERMS_DB_USER}" "${AUTHME_DB_NAME}" "${AUTHME_DB_USER}"; do
  [[ "${identifier}" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid MariaDB identifier" >&2; exit 1; }
done

sql_quote() {
  printf '%s' "${1//\'/\'\'}"
}

luckperms_password="$(sql_quote "${LUCKPERMS_DB_PASSWORD}")"
authme_password="$(sql_quote "${AUTHME_DB_PASSWORD}")"

mariadb --protocol=socket -uroot -p"${MARIADB_ROOT_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${LUCKPERMS_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${LUCKPERMS_DB_USER}'@'%' IDENTIFIED BY '${luckperms_password}';
ALTER USER '${LUCKPERMS_DB_USER}'@'%' IDENTIFIED BY '${luckperms_password}';
GRANT ALL PRIVILEGES ON \`${LUCKPERMS_DB_NAME}\`.* TO '${LUCKPERMS_DB_USER}'@'%';
CREATE DATABASE IF NOT EXISTS \`${AUTHME_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${AUTHME_DB_USER}'@'%' IDENTIFIED BY '${authme_password}';
ALTER USER '${AUTHME_DB_USER}'@'%' IDENTIFIED BY '${authme_password}';
GRANT ALL PRIVILEGES ON \`${AUTHME_DB_NAME}\`.* TO '${AUTHME_DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
