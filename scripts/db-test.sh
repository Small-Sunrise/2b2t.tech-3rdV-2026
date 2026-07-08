#!/usr/bin/env bash
# Database connectivity test for 2b2t.tech Minecraft network
# Usage: bash scripts/db-test.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load .env if present
if [ -f "${ROOT_DIR}/.env" ]; then
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

echo "=== 2b2t.tech Database Connectivity Test ==="
echo ""

# ---- Test 1: Env vars present ----
echo "[1/4] Checking environment variables..."

check_var() {
  local var_name="$1"
  if [ -z "${!var_name:-}" ]; then
    echo "  WARN: ${var_name} is not set in .env"
    return 1
  else
    echo "  OK:   ${var_name} is set"
    return 0
  fi
}

FAIL=0
check_var "LUCKPERMS_DB_HOST" || FAIL=1
check_var "LUCKPERMS_DB_NAME" || FAIL=1
check_var "LUCKPERMS_DB_USER" || FAIL=1
check_var "LUCKPERMS_DB_PASSWORD" || FAIL=1

# ---- Test 2: MariaDB port reachable ----
echo ""
echo "[2/4] Testing TCP connectivity to ${LUCKPERMS_DB_HOST:-unknown}..."

DB_HOST=$(echo "${LUCKPERMS_DB_HOST}" | cut -d: -f1)
DB_PORT=$(echo "${LUCKPERMS_DB_HOST}" | cut -d: -f2)

if command -v nc &>/dev/null; then
  if nc -z -w5 "${DB_HOST}" "${DB_PORT}" 2>/dev/null; then
    echo "  OK:   ${DB_HOST}:${DB_PORT} is reachable"
  else
    echo "  FAIL: ${DB_HOST}:${DB_PORT} is NOT reachable"
    FAIL=1
  fi
elif command -v timeout &>/dev/null; then
  if timeout 5 bash -c "echo >/dev/tcp/${DB_HOST}/${DB_PORT}" 2>/dev/null; then
    echo "  OK:   ${DB_HOST}:${DB_PORT} is reachable"
  else
    echo "  FAIL: ${DB_HOST}:${DB_PORT} is NOT reachable"
    FAIL=1
  fi
else
  echo "  SKIP: nc/timeout not available; cannot test TCP connectivity"
fi

# ---- Test 3: MySQL login ----
echo ""
echo "[3/4] Testing MySQL authentication..."

if command -v mysql &>/dev/null; then
  if mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${LUCKPERMS_DB_USER}" -p"${LUCKPERMS_DB_PASSWORD}" -e "SELECT 1;" 2>/dev/null; then
    echo "  OK:   MySQL login successful"
  else
    echo "  FAIL: MySQL login failed (check credentials in .env)"
    FAIL=1
  fi
else
  echo "  SKIP: mysql client not installed; install it: brew install mysql-client"
fi

# ---- Test 4: Database exists ----
echo ""
echo "[4/4] Checking database '${LUCKPERMS_DB_NAME:-luckperms_2b2t}'..."

if command -v mysql &>/dev/null; then
  if mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${LUCKPERMS_DB_USER}" -p"${LUCKPERMS_DB_PASSWORD}" -e "USE ${LUCKPERMS_DB_NAME}; SELECT 1;" 2>/dev/null; then
    echo "  OK:   Database '${LUCKPERMS_DB_NAME}' exists and is accessible"
  else
    echo "  FAIL: Database '${LUCKPERMS_DB_NAME}' not found or not accessible"
    FAIL=1
  fi
fi

echo ""
if [ "${FAIL}" -eq 0 ]; then
  echo "=== All tests passed ==="
  exit 0
else
  echo "=== Some tests failed (see above) ==="
  exit 1
fi
