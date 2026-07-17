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


   ________          __  ________ _____________
  / ____/ /_  ____ _/ /_/ ____/ // / ____/_  __/
 / /   / __ \/ __ `/ __/ / __/ // / /     / /
/ /___/ / / / /_/ / /_/ /_/ /__  / /___  / /
\____/_/ /_/\__,_/\__/\____/  /_/\____/ /_/

Built with OpenAI ChatGPT 🤖
https://openai.com/chatgpt
