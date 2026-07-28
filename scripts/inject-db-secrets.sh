#!/usr/bin/env bash
# Inject runtime credentials from environment variables into plugin configs.
# Call from server startup scripts after sourcing .env.
set -euo pipefail

# --- Shared atomic-rewrite machinery -----------------------------------
#
# All four injectors below rewrite a config file in place using the same
# contract as the previous python3 implementation:
#   - a temp file is created in the *same directory* as the target so the
#     final rename is atomic (same filesystem);
#   - the original file's permission bits are copied onto the temp file
#     before the rename;
#   - the temp file is cleaned up on any failure, INT or TERM;
#   - every line that is not rewritten passes through byte-for-byte,
#     including its own line terminator (LF or CRLF, per line);
#   - if the original file had no trailing newline, the rewritten file
#     doesn't gain one either.
#
# This is implemented with POSIX awk (no gawk-only features: no gensub(),
# no strtonum(), no length(array), no regex RS, no interval-less reliance
# on --re-interval) so it behaves identically under Git Bash's gawk and
# Debian-slim's mawk.

CURRENT_TMP_FILE=""

# On a signal we must NOT exit with "$?" (the status of the last completed
# command, which during a healthy run is 0). Callers treat this script's exit
# status as authoritative -- lobby/run.sh and 2b2t/run.sh both do
# "bash inject-db-secrets.sh || exit 1" -- so reporting success after being
# interrupted would let a server start with only some of its configs injected.
# Exit 128+signal instead, which is what the shell itself would have reported
# with no handler installed (verified: 143 for TERM), and matches the exit 130
# convention already used by scripts/fetch-jars.sh.
_inject_cleanup_on_signal() {
  local signal="$1"
  if [ -n "${CURRENT_TMP_FILE}" ]; then
    rm -f -- "${CURRENT_TMP_FILE}"
  fi
  trap - INT TERM
  case "${signal}" in
    INT) exit 130 ;;
    TERM) exit 143 ;;
    *) exit 1 ;;
  esac
}
trap '_inject_cleanup_on_signal INT' INT
trap '_inject_cleanup_on_signal TERM' TERM
trap 'rm -f -- "${CURRENT_TMP_FILE:-}"' EXIT

# Prints "1" if the file is non-empty and ends with a newline byte, "1" if
# the file is empty (nothing to preserve), otherwise "0".
file_ends_with_newline() {
  local path="$1"
  if [ ! -s "${path}" ]; then
    printf '1'
    return 0
  fi
  if [ -z "$(tail -c1 -- "${path}")" ]; then
    printf '1'
  else
    printf '0'
  fi
}

# Reads a file's permission bits portably. GNU stat (Git Bash's coreutils
# and Debian's coreutils both provide it) is tried first; a BSD/macOS
# fallback is included for defense in depth even though it isn't one of
# our two required targets.
file_mode() {
  local path="$1"
  stat -c '%a' -- "${path}" 2>/dev/null || stat -f '%OLp' -- "${path}"
}

# rewrite_config <config> <awk-program> [NAME=value ...]
#
# Runs awk over <config>, writing to a fresh temp file in the same
# directory, then chmods it to match the original mode and renames it into
# place. NAME=value pairs are exported into the awk process's environment
# (readable via ENVIRON) rather than passed as -v assignments, since -v
# values undergo awk's own backslash-escape parsing and would corrupt
# secrets containing literal backslashes.
rewrite_config() {
  local config="$1" awk_program="$2"
  shift 2

  local add_final_nl mode dir tmp
  add_final_nl="$(file_ends_with_newline "${config}")"
  mode="$(file_mode "${config}")"

  dir="${config%/*}"
  if [ "${dir}" = "${config}" ]; then
    dir="."
  fi

  tmp="$(mktemp "${dir}/inject-db-secrets.tmp.XXXXXX")"
  CURRENT_TMP_FILE="${tmp}"

  # BINMODE=3 disables gawk-for-Windows' automatic CRLF<->LF text-mode
  # translation (Git Bash's gawk otherwise silently eats the \r before our
  # regexes ever see it, exactly like Python's universal-newlines mode
  # would). It is a no-op on mawk/Linux: mawk doesn't recognize BINMODE at
  # all, so setting it there is just an unused variable assignment.
  if ! env "$@" LC_ALL=C awk -v BINMODE=3 -v add_final_nl="${add_final_nl}" "${awk_program}" "${config}" > "${tmp}"; then
    rm -f -- "${tmp}"
    CURRENT_TMP_FILE=""
    return 1
  fi

  chmod "${mode}" "${tmp}"
  mv -f -- "${tmp}" "${config}"
  CURRENT_TMP_FILE=""
}

