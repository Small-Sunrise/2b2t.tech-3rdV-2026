#!/usr/bin/env bash
# Fetches the required server jars (Velocity / Paper / Leaf) for a fresh
# clone, per scripts/jars.manifest.
#
# - Reads scripts/jars.manifest (path|URL-or-MANUAL|location|sha256).
# - Skips jars that already exist on disk with a matching sha256 (idempotent).
# - Downloads to a temp file in the target directory, verifies sha256, then
#   atomically renames into place. A failed/mismatched download never leaves
#   a partial jar at the target path.
# - MANUAL entries (no reliable official direct link) are never downloaded;
#   the script prints a clear instruction instead.
# - Plugin jars are out of scope with ONE exception: the ViaVersion suite
#   (ViaVersion / ViaBackwards / ViaRewind). lobby runs protocol 775 and 2b2t
#   runs protocol 776, so without Via no single client protocol can reach both
#   backends and cross-server travel is impossible. It is a prerequisite for
#   the network to work at all, not an optional gameplay plugin. Everything
#   else: see PLUGINS.md.
#
# Usage:
#   bash scripts/fetch-jars.sh [path-to-manifest]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${1:-${ROOT_DIR}/scripts/jars.manifest}"

if [ ! -f "${MANIFEST}" ]; then
  echo "错误: 清单文件不存在: ${MANIFEST}" >&2
  exit 1
fi

sha256_of() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  else
    shasum -a 256 "${file}" | awk '{print $1}'
  fi
}

FETCHED=0
SKIPPED=0
MANUAL_COUNT=0
FAILED=0

echo "=== 拉取服务端 jar (scripts/fetch-jars.sh) ==="
echo "清单: ${MANIFEST}"
echo ""

while IFS='|' read -r rel_path kind location checksum; do
  target="${ROOT_DIR}/${rel_path}"

  if [ "${kind}" = "MANUAL" ]; then
    echo "⚠ 需手工准备: ${rel_path}"
    echo "  说明: ${location}"
    if [ -f "${target}" ]; then
      echo "  当前状态: 文件已存在于 ${target}（无官方 checksum 可比对，脚本不做校验）"
    else
      echo "  当前状态: 缺失"
    fi
    echo ""
    MANUAL_COUNT=$((MANUAL_COUNT + 1))
    continue
  fi

  if [ "${kind}" != "URL" ]; then
    echo "错误: ${rel_path} 的清单类型未知: '${kind}'（应为 URL 或 MANUAL）" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if [ -z "${checksum}" ] || [ "${checksum}" = "N/A" ]; then
    echo "错误: ${rel_path} 缺少 sha256 校验和，拒绝下载不可信内容" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  mkdir -p "$(dirname "${target}")"

  if [ -f "${target}" ]; then
    existing_sum="$(sha256_of "${target}")"
    if [ "${existing_sum}" = "${checksum}" ]; then
      echo "✓ 已存在且校验和匹配，跳过: ${rel_path}"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    echo "⚠ ${rel_path} 已存在但校验和不匹配（本地 ${existing_sum}），将重新下载"
  fi

  tmp_file="${target}.${$}.tmp"
  # 中断（Ctrl-C / TERM）时也要清掉临时文件，避免在仓库里留下大体积残留物。
  trap 'rm -f "${tmp_file}"; exit 130' INT TERM
  echo "→ 下载: ${rel_path}"
  echo "  来源: ${location}"
  if ! curl -fsSL --retry 3 --connect-timeout 10 -o "${tmp_file}" "${location}"; then
    echo "错误: 下载失败: ${location}" >&2
    rm -f "${tmp_file}"
    FAILED=$((FAILED + 1))
    trap - INT TERM
    continue
  fi

  downloaded_sum="$(sha256_of "${tmp_file}")"
  if [ "${downloaded_sum}" != "${checksum}" ]; then
    echo "错误: ${rel_path} 校验和不匹配，已删除临时文件" >&2
    echo "  期望: ${checksum}" >&2
    echo "  实际: ${downloaded_sum}" >&2
    rm -f "${tmp_file}"
    FAILED=$((FAILED + 1))
    trap - INT TERM
    continue
  fi

  mv -f "${tmp_file}" "${target}"
  trap - INT TERM
  echo "✓ 下载完成并通过 sha256 校验: ${rel_path}"
  FETCHED=$((FETCHED + 1))
  echo ""
done < <(grep -Ev '^[[:space:]]*(#|$)' "${MANIFEST}")

echo "=== 汇总 ==="
echo "下载: ${FETCHED}  已跳过(既有且校验通过): ${SKIPPED}  需手工处理: ${MANUAL_COUNT}  失败: ${FAILED}"
echo ""
echo "提醒: 除 ViaVersion 套件（协议桥接，缺了就没法跨服）外，其余插件 jar 不在本"
echo "脚本范围内（数量多、来源杂），请参考 PLUGINS.md 手工放置到各 */plugins/ 目录"
echo "后再运行 scripts/startup-check.sh。"

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "存在下载失败/清单错误，退出码 1。" >&2
  exit 1
fi

exit 0
