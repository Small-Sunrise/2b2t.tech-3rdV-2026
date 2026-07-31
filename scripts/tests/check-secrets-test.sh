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

# Locale files are UI text, not credential stores: AuthMe 6.0.0 ships dialog
# labels that are literally `password: '&fPassword'`, which used to be reported
# as a leak and blocked the commit. The key rule is suppressed for the listed
# message directories -- and nowhere else, which the second half asserts.
mkdir -p "${TEST_DIR}/lobby/plugins/AuthMe/messages"
cat > "${TEST_DIR}/lobby/plugins/AuthMe/messages/messages_zh.yml" <<'YAML'
dialog:
    login:
        password: '&fPassword'
    register:
        confirm_password: '&fConfirm Password'
YAML
git -C "${TEST_DIR}" add lobby/plugins/AuthMe/messages/messages_zh.yml
if ! (cd "${TEST_DIR}" && bash "${ROOT_DIR}/scripts/check-secrets.sh" --staged >/dev/null 2>&1); then
  echo "expected locale message labels to be allowed" >&2
  exit 1
fi
git -C "${TEST_DIR}" reset -q

# The same content outside a message directory must still be reported.
mkdir -p "${TEST_DIR}/lobby/plugins/AuthMe"
cp "${TEST_DIR}/lobby/plugins/AuthMe/messages/messages_zh.yml" "${TEST_DIR}/lobby/plugins/AuthMe/config.yml"
git -C "${TEST_DIR}" add lobby/plugins/AuthMe/config.yml
if (cd "${TEST_DIR}" && bash "${ROOT_DIR}/scripts/check-secrets.sh" --staged >/dev/null 2>&1); then
  echo "expected the same labels OUTSIDE a message dir to still be flagged" >&2
  exit 1
fi
git -C "${TEST_DIR}" reset -q
rm -rf "${TEST_DIR}/lobby"

echo "check-secrets test: OK"
