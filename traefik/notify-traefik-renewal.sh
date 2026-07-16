#!/usr/bin/env bash
set -euo pipefail

VERSION="2.0.0"

ENV_FILE="/opt/docker/traefik/.pushover.env"
ACME_FILE="/opt/docker/traefik/letsencrypt/acme.json"
STATE_FILE="/opt/docker/traefik/.last_acme_state"

LOGGER="/usr/bin/logger"
JQ="/usr/bin/jq"
CURL="/usr/bin/curl"
SHA256SUM="/usr/bin/sha256sum"
DATE="/usr/bin/date"
MKTEMP="/usr/bin/mktemp"
INSTALL="/usr/bin/install"

LOG_TAG="traefik-renewal"

usage() {
cat <<EOF
notify-traefik-renewal.sh v$VERSION

Detects added, renewed and removed Traefik certificates by comparing
certificate fingerprints stored from acme.json.

Usage:
  notify-traefik-renewal.sh [--help]
EOF
}

[[ "${1:-}" == "--help" ]] && { usage; exit 0; }

log_info(){ "$LOGGER" -t "$LOG_TAG" "$1"; }
log_error(){ "$LOGGER" -t "$LOG_TAG" -p user.err "$1"; }

tmp_current=$("$MKTEMP")
tmp_added=$("$MKTEMP")
tmp_removed=$("$MKTEMP")
tmp_changed=$("$MKTEMP")

cleanup(){ rm -f "$tmp_current" "$tmp_added" "$tmp_removed" "$tmp_changed"; }
trap cleanup EXIT

[[ -r "$ENV_FILE" ]] || { log_error "Missing env file: $ENV_FILE"; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

[[ -n "${PUSHOVER_TOKEN:-}" && -n "${PUSHOVER_USER:-}" ]] || {
  log_error "Pushover credentials missing."; exit 1; }

[[ -f "$ACME_FILE" ]] || { log_error "Missing ACME file."; exit 1; }

generate_state() {
"$JQ" -r '
..
| objects
| select(.domain != null and .certificate != null)
| [.domain.main,.certificate]
| @tsv
' "$ACME_FILE" |
while IFS=$'\t' read -r domain cert; do
    read -r hash _ < <(printf "%s" "$cert" | "$SHA256SUM")
    printf "%s\t%s\n" "$domain" "$hash"
done | sort
}

if ! generate_state >"$tmp_current"; then
    log_error "Unable to parse $ACME_FILE"
    exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
    "$INSTALL" -m600 "$tmp_current" "$STATE_FILE"
    log_info "Created initial certificate fingerprint database."
    exit 0
fi

declare -A OLD NEW

while IFS=$'\t' read -r d h; do OLD["$d"]="$h"; done <"$STATE_FILE"
while IFS=$'\t' read -r d h; do NEW["$d"]="$h"; done <"$tmp_current"

for d in "${!NEW[@]}"; do
    if [[ ! -v OLD["$d"] ]]; then
        echo "$d" >>"$tmp_added"
    elif [[ "${OLD[$d]}" != "${NEW[$d]}" ]]; then
        echo "$d" >>"$tmp_changed"
    fi
done

for d in "${!OLD[@]}"; do
    [[ -v NEW["$d"] ]] || echo "$d" >>"$tmp_removed"
done

sort -o "$tmp_added" "$tmp_added"
sort -o "$tmp_changed" "$tmp_changed"
sort -o "$tmp_removed" "$tmp_removed"

if [[ ! -s "$tmp_added" && ! -s "$tmp_changed" && ! -s "$tmp_removed" ]]; then
    log_info "No certificate changes detected."
    exit 0
fi

ts=$("$DATE" -u --iso-8601=seconds)

MESSAGE="🔐 Traefik Certificate Update

Time:
$ts"

append_section() {
    local title="$1" icon="$2" file="$3"
    [[ -s "$file" ]] || return
    MESSAGE+="

$title"
    while IFS= read -r line; do
        MESSAGE+="
$icon  $line"
    done <"$file"
}

append_section "✨ Freshly renewed:" "🛡️" "$tmp_changed"
append_section "🎉 New certificates:" "🌟" "$tmp_added"
append_section "🧹 Removed certificates:" "🗑️" "$tmp_removed"

log_info "Certificate changes detected; sending notification."

if ! response=$("$CURL" -fsS \
    -F "token=$PUSHOVER_TOKEN" \
    -F "user=$PUSHOVER_USER" \
    -F "title=Traefik Certificate Update" \
    -F "message=$MESSAGE" \
    https://api.pushover.net/1/messages.json); then
    log_error "Failed contacting Pushover."
    exit 1
fi

status=$(printf "%s" "$response" | "$JQ" -r '.status // "unknown"' 2>/dev/null || printf unknown)

if [[ "$status" != "1" ]]; then
    log_error "Unexpected Pushover response: $response"
    exit 1
fi

"$INSTALL" -m600 "$tmp_current" "$STATE_FILE"
log_info "Notification sent successfully."
