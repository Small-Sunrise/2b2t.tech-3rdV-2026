#!/usr/bin/env bash
# Install logrotate config for 2b2t.tech
# Usage: sudo bash scripts/install-logrotate.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/scripts/logrotate.conf"
DEST="/etc/logrotate.d/2b2t"

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (sudo)."
  echo "  sudo bash scripts/install-logrotate.sh"
  exit 1
fi

# Replace placeholder paths with actual path
sed "s|/path/to/2b2t.tech-3rdV-2026|${ROOT_DIR}|g" "${SRC}" > "${DEST}"
chmod 644 "${DEST}"

echo "Logrotate config installed to ${DEST}"
echo "Test with: logrotate -d ${DEST}"
