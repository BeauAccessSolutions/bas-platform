# Deploy runbook: standalone Keycloak on DigitalOcean

Status: **runbook / not yet executed** · Last updated: 2026-07-07
Anchors: [keycloak-setup-and-hardening.md](../keycloak-setup-and-hardening.md) ·
[phase-0-execution.md](../phase-0-execution.md) · [ADR-001](../adr/001-platform-architecture-and-identity.md)

Stand up the platform identity service as its **own isolated, hardened** host — not
sharing infra with any app. Do the hardening checklist alongside this; this runbook is
the DO-specific mechanics, the checklist is the security bar.

## Choose the shape

| | **Droplet + Docker (recommended)** | App Platform (alternative) |
|---|---|---|
| Admin-console network isolation | ✅ firewall / SSH-tunnel the admin path | ⚠️ weak — no easy IP allowlist |
| TLS | Caddy auto-TLS (or nginx + certbot) | ✅ managed |
| Control / matches "hardened isolated service" | ✅ full | partial |
| Effort | slightly more | less |

For a PHI-adjacent IdP the admin-plane isolation (hardening §2) matters, so **Droplet**
is the recommendation. App Platform deltas are noted at the end.

## Prerequrisites

- `doctl` authenticated; a domain you control (marketing domain is fine).
- **DO Managed Postgres** (dedicated to Keycloak — not CIT's DB). Note its host, port
  (`25060`), db name, user, password, and CA cert.
- DNS: an `A` record `id.beauaccesssolutions.com` → the Droplet's IP (create after step 2).

## Steps

**1. Managed Postgres (dedicated).**
```sh
doctl databases create bas-keycloak-db --engine pg --version 16 --region nyc1 --size db-s-1vcpu-1gb
# note the connection details; create a database `keycloak` and a restricted user
```
Add the Droplet (step 2) to the DB's **trusted sources** so only it can connect.

**2. Droplet.**
```sh
doctl compute droplet create bas-keycloak --region nyc1 --image docker-20-04 \
  --size s-1vcpu-2gb --ssh-keys <your-key-id>
```
Then point the `id.` DNS `A` record at its IP.

**3. Cloud Firewall — public 443 only; SSH restricted.**
```sh
# inbound: 443 from anywhere; 22 only from your IP. NOT 8080 (Keycloak stays behind Caddy).
doctl compute firewall create --name bas-keycloak-fw \
  --inbound-rules "protocol:tcp,ports:443,address:0.0.0.0/0 protocol:tcp,ports:22,address:<your-ip>/32" \
  --outbound-rules "protocol:tcp,ports:all,address:0.0.0.0/0 protocol:udp,ports:all,address:0.0.0.0/0" \
  --droplet-ids <droplet-id>
```

**4. On the Droplet — compose (prod Keycloak behind Caddy).** Secrets come from a
`.env` on the host (chmod 600), never committed.

`compose.yml`:
```yaml
services:
  keycloak:
    image: quay.io/keycloak/keycloak:26.0        # pin; matches identity/dev
    command: start --optimized
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://${PG_HOST}:25060/keycloak?sslmode=require
      KC_DB_USERNAME: ${PG_USER}
      KC_DB_PASSWORD: ${PG_PASSWORD}
      KC_HOSTNAME: https://id.beauaccesssolutions.com
      KC_HTTP_ENABLED: "true"          # TLS is terminated by Caddy; KC speaks http on the internal net
      KC_PROXY_HEADERS: xforwarded     # trust X-Forwarded-* from Caddy only
      KC_HEALTH_ENABLED: "true"
      KC_BOOTSTRAP_ADMIN_USERNAME: ${KC_ADMIN}      # first-boot only; delete after §2
      KC_BOOTSTRAP_ADMIN_PASSWORD: ${KC_ADMIN_PASSWORD}
    expose: ["8080"]
    restart: unless-stopped
  caddy:
    image: caddy:2
    ports: ["443:443", "80:80"]
    volumes: [caddy_data:/data, ./Caddyfile:/etc/caddy/Caddyfile:ro]
    restart: unless-stopped
volumes: { caddy_data: {} }
```
`Caddyfile` (auto-TLS via Let's Encrypt):
```
id.beauaccesssolutions.com {
    reverse_proxy keycloak:8080
}
```
> Env-var names are version-specific — verify against the pinned Keycloak 26 docs.
> `KC_PROXY` was replaced by `KC_PROXY_HEADERS` in 26.

**5. Boot + verify.**
```sh
docker compose up -d
curl -fsS https://id.beauaccesssolutions.com/health/ready        # Keycloak health
curl -fsS https://id.beauaccesssolutions.com/realms/master/.well-known/openid-configuration >/dev/null
```

**6. Harden — do the checklist now.** Follow
[keycloak-setup-and-hardening.md](../keycloak-setup-and-hardening.md) §2–§9:
replace/lock the admin account, restrict the admin path (SSH tunnel or a separate
allowlisted firewall rule), enable brute-force detection, create the `bas` realm +
`cit-web` client (PKCE, **pairwise `sub`**, audience), set token TTLs + RS256, enable
2FA/step-up, apply the accessible login theme (§6), and configure backups (§8).

**7. Realm-as-code.** Import the realm exported from `identity/dev` (once validated
locally) so prod config isn't click-ops:
```sh
docker compose exec keycloak /opt/keycloak/bin/kc.sh import --file /path/bas-realm.json
```

## App Platform alternative (deltas)

Deploy the Keycloak container as an App Platform **service** (`start --optimized`,
`KC_PROXY_HEADERS=xforwarded`, `KC_HOSTNAME=https://…`), attach the managed Postgres,
let App Platform handle TLS + the domain + health checks (`/health/ready`). Trade-off:
you lose easy admin-console network isolation (hardening §2) — compensate with a
strong, 2FA-gated admin account and consider a separate admin-only client/realm.

## Exit criterion

`https://id.beauaccesssolutions.com` serves a hardened Keycloak; the `bas` realm +
`cit-web` client exist; the JWKS endpoint
(`/realms/bas/protocol/openid-connect/certs`) is reachable — CIT's `KEYCLOAK_ISSUER`
can point at `https://id.beauaccesssolutions.com/realms/bas`.
