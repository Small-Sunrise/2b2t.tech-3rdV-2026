#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "${TEST_DIR}"' EXIT

mkdir -p "${TEST_DIR}/server/plugins/LuckPerms"
cat > "${TEST_DIR}/server/plugins/LuckPerms/config.yml" <<'YAML'
storage-method: MySQL
data:
  address: localhost:3306
  database: luckperms
  username: user
  password: 'placeholder'
  pool-settings:
    maximum-pool-size: 10

redis:
  enabled: false
  address: localhost
  username: ''
  password: ''
YAML

mkdir -p "${TEST_DIR}/proxy/plugins/luckperms"
cat > "${TEST_DIR}/proxy/plugins/luckperms/config.yml" <<'YAML'
storage-method: MySQL
data:
  address: localhost:3306
  database: luckperms
  username: user
  password: 'placeholder'
  pool-settings:
    maximum-pool-size: 10

redis:
  enabled: false
  address: localhost
  username: ''
  password: ''
YAML

(
  cd "${TEST_DIR}"
  LOBBY_DIR="${TEST_DIR}/server" \
  SURVIVAL_DIR="" \
  VC_DIR="${TEST_DIR}/proxy" \
  LUCKPERMS_DB_HOST="db.internal:3307" \
  LUCKPERMS_DB_NAME="luckperms_test" \
  LUCKPERMS_DB_USER="test-user" \
  LUCKPERMS_DB_PASSWORD="secret'with#chars" \
    bash "${ROOT_DIR}/scripts/inject-db-secrets.sh"
)

CONFIG="${TEST_DIR}/server/plugins/LuckPerms/config.yml"
grep -Fqx "  address: 'db.internal:3307'" "${CONFIG}"
grep -Fqx "  database: 'luckperms_test'" "${CONFIG}"
grep -Fqx "  username: 'test-user'" "${CONFIG}"
grep -Fqx "  password: 'secret''with#chars'" "${CONFIG}"

# Disabled messaging backends must not receive SQL credentials.
grep -Fqx "  address: localhost" "${CONFIG}"
grep -Fqx "  username: ''" "${CONFIG}"
grep -Fqx "  password: ''" "${CONFIG}"

PROXY_CONFIG="${TEST_DIR}/proxy/plugins/luckperms/config.yml"
grep -Fqx "  address: 'db.internal:3307'" "${PROXY_CONFIG}"
grep -Fqx "  database: 'luckperms_test'" "${PROXY_CONFIG}"
grep -Fqx "  username: 'test-user'" "${PROXY_CONFIG}"
grep -Fqx "  password: 'secret''with#chars'" "${PROXY_CONFIG}"

# Disabled messaging backends must not receive SQL credentials.
grep -Fqx "  address: localhost" "${PROXY_CONFIG}"
grep -Fqx "  username: ''" "${PROXY_CONFIG}"
grep -Fqx "  password: ''" "${PROXY_CONFIG}"

echo "inject-db-secrets test: OK"

# AuthMe: verify the mySQLPassword field (including special characters and
# single quotes) is injected correctly and the config remains valid.
mkdir -p "${TEST_DIR}/authme-server/plugins/AuthMe"
cat > "${TEST_DIR}/authme-server/plugins/AuthMe/config.yml" <<'YAML'
DataSource:
    mySQLHost: 127.0.0.1
    mySQLPort: '3306'
    mySQLUsername: authme
    mySQLPassword: ''
    mySQLDatabase: authme
YAML

(
  cd "${TEST_DIR}"
  LOBBY_DIR="${TEST_DIR}/authme-server" \
  SURVIVAL_DIR="" \
  VC_DIR="" \
  AUTHME_DB_HOST="db.internal" \
  AUTHME_DB_NAME="authme_test" \
  AUTHME_DB_USER="authme-user" \
  AUTHME_DB_PASSWORD="secret'with#chars" \
    bash "${ROOT_DIR}/scripts/inject-db-secrets.sh"
)

AUTHME_CONFIG="${TEST_DIR}/authme-server/plugins/AuthMe/config.yml"
grep -Fqx "    mySQLHost: db.internal" "${AUTHME_CONFIG}"
grep -Fqx "    mySQLUsername: authme-user" "${AUTHME_CONFIG}"
grep -Fqx "    mySQLPassword: 'secret''with#chars'" "${AUTHME_CONFIG}"
grep -Fqx "    mySQLDatabase: authme_test" "${AUTHME_CONFIG}"

# Re-running must be idempotent.
BEFORE_MD5="$(md5sum "${AUTHME_CONFIG}" | awk '{print $1}')"
(
  cd "${TEST_DIR}"
  LOBBY_DIR="${TEST_DIR}/authme-server" \
  SURVIVAL_DIR="" \
  VC_DIR="" \
  AUTHME_DB_HOST="db.internal" \
  AUTHME_DB_NAME="authme_test" \
  AUTHME_DB_USER="authme-user" \
  AUTHME_DB_PASSWORD="secret'with#chars" \
    bash "${ROOT_DIR}/scripts/inject-db-secrets.sh"
)
AFTER_MD5="$(md5sum "${AUTHME_CONFIG}" | awk '{print $1}')"
[ "${BEFORE_MD5}" = "${AFTER_MD5}" ] || { echo "authme injection not idempotent" >&2; exit 1; }

