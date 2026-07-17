# Infrastructure Scripts

Miscellaneous scripts used throughout my homelab.

## Contents

# Traefik Scripts

This directory contains helper scripts for managing and monitoring a Traefik installation.

---

## notify-traefik-renewal.sh

Monitors Traefik's `acme.json` for certificate changes and sends a Pushover notification whenever certificates are:

- Renewed
- Added
- Removed

Unlike simply detecting that `acme.json` changed, the script compares per-certificate fingerprints, allowing it to report exactly which certificates changed.

### Features

- Detects certificate renewals
- Detects newly issued certificates
- Detects removed certificates
- Reports affected domains
- Reports the new certificate expiry date (for added and renewed certificates)
- Sends Pushover notifications
- Logs to the system journal via `logger`
- Never stores certificate or private key material outside of `acme.json`
- Stores only SHA-256 fingerprints and certificate metadata
- Uses a lightweight fingerprint database for change detection
- Automatically cleans up temporary files
- Robust error handling
- Cron-friendly
- ShellCheck-friendly

### Notification example

```text
🔐 Traefik Certificate Update

Time:
2026-07-16T13:00:00Z

✨ Freshly renewed:
🛡️ nextcloud.example.com
🛡️ immich.example.com

🎉 New certificates:
🌟 paperless.example.com

🧹 Removed certificates:
🗑️ old-test.example.com
```

### Requirements

- Bash 4+
- jq
- curl
- sha256sum
- logger (util-linux)
- openssl
- base64
- Pushover account
- Traefik using `acme.json`

### Configuration

Edit the configuration section at the top of the script:

```bash
ENV_FILE="/opt/docker/traefik/.pushover.env"
ACME_FILE="/opt/docker/traefik/letsencrypt/acme.json"
STATE_FILE="/opt/docker/traefik/.last_acme_state"
```

Example `.pushover.env`:

```bash
PUSHOVER_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
PUSHOVER_USER=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Installation

```bash
chmod +x notify-traefik-renewal.sh
```

Run daily from root's crontab:

```cron
0 13 * * * /opt/docker/traefik/notify-traefik-renewal.sh
```

### Logging

The script logs to the system journal.

View recent messages:

```bash
journalctl -t traefik-renewal
```

Follow live output:

```bash
journalctl -f -t traefik-renewal
```

### State file

The script maintains a small local state database containing:

- Domain
- Certificate fingerprint (SHA-256)
- Certificate expiry

No certificates or private keys are stored outside of Traefik's `acme.json`.

### Security

The script intentionally **does not**:

- copy `acme.json`
- export certificates
- export private keys

Only certificate fingerprints and metadata are stored for comparison between runs.

---

Developed and maintained by **Graham van der Wielen**.

Created with assistance from **ChatGPT (OpenAI)**.
