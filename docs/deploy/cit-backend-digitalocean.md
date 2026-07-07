# Deploy runbook: CIT backend on DigitalOcean App Platform

Status: **runbook / not yet executed** · Last updated: 2026-07-07
Anchors: [phase-0-execution.md](../phase-0-execution.md) · CIT `.do/app.yaml`

Deploy the Chronic Illness Tracker (Next.js + Postgres) so the app is reachable off
localhost. The spec already exists at CIT `.do/app.yaml` — a PRE_DEPLOY `migrate` job
(`prisma migrate deploy`) plus a `web` service with a `/api/health` check. This runbook
is the mechanics + the secrets you must set.

## Before you deploy

- The spec's `github.repo` is `kbeaudoin001/Chronic-Illness-Tracker`, branch `main`,
  `deploy_on_push: true`. So **merging to `main` triggers a deploy.** Merge the security
  branches and the `feat/oidc-session-endpoint` PR to `main` first, or point the spec at
  the branch you want to ship.
- The new `20260707…add_oidc_sub` migration will run in the PRE_DEPLOY job — that's the
  intended path (verify it once with `prisma migrate dev` against a shadow DB first).

## Steps

**1. Create the app from the spec.**
```sh
doctl apps create --spec .do/app.yaml
```
Or dashboard → Apps → Create → "Import from app spec". This provisions the dev Postgres
(`db`) defined in the spec and wires `DATABASE_URL` + `DATABASE_CA_CERT`.

**2. Set the encrypted secrets** (dashboard → app → Settings → App-Level Env, type
`SECRET` — never in the repo):
- `ANTHROPIC_API_KEY` — only if enabling AI (`AI_PROVIDER=anthropic`); otherwise leave `AI_PROVIDER=mock`.
- **Later, once Keycloak is live** (enables the platform login endpoint):
  - `KEYCLOAK_ISSUER=https://id.beauaccesssolutions.com/realms/bas`
  - `KEYCLOAK_CLIENT_ID=cit-web`
  - (optional) `KEYCLOAK_JWKS_URL`
  Until these are set, `POST /api/auth/session` is inert and password login is used.

**3. First deploy runs migrations automatically** (the `migrate` PRE_DEPLOY job). Watch:
```sh
doctl apps list                       # get the app id
doctl apps logs <app-id> --type deploy
```

**4. Verify.**
```sh
APP_URL=$(doctl apps get <app-id> --format DefaultIngress --no-header)
curl -fsS "$APP_URL/api/health"                 # expect ok
# smoke: password signup/login still works; export produces a signed URL
```
Confirm TLS-to-DB is verified (the spec sets `DATABASE_CA_CERT=${db.CA_CERT}` so TLS is
checked against DO's CA, not disabled).

**5. Production database.** The spec's `db` is the ~$7/mo dev database (`production:
false`). Before real users, provision a managed HA Postgres cluster and attach it
instead (dashboard → Databases), then update `DATABASE_URL`.

## Once both are up (Keycloak + CIT)

Set the `KEYCLOAK_*` secrets (step 2), redeploy, and test the full path:
```sh
# obtain a Keycloak token via the cit-web client (PKCE), then:
curl -fsS -X POST "$APP_URL/api/auth/session" -H 'content-type: application/json' \
  -d '{"idToken":"<oidc-token>"}'
# expect: a CIT session (Set-Cookie) + { user, sessionToken }
```
That closes the Phase 0 exit criterion: a real (non-local) Keycloak login mints a CIT
session end-to-end.

## Notes

- No PHI in any env var, log, or the app spec. Secrets are DO-encrypted env vars only.
- Export files use `EXPORT_DIR=/tmp/exports` (ephemeral) — fine for signed-URL downloads
  within their short window; not durable storage.