inject_luckperms() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${LUCKPERMS_DB_PASSWORD:-}" ] || return 0

  local awk_program
  awk_program="$(cat <<'AWK'
function yaml_sq(v,   out) {
    out = v
    gsub(/'/, "&&", out)
    return "'" out "'"
}
function emit(text, cr) {
    printf "%s", text
    if (cr) printf "\r"
    printf "\n"
}
BEGIN {
    RS = "\n"
    have_prev = 0
    in_data = 0
    done_address = 0
    done_database = 0
    done_username = 0
    done_password = 0
}
{
    if (have_prev) emit(prev, prev_cr)
    line = $0
    cr = sub(/\r$/, "", line)

    if (line == "data:") {
        in_data = 1
    } else {
        if (in_data) {
            stripped = line
            gsub(/^[ \t]+/, "", stripped)
            gsub(/[ \t]+$/, "", stripped)
            first_char = substr(line, 1, 1)
            if (stripped != "" && first_char != " " && first_char != "\t" && first_char != "#") {
                in_data = 0
            }
        }
        if (in_data) {
            if (!done_address && index(line, "  address:") == 1) {
                line = "  address: " yaml_sq(ENVIRON["INJ_ADDRESS"])
                done_address = 1
            } else if (!done_database && index(line, "  database:") == 1) {
                line = "  database: " yaml_sq(ENVIRON["INJ_DATABASE"])
                done_database = 1
            } else if (!done_username && index(line, "  username:") == 1) {
                line = "  username: " yaml_sq(ENVIRON["INJ_USERNAME"])
                done_username = 1
            } else if (!done_password && index(line, "  password:") == 1) {
                line = "  password: " yaml_sq(ENVIRON["INJ_PASSWORD"])
                done_password = 1
            }
        }
    }

    prev = line
    prev_cr = cr
    have_prev = 1
}
END {
    if (have_prev) {
        printf "%s", prev
        if (prev_cr) printf "\r"
        if (add_final_nl == "1") printf "\n"
    }
}
AWK
)"

  rewrite_config "${config}" "${awk_program}" \
    INJ_ADDRESS="${LUCKPERMS_DB_HOST:-127.0.0.1:3306}" \
    INJ_DATABASE="${LUCKPERMS_DB_NAME:-luckperms_2b2t}" \
    INJ_USERNAME="${LUCKPERMS_DB_USER:-lpsql}" \
    INJ_PASSWORD="${LUCKPERMS_DB_PASSWORD:-}"
}

inject_tab() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${TAB_DB_PASSWORD:-}" ] || return 0

  local awk_program
  awk_program="$(cat <<'AWK'
function yaml_sq(v,   out) {
    out = v
    gsub(/'/, "&&", out)
    return "'" out "'"
}
function emit(text, cr) {
    printf "%s", text
    if (cr) printf "\r"
    printf "\n"
}
BEGIN {
    RS = "\n"
    have_prev = 0
    done_password = 0
    done_username = 0
    done_database = 0
}
{
    if (have_prev) emit(prev, prev_cr)
    line = $0
    cr = sub(/\r$/, "", line)

    if (!done_password && index(line, "  password:") == 1) {
        line = "  password: " yaml_sq(ENVIRON["INJ_PASSWORD"])
        done_password = 1
    }
    if (!done_username && index(line, "  username:") == 1) {
        line = "  username: " yaml_sq(ENVIRON["INJ_USERNAME"])
        done_username = 1
    }
    if (!done_database && index(line, "  database:") == 1) {
        line = "  database: " yaml_sq(ENVIRON["INJ_DATABASE"])
        done_database = 1
    }

    prev = line
    prev_cr = cr
    have_prev = 1
}
END {
    if (have_prev) {
        printf "%s", prev
        if (prev_cr) printf "\r"
        if (add_final_nl == "1") printf "\n"
    }
}
AWK
)"

  rewrite_config "${config}" "${awk_program}" \
    INJ_PASSWORD="${TAB_DB_PASSWORD:-}" \
    INJ_USERNAME="${TAB_DB_USER:-user}" \
    INJ_DATABASE="${TAB_DB_NAME:-tab}"
}

