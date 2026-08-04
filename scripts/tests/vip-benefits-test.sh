#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOOTSTRAP="${ROOT_DIR}/scripts/luckperms-vip-bootstrap.txt"
DESIGN="${ROOT_DIR}/docs/VIP-SVIP-DESIGN.md"

require_line() {
  local file="$1" line="$2"
  grep -Fqx -- "${line}" "${file}" || {
    echo "missing expected line in ${file}: ${line}" >&2
    exit 1
  }
}

require_line "${BOOTSTRAP}" "lp group svip parent add vip"
require_line "${BOOTSTRAP}" "lp group vip permission set essentials.back true"
require_line "${BOOTSTRAP}" "lp group vip permission set essentials.back.ondeath true"
require_line "${BOOTSTRAP}" "lp group vip permission set dupeplus.dupe true"
require_line "${BOOTSTRAP}" "lp group vip permission set residence.group.vip true"
require_line "${BOOTSTRAP}" "lp group svip permission set residence.group.svip true"

if grep -Eq '^lp group (vip|svip) permission set essentials\.(home|sethome)([. ]|$)' "${BOOTSTRAP}"; then
  echo "VIP bootstrap must not grant home/sethome" >&2
  exit 1
fi
if grep -Eq '^lp group (vip|svip) permission set residence\.admin' "${BOOTSTRAP}"; then
  echo "VIP bootstrap must not grant broad Residence admin permissions" >&2
  exit 1
fi

grep -A8 '^dupe:' "${ROOT_DIR}/2b2t/plugins/DupePlus/config.yml" | grep -Fq '  permission: true'
grep -A5 '^  svip:' "${ROOT_DIR}/2b2t/plugins/TChat/modules/tags.yml" | grep -Fq 'permission: tchat.tag.svip'
grep -A5 '^  svip:' "${ROOT_DIR}/lobby/plugins/TChat/modules/tags.yml" | grep -Fq 'permission: tchat.tag.svip'

grep -Fq '50,000,000' "${DESIGN}"
grep -Fq '200,000,000' "${DESIGN}"
grep -Fq '每日签到奖励为 1,000' "${DESIGN}"
grep -Fq '60 天 ECV 宽限期' "${DESIGN}"

echo "VIP/SVIP benefit contract test: OK"
