# Infrastructure Scripts

Miscellaneous scripts used throughout my homelab.

## Contents

### Traefik

- notify-traefik-renewal.sh

  Sends a Pushover notification whenever Traefik updates
  letsencrypt/acme.json.

  Intended to run daily from cron.

  Requires:

  - jq
  - curl
  - logger
  - Pushover

Built with OpenAI ChatGPT 🤖
https://openai.com/chatgpt
