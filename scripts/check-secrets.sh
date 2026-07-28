#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
if [ -n "${mode}" ] && [ "${mode}" != "--staged" ]; then
  echo "Usage: $0 [--staged]" >&2
  exit 2
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "${ROOT_DIR}"

# This scanner is pure POSIX awk + bash (no gawk-only features), so it
# behaves identically under Git Bash's gawk and Debian-slim's mawk. See
# scripts/tests/check-secrets-test.sh for the behavioral contract.

staged=0
if [ "${mode}" = "--staged" ]; then
  staged=1
fi

# Shared detection engine. Two invocation shapes are supported so that we
# never spawn more than one awk process per staged file (--staged, which
# always deals with a small changeset from the pre-commit hook) and
# exactly *one* awk process total for a full worktree scan (which is the
# case with hundreds of tracked config files -- spawning an interpreter
# per file there is what actually made this "slow"; the detection logic
# itself is a single linear pass and was never quadratic):
#  - worktree scan: every tracked regular file is passed as an awk file
#    argument (prefixed with "./" so a filename that happens to contain
#    "=" is never mistaken for an awk command-line var=value assignment);
#    awk reads each one itself via its normal ARGV file handling.
#  - staged scan: content must come from the git index (`git show`), so
#    this is invoked once per path with the blob content on stdin and the
#    path passed via the SCAN_PATH environment variable.
AWK_PROGRAM='
function file_ext(p,    base, i) {
    base = p
    for (i = length(p); i >= 1; i--) {
        if (substr(p, i, 1) == "/") { base = substr(p, i + 1); break }
    }
    for (i = length(base); i >= 1; i--) {
        if (substr(base, i, 1) == ".") return tolower(substr(base, i))
    }
    return ""
}
function is_config_like(p,    ext) {
    ext = file_ext(p)
    return (ext == ".yml" || ext == ".yaml" || ext == ".conf" || ext == ".toml" || \
            ext == ".properties" || ext == ".json" || ext == ".ini" || ext == ".env")
}
function is_benign_hex_path(p) {
    return (p in BENIGN_PATH)
}
function unquote(value,   idx, n, first, last) {
    gsub(/^[ \t]+/, "", value)
    gsub(/[ \t]+$/, "", value)
    idx = index(value, " #")
    if (idx > 0) {
        value = substr(value, 1, idx - 1)
        gsub(/[ \t]+$/, "", value)
    }
    n = length(value)
    if (n >= 2) {
        first = substr(value, 1, 1)
        last = substr(value, n, 1)
        if (first == last && (first == SQ || first == "\"")) {
            value = substr(value, 2, n - 2)
        }
    }
    gsub(/^[ \t]+/, "", value)
    gsub(/[ \t]+$/, "", value)
    return value
}
function try_key_match(t,   lower, klen, rest, seplen) {
    lower = tolower(t)
    if (!match(lower, /^(secret|access[_-]?token|mysqlpassword|password|token|api[_-]?key|management-server-secret)/)) {
        return 0
    }
    klen = RLENGTH
    rest = substr(lower, klen + 1)
    if (!match(rest, /^[ \t]*[:=][ \t]*/)) {
        return 0
    }
    seplen = RLENGTH
    MATCHED_KEY = substr(t, 1, klen)
    MATCHED_VALUE = substr(t, klen + seplen + 1)
    gsub(/[ \t]+$/, "", MATCHED_VALUE)
    return 1
}
function scan_line(rpath, config_like, allow_benign_hex, line_number,   line, trimmed, value, lower_value) {
    line = $0
    sub(/\r$/, "", line)

    trimmed = line
    gsub(/^[ \t]+/, "", trimmed)
    if (trimmed == "" || substr(trimmed, 1, 1) == "#") {
        return
    }

    if (config_like && try_key_match(trimmed)) {
        value = unquote(MATCHED_VALUE)
        lower_value = tolower(value)
        if (!(lower_value in PLACEHOLDER) && substr(value, 1, 2) != "${") {
            printf "  %s:%d: non-placeholder value for %s\n", rpath, line_number, MATCHED_KEY
            return
        }
    }

    if (line ~ hexpattern && !allow_benign_hex) {
        printf "  %s:%d: long hexadecimal value in a config value\n", rpath, line_number
    }
}
BEGIN {
    RS = "\n"
    SQ = sprintf("%c", 39)

    n = split("|-|key|pass|password|minecraft|guest|your-db-password|your-minepay-token-here|enter-here-your-key|change-me-in-production|replace_me|changeme|none|null|passwd", parts, "|")
    for (i = 1; i <= n; i++) PLACEHOLDER[parts[i]] = 1

    hexclass = "[0-9a-fA-F]"
    hexrun = ""
    for (i = 0; i < 31; i++) hexrun = hexrun hexclass
    hexrun = hexrun hexclass "+"
    hexpattern = "[:=][ \t]*[" SQ "\"]?(" hexrun ")[" SQ "\"]?[ \t]*(#.*)?$"

    BENIGN_PATH["VC/plugins/Geyser-Velocity/custom-skulls.yml"] = 1
    BENIGN_PATH["VC/plugins/skinsrestorer/config.yml"] = 1
    BENIGN_PATH["2b2t/plugins/CMILib/config.yml"] = 1
    BENIGN_PATH["lobby/plugins/CMILib/config.yml"] = 1
    BENIGN_PATH["lobby/plugins/EnderChestVault/config.yml"] = 1
    BENIGN_PATH["2b2t/plugins/Essentials/items.json"] = 1
    BENIGN_PATH["lobby/plugins/Essentials/items.json"] = 1

    SCAN_PATH = ENVIRON["SCAN_PATH"]
    if (SCAN_PATH != "") {
        IS_STAGED = 1
        staged_config_like = is_config_like(SCAN_PATH)
        staged_allow_benign_hex = is_benign_hex_path(SCAN_PATH)
    } else {
        IS_STAGED = 0
    }
}
IS_STAGED {
    scan_line(SCAN_PATH, staged_config_like, staged_allow_benign_hex, NR)
    next
}
FNR == 1 {
    report_path = FILENAME
    sub(/^\.\//, "", report_path)
    file_config_like = is_config_like(report_path)
    file_allow_benign_hex = is_benign_hex_path(report_path)
}
{
    scan_line(report_path, file_config_like, file_allow_benign_hex, FNR)
}
'

findings_file="$(mktemp)"
trap 'rm -f -- "${findings_file}"' EXIT

if [ "${staged}" -eq 1 ]; then
  while IFS= read -r -d '' path; do
    # A failed `git show` must not abort the whole scan: with `set -e` plus
    # `pipefail` an unreadable index entry (e.g. a non-blob) would kill this
    # script with a bare exit 1 and no message, which from the pre-commit
    # hook's point of view is indistinguishable from "secrets found". The
    # python implementation this replaces caught CalledProcessError and
    # treated the content as empty; do the same.
    # Note: deliberately a subshell group piped into awk rather than
    # `blob="$(git show ...)"`. Command substitution silently drops NUL bytes
    # and trailing newlines, which would corrupt binary blobs (the repo tracks
    # VC/server-icon.png) before they ever reach the scanner.
    { git show ":${path}" 2>/dev/null || true; } \
      | LC_ALL=C SCAN_PATH="${path}" awk -v BINMODE=3 "${AWK_PROGRAM}" \
      >> "${findings_file}"
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
else
  paths=()
  while IFS= read -r -d '' path; do
    # Skip anything that isn't (or no longer is) a regular file, matching
    # the original python's silent FileNotFoundError/IsADirectoryError
    # handling.
    [ -f "${path}" ] && paths+=("./${path}")
  done < <(git ls-files -z)

  if [ "${#paths[@]}" -gt 0 ]; then
    LC_ALL=C awk -v BINMODE=3 "${AWK_PROGRAM}" "${paths[@]}" >> "${findings_file}"
  fi
fi

if [ -s "${findings_file}" ]; then
  echo "Potential secrets found in tracked content:" >&2
  cat -- "${findings_file}" >&2
  exit 1
fi

if [ "${staged}" -eq 1 ]; then
  echo "Secret scan OK: staged tracked content"
else
  echo "Secret scan OK: tracked working-tree files"
fi
