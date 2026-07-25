#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
if [ -n "${mode}" ] && [ "${mode}" != "--staged" ]; then
  echo "Usage: $0 [--staged]" >&2
  exit 2
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "${ROOT_DIR}"
python3 - "${mode}" <<'PY'
import os
import re
import subprocess
import sys

staged = sys.argv[1] == "--staged"

# These paths contain public Minecraft skin texture data or generated file
# fingerprints, not authentication material. Keep this list path-specific so
# the general credential rules remain strict everywhere else.
BENIGN_PATH_RULES = {
    "VC/plugins/Geyser-Velocity/custom-skulls.yml": "skin texture hash example",
    "VC/plugins/skinsrestorer/config.yml": "skin texture hash",
    "2b2t/plugins/CMILib/config.yml": "base64-encoded skin texture",
    "lobby/plugins/CMILib/config.yml": "base64-encoded skin texture",
    "lobby/plugins/EnderChestVault/config.yml": "base64-encoded skin texture",
    "2b2t/plugins/Essentials/items.json": "EssentialsX file fingerprint",
    "lobby/plugins/Essentials/items.json": "EssentialsX file fingerprint",
}

PLACEHOLDERS = {
    "", "-", "key", "pass", "password", "minecraft", "guest",
    "your-db-password", "your-minepay-token-here", "enter-here-your-key",
    "change-me-in-production", "replace_me", "changeme", "none", "null", "passwd",
}
KEY_RE = re.compile(
    r"^\s*(?P<key>secret|access[_-]?token|mysqlpassword|password|token|api[_-]?key|management-server-secret)"
    r"\s*[:=]\s*(?P<value>.*?)\s*$",
    re.IGNORECASE,
)
HEX_VALUE_RE = re.compile(r"[:=]\s*['\"]?(?P<value>[0-9a-fA-F]{32,})['\"]?\s*(?:#.*)?$")


def git_output(*args):
    return subprocess.check_output(["git", *args])


if staged:
    paths = [p.decode() for p in git_output("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z").split(b"\0") if p]
else:
    paths = [p.decode() for p in git_output("ls-files", "-z").split(b"\0") if p]


def content_for(path):
    if staged:
        try:
            return git_output("show", f":{path}").decode("utf-8", "replace")
        except subprocess.CalledProcessError:
            return ""
    try:
        with open(path, encoding="utf-8", errors="replace") as source:
            return source.read()
    except (FileNotFoundError, IsADirectoryError):
        return ""


def unquote(value):
    value = value.strip()
    # Strip a trailing YAML comment after a quoted or bare scalar.
    if " #" in value:
        value = value.split(" #", 1)[0].rstrip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        value = value[1:-1]
    return value.strip()


findings = []
for path in paths:
    allow_benign_hex = path in BENIGN_PATH_RULES
    for line_number, line in enumerate(content_for(path).splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        config_like = os.path.splitext(path)[1].lower() in {".yml", ".yaml", ".conf", ".toml", ".properties", ".json", ".ini", ".env"}
        key_match = KEY_RE.match(line) if config_like else None
        if key_match:
            value = unquote(key_match.group("value"))
            if value.lower() not in PLACEHOLDERS and not value.startswith("${"):
                findings.append((path, line_number, f"non-placeholder value for {key_match.group('key')}"))
                continue
        if HEX_VALUE_RE.search(line) and not allow_benign_hex:
            findings.append((path, line_number, "long hexadecimal value in a config value"))

if findings:
    print("Potential secrets found in tracked content:", file=sys.stderr)
    for path, line_number, rule in findings:
        print(f"  {path}:{line_number}: {rule}", file=sys.stderr)
    sys.exit(1)

scope = "staged tracked content" if staged else "tracked working-tree files"
print(f"Secret scan OK: {scope}")
PY
