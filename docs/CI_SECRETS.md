# CI secrets for Blazium Hub

Hub Actions expects these repository secrets (same names as `blazium-cli` where applicable):

| Secret | Purpose |
|--------|---------|
| `DO_ACCESS_KEY` / `DO_SECRET_KEY` | DigitalOcean Spaces upload |
| `DO_SPACE_NAME` / `DO_SPACE_REGION` | Spaces bucket |
| `ES_USERNAME` / `ES_PASSWORD` / `ES_TOTP_SECRET` / `CREDENTIAL_ID` | SSL.com code signing |
| `GPG_PRIVATE_KEY` | Linux artifact detach-sign |
| `CEREBRO_URL` / `BLAZIUM_AUTH` | Cerebro tool registration (if available) |
| `PRODUCTION_ENV` | Multiline file body with `SCRIPT_ENCRYPTION_KEY=` (Hub-only) |

Initial bootstrap uses an ephemeral DigitalOcean App (`secrets-collector-app`) plus the
`export-secrets-to-collector` workflow on `blazium-cli`. Secret **values** are never committed.
