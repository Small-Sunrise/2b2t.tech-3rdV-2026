#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "${TEST_DIR}"' EXIT

git -C "${TEST_DIR}" init -q
git -C "${TEST_DIR}" config user.email test@example.invalid
git -C "${TEST_DIR}" config user.name Test

write_and_stage() {
  printf '%s\n' "$2" > "${TEST_DIR}/$1"
  git -C "${TEST_DIR}" add "$1"
}

expect_fail() {
  if (cd "${TEST_DIR}" && bash "${ROOT_DIR}/scripts/check-secrets.sh" --staged >/dev/null 2>&1); then
    echo "expected secret scan failure: $1" >&2
    exit 1
  fi
  git -C "${TEST_DIR}" reset -q
  rm -f "${TEST_DIR}/fixture.yml"
}

long_hex="$(printf 'ab%.0s' {1..20})"
write_and_stage fixture.yml "access_token: ${long_hex}"
expect_fail "long hex token"
write_and_stage fixture.yml "mySQLPassword: definitely-not-a-placeholder"
expect_fail "non-placeholder password"
write_and_stage fixture.yml "management-server-secret=generated-secret-value"
expect_fail "management server secret"

cat > "${TEST_DIR}/fixture.yml" <<'YAML'
access_token: ""
password: your-db-password
token: change-me-in-production
secret: ${RUNTIME_SECRET}
YAML
git -C "${TEST_DIR}" add fixture.yml
(cd "${TEST_DIR}" && bash "${ROOT_DIR}/scripts/check-secrets.sh" --staged >/dev/null)
git -C "${TEST_DIR}" commit -qm fixtures

# --staged must ignore an unstaged secret and catch it after staging.
printf '%s\n' 'password: unstaged-real-value' > "${TEST_DIR}/fixture.yml"
(cd "${TEST_DIR}" && bash "${ROOT_DIR}/scripts/check-secrets.sh" --staged >/dev/null)
git -C "${TEST_DIR}" add fixture.yml
expect_fail "staged-only behavior"

echo "check-secrets test: OK"
