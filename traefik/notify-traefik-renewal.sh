#!/bin/bash
source /opt/docker/traefik/.pushover.env

# CONFIG
ACME_FILE="/opt/docker/traefik/letsencrypt/acme.json"  
LAST_CHECK="/tmp/last_acme_check"

# Create baseline file if needed
[[ ! -f "$LAST_CHECK" ]] && cp "$ACME_FILE" "$LAST_CHECK"

# Compare hashes
if ! cmp -s "$ACME_FILE" "$LAST_CHECK"; then
  # Something changed
  DOMAINS=$(jq -r '.. | objects | select(.domain!=null) | .domain.main' "$ACME_FILE" | sort | uniq)
  MSG="🔐 Traefik certs renewed for:$DOMAINS"

  # Send push notification
  curl -s \
    -F "token=$PUSHOVER_TOKEN" \
    -F "user=$PUSHOVER_USER" \
    -F "title=Traefik Cert Renewed" \
    -F "message=$MSG" \
    https://api.pushover.net/1/messages.json

  # Update reference
  cp "$ACME_FILE" "$LAST_CHECK"
fi