echo "inject-db-secrets authme test: OK"

# QueQiao: proxy-only access token injection is scoped, atomic and idempotent.
mkdir -p "${TEST_DIR}/queqiao-proxy/plugins/QueQiao"
cat > "${TEST_DIR}/queqiao-proxy/plugins/QueQiao/config.yml" <<'YAML'
server_name: "fixture"
access_token: "" # injected at runtime
websocket_server:
  enable: true
YAML
QUEQIAO_CONFIG="${TEST_DIR}/queqiao-proxy/plugins/QueQiao/config.yml"
BEFORE_EMPTY_MD5="$(md5sum "${QUEQIAO_CONFIG}" | awk '{print $1}')"
if VC_DIR="${TEST_DIR}/queqiao-proxy" bash "${ROOT_DIR}/scripts/inject-db-secrets.sh" >/dev/null 2>&1; then
  echo "unset QueQiao token did not fail" >&2
  exit 1
fi
AFTER_EMPTY_MD5="$(md5sum "${QUEQIAO_CONFIG}" | awk '{print $1}')"
[ "${BEFORE_EMPTY_MD5}" = "${AFTER_EMPTY_MD5}" ] || { echo "unset QueQiao token changed config" >&2; exit 1; }

VC_DIR="${TEST_DIR}/queqiao-proxy" \
QUEQIAO_ACCESS_TOKEN='fixture"token\with#chars' \
  bash "${ROOT_DIR}/scripts/inject-db-secrets.sh"
grep -Fqx 'access_token: "fixture\"token\\with#chars" # injected at runtime' "${QUEQIAO_CONFIG}"
BEFORE_MD5="$(md5sum "${QUEQIAO_CONFIG}" | awk '{print $1}')"
VC_DIR="${TEST_DIR}/queqiao-proxy" \
QUEQIAO_ACCESS_TOKEN='fixture"token\with#chars' \
  bash "${ROOT_DIR}/scripts/inject-db-secrets.sh"
AFTER_MD5="$(md5sum "${QUEQIAO_CONFIG}" | awk '{print $1}')"
[ "${BEFORE_MD5}" = "${AFTER_MD5}" ] || { echo "QueQiao injection not idempotent" >&2; exit 1; }

python3 - "${QUEQIAO_CONFIG}" <<'PY'
import sys
import yaml
with open(sys.argv[1], encoding="utf-8") as source:
    assert yaml.safe_load(source)["access_token"] == 'fixture"token\\with#chars'
PY

echo "inject-db-secrets QueQiao test: OK"


# TAB: SQL values are YAML-quoted, scoped to the first mysql keys and idempotent.
mkdir -p "${TEST_DIR}/tab-server/plugins/TAB"
cat > "${TEST_DIR}/tab-server/plugins/TAB/config.yml" <<'YAML'
mysql:
  enabled: true
  database: tab
  username: user
  password: password
other:
  database: untouched
  username: untouched
  password: untouched
YAML
TAB_CONFIG="${TEST_DIR}/tab-server/plugins/TAB/config.yml"
SURVIVAL_DIR="${TEST_DIR}/tab-server" \
TAB_DB_NAME="tab:test" \
TAB_DB_USER="user#name" \
TAB_DB_PASSWORD="secret'with#chars" \
  bash "${ROOT_DIR}/scripts/inject-db-secrets.sh"
grep -Fqx "  database: 'tab:test'" "${TAB_CONFIG}"
grep -Fqx "  username: 'user#name'" "${TAB_CONFIG}"
grep -Fqx "  password: 'secret''with#chars'" "${TAB_CONFIG}"
grep -Fqx "  password: untouched" "${TAB_CONFIG}"
BEFORE_MD5="$(md5sum "${TAB_CONFIG}" | awk '{print $1}')"
SURVIVAL_DIR="${TEST_DIR}/tab-server" \
TAB_DB_NAME="tab:test" \
TAB_DB_USER="user#name" \
TAB_DB_PASSWORD="secret'with#chars" \
  bash "${ROOT_DIR}/scripts/inject-db-secrets.sh"
AFTER_MD5="$(md5sum "${TAB_CONFIG}" | awk '{print $1}')"
[ "${BEFORE_MD5}" = "${AFTER_MD5}" ] || { echo "TAB injection not idempotent" >&2; exit 1; }
python3 - "${TAB_CONFIG}" <<'PY'
import sys
import yaml
with open(sys.argv[1], encoding="utf-8") as source:
    config = yaml.safe_load(source)
assert config["mysql"]["password"] == "secret'with#chars"
assert config["other"]["password"] == "untouched"
PY

echo "inject-db-secrets TAB test: OK"
