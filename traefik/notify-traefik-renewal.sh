#!/bin/bash
set -euo pipefail

###############################################################################
# notify-traefik-renewal.sh
#
# Sends a Pushover notification whenever Traefik's acme.json changes.
# Intended to run once per day from cron.
###############################################################################

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

ENV_FILE="/opt/docker/traefik/.pushover.env"
ACME_FILE="/opt/docker/traefik/letsencrypt/acme.json"
STATE_FILE="/opt/docker/traefik/.last_acme_hash"

LOGGER="/usr/bin/logger"
JQ="/usr/bin/jq"
CURL="/usr/bin/curl"
SHA256SUM="/usr/bin/sha256sum"
DATE="/usr/bin/date"

LOG_TAG="traefik-renewal"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

log_info() {
    "$LOGGER" -t "$LOG_TAG" "$1"
}

log_error() {
    "$LOGGER" -t "$LOG_TAG" -p user.err "$1"
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

if [[ ! -r "$ENV_FILE" ]]; then
    log_error "Missing or unreadable environment file: $ENV_FILE"
    exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

if [[ -z "${PUSHOVER_TOKEN:-}" || -z "${PUSHOVER_USER:-}" ]]; then
    log_error "Pushover credentials are missing from $ENV_FILE"
    exit 1
fi

if [[ ! -f "$ACME_FILE" ]]; then
    log_error "ACME file not found: $ACME_FILE"
    exit 1
fi

# ---------------------------------------------------------------------------
# Calculate current hash
# ---------------------------------------------------------------------------

CURRENT_HASH=$("$SHA256SUM" "$ACME_FILE" | awk '{print $1}')

# First run: create baseline and exit quietly.
if [[ ! -f "$STATE_FILE" ]]; then
    printf "%s\n" "$CURRENT_HASH" > "$STATE_FILE"
    chmod 600 "$STATE_FILE"
    log_info "Initial state created."
    exit 0
fi

LAST_HASH=$(<"$STATE_FILE")

# Nothing changed.
if [[ "$CURRENT_HASH" == "$LAST_HASH" ]]; then
    exit 0
fi

log_info "Detected change in acme.json."

# ---------------------------------------------------------------------------
# Extract domains
# ---------------------------------------------------------------------------

if ! DOMAINS=$(
    "$JQ" -r '
        .. | objects
        | select(.domain != null)
        | .domain.main
    ' "$ACME_FILE" 2>/dev/null | sort -u
); then
    DOMAINS="(unable to parse acme.json)"
    log_error "Failed to parse domain list from $ACME_FILE"
fi

[[ -z "$DOMAINS" ]] && DOMAINS="(no domains found)"

TIMESTAMP=$("$DATE" -u --iso-8601=seconds)

MESSAGE=$(cat <<EOF
🔐 Traefik updated one or more Let's Encrypt certificates.

Time:
$TIMESTAMP

Domains:
$(echo "$DOMAINS" | sed 's/^/ • /')
EOF
)

# ---------------------------------------------------------------------------
# Send Pushover notification
# ---------------------------------------------------------------------------

if ! RESPONSE=$(
    "$CURL" -fsS \
        -F "token=$PUSHOVER_TOKEN" \
        -F "user=$PUSHOVER_USER" \
        -F "title=Traefik Certificate Update" \
        -F "message=$MESSAGE" \
        https://api.pushover.net/1/messages.json
); then
    log_error "curl failed while contacting Pushover."
    exit 1
fi

STATUS=$(echo "$RESPONSE" | "$JQ" -r '.status // "unknown"' 2>/dev/null || echo "unknown")

if [[ "$STATUS" != "1" ]]; then
    log_error "Unexpected response from Pushover: $RESPONSE"
    exit 1
fi

# ---------------------------------------------------------------------------
# Update state
# ---------------------------------------------------------------------------

printf "%s\n" "$CURRENT_HASH" > "$STATE_FILE"
chmod 600 "$STATE_FILE"

log_info "Pushover notification sent successfully."

exit 0