inject_authme() {
  local config="$1"
  [ -f "${config}" ] || return 0
  [ -n "${AUTHME_DB_PASSWORD:-}" ] || return 0

  local awk_program
  awk_program="$(cat <<'AWK'
function yaml_sq(v,   out) {
    out = v
    gsub(/'/, "&&", out)
    return "'" out "'"
}
function emit(text, cr) {
    printf "%s", text
    if (cr) printf "\r"
    printf "\n"
}
BEGIN {
    RS = "\n"
    have_prev = 0
    done_password = 0
    done_username = 0
    done_host = 0
    done_database = 0
}
{
    if (have_prev) emit(prev, prev_cr)
    line = $0
    cr = sub(/\r$/, "", line)

    if (!done_password && index(line, "    mySQLPassword:") == 1) {
        line = "    mySQLPassword: " yaml_sq(ENVIRON["INJ_PASSWORD"])
        done_password = 1
    }
    if (!done_username && index(line, "    mySQLUsername:") == 1) {
        line = "    mySQLUsername: " ENVIRON["INJ_USERNAME"]
        done_username = 1
    }
    if (!done_host && index(line, "    mySQLHost:") == 1) {
        line = "    mySQLHost: " ENVIRON["INJ_HOST"]
        done_host = 1
    }
    if (!done_database && index(line, "    mySQLDatabase:") == 1) {
        line = "    mySQLDatabase: " ENVIRON["INJ_DATABASE"]
        done_database = 1
    }

    prev = line
    prev_cr = cr
    have_prev = 1
}
END {
    if (have_prev) {
        printf "%s", prev
        if (prev_cr) printf "\r"
        if (add_final_nl == "1") printf "\n"
    }
}
AWK
)"

  rewrite_config "${config}" "${awk_program}" \
    INJ_PASSWORD="${AUTHME_DB_PASSWORD:-}" \
    INJ_USERNAME="${AUTHME_DB_USER:-authme}" \
    INJ_HOST="${AUTHME_DB_HOST:-127.0.0.1}" \
    INJ_DATABASE="${AUTHME_DB_NAME:-authme}"
}

inject_queqiao() {
  local config="$1"
  [ -f "${config}" ] || return 0
  if [ -z "${QUEQIAO_ACCESS_TOKEN:-}" ]; then
    echo "QUEQIAO_ACCESS_TOKEN is required while QueQiao is installed" >&2
    return 1
  fi

  local awk_program
  awk_program="$(cat <<'AWK'
function yaml_dq(v,   i, n, c, out) {
    out = ""
    n = length(v)
    for (i = 1; i <= n; i++) {
        c = substr(v, i, 1)
        if (c == "\\") out = out "\\" "\\"
        else if (c == "\"") out = out "\\" "\""
        else out = out c
    }
    return "\"" out "\""
}
function emit(text, cr) {
    printf "%s", text
    if (cr) printf "\r"
    printf "\n"
}
BEGIN {
    RS = "\n"
    have_prev = 0
    done = 0
}
{
    if (have_prev) emit(prev, prev_cr)
    line = $0
    cr = sub(/\r$/, "", line)

    if (!done && index(line, "access_token:") == 1) {
        rest = substr(line, length("access_token:") + 1)
        comment_idx = index(rest, " #")
        if (comment_idx > 0) {
            suffix = substr(rest, comment_idx)
        } else {
            suffix = ""
        }
        line = "access_token: " yaml_dq(ENVIRON["INJ_TOKEN"]) suffix
        done = 1
    }

    prev = line
    prev_cr = cr
    have_prev = 1
}
END {
    if (have_prev) {
        printf "%s", prev
        if (prev_cr) printf "\r"
        if (add_final_nl == "1") printf "\n"
    }
}
AWK
)"

  rewrite_config "${config}" "${awk_program}" \
    INJ_TOKEN="${QUEQIAO_ACCESS_TOKEN}"
}

for dir in "${LOBBY_DIR:-}" "${SURVIVAL_DIR:-}"; do
  [ -d "${dir}" ] || continue
  inject_luckperms "${dir}/plugins/LuckPerms/config.yml"
done

if [ -n "${VC_DIR:-}" ]; then
  # Velocity uses a lowercase LuckPerms directory, unlike the backends.
  inject_luckperms "${VC_DIR}/plugins/luckperms/config.yml"
  inject_queqiao "${VC_DIR}/plugins/QueQiao/config.yml"
fi

if [ -n "${LOBBY_DIR:-}" ]; then
  inject_authme "${LOBBY_DIR}/plugins/AuthMe/config.yml"
fi

if [ -n "${SURVIVAL_DIR:-}" ]; then
  inject_tab "${SURVIVAL_DIR}/plugins/TAB/config.yml"
fi
