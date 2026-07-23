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

(
  cd "${TEST_DIR}"
  LOBBY_DIR="${TEST_DIR}/server" \
  SURVIVAL_DIR="" \
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

echo "inject-db-secrets test: OK"
