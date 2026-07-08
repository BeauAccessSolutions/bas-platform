# Keycloak: stand-up & hardening checklist (Phase 0)

Status: **checklist / not yet executed** · Last updated: 2026-07-07
Anchors: [ADR-001](adr/001-platform-architecture-and-identity.md) ·
[ADR-003 pairwise sub](adr/003-pairwise-subject-identifiers.md) ·
[ADR-004 user migration](adr/004-existing-user-migration.md) · [PLATFORM.md](../PLATFORM.md)

The identity service is the single most security-sensitive component in the platform —
it authenticates access to health, dating, and veteran data. Treat this as a hardened,
isolated, minimal service. Work top to bottom; nothing downstream (Phase 1 OIDC
contract) should start until §1–§4 hold.

Distribution: **Keycloak (Quarkus dist), pinned to a specific version.** Never run the
legacy WildFly dist, never run `start-dev` in production.

---

## 1. Isolation & deployment

- [ ] Runs as its **own service**, separate from every app's infra (own container/VM, own
      network) — a compromise of any app must not reach the IdP host. (ADR-001)
- [ ] **Dedicated Postgres**, not shared with any app database. Own credentials.
- [ ] Own hostname on HTTPS only, e.g. `id.beauaccesssolutions.com` — a generic identity
      host that does not name any app.
- [ ] `KC_HOSTNAME` pinned; `KC_PROXY`/`--proxy-headers` set correctly for the TLS-terminating
      proxy so Keycloak sees real client IPs and issues correct redirect URIs.
- [ ] Production mode (`kc.sh start`), `KC_HTTP_ENABLED=false` (TLS only), HSTS on at the proxy.
- [ ] Secrets (DB password, admin creds, SMTP) come from the platform secret store, never a committed file.
- [ ] Version pinned + a **patch cadence** owner assigned; subscribe to Keycloak security advisories.

## 2. Admin plane hardening

- [ ] Bootstrap admin replaced with a named admin account; **delete the temp admin**.
- [ ] Admin console reachable only from an allowlist / VPN (not the public internet), or at minimum a non-default path + strong 2FA on admin accounts.
- [ ] Built-in **brute-force detection** enabled (permanent-lockout or temporary with backoff).
- [ ] Realm **SSL required = external requests** (or all).
- [ ] Disable any flows you don't use (Direct Access Grants / password grant, Implicit flow) — reduce surface.
- [ ] Event logging on (login + admin events), retention set — but **verify no tokens/secrets are logged**.

## 3. Realm, clients & the pairwise-sub invariant

- [ ] One platform realm (e.g. `bas`); users live here, one **client per app**.
- [ ] Each app client: **Authorization Code + PKCE**; Implicit and password grants off.
- [ ] Redirect URIs are an **exact allowlist** (no wildcards on the host); web + native (AppAuth custom scheme) URIs only.
- [ ] Client type per app: server-side callback = **confidential**; pure SPA/native = **public** (PKCE mandatory).
- [ ] **Pairwise subject identifiers per client** (ADR-003): set Subject Type = `pairwise` with a sector identifier so each app receives a *different* stable `sub` for the same user — no cross-app correlation from tokens or data.
- [ ] `aud`/`azp` scoped to each client so a token minted for one app is **rejected** by another (matches CIT spec's audience check).
- [ ] Consent + scopes minimal; do not leak profile attributes an app doesn't need.

## 4. Tokens, keys & sessions

- [ ] **Short-lived access tokens** (minutes); refresh tokens with **rotation** + reuse detection.
- [ ] Signing = RS256 (asymmetric) so resource servers verify via JWKS; **no HS256 shared secret**.
- [ ] **Key rotation** policy defined; JWKS caching on the app side honors rollover (CIT spec §5).
- [ ] SSO session idle/max timeouts set; remember-me policy decided.
- [ ] Confirms the layered-session model: apps mint their **own** session after login; the IdP token is short-lived and never the data-access credential.

## 5. 2FA & step-up (ACR/LoA)

- [ ] OTP (TOTP) + **WebAuthn/passkeys** enabled as second factors.
- [ ] Authentication flows define **assurance levels**; sensitive apps request step-up via `acr_values` and Keycloak enforces re-auth (CIT applies this to delete/export/regimen).
- [ ] Recovery path (backup codes / recovery email) that itself can't be used to bypass 2FA silently.

## 6. Login theme — WCAG 2.2 AA (non-negotiable)

The hosted login page **is** the user-facing auth surface (apps render no credential
form — CIT spec §2/§5). It must meet the strictest a11y bar in the portfolio.

- [ ] Custom Keycloak theme (login + account) — do not ship the stock theme unaudited.
- [ ] Contrast ≥ WCAG 2.2 AA; visible focus indicators; logical focus order.
- [ ] Every field programmatically labelled; errors associated to fields and announced (`aria-live`).
- [ ] Full keyboard operability; tap targets ≥ 44×44px; honors `prefers-reduced-motion`.
- [ ] `lang` attribute set + Keycloak i18n enabled; **Spanish reviewed by a fluent human** before release (mirrors CIT non-negotiable #11).
- [ ] Passes **axe** *and* a manual VoiceOver + TalkBack pass (automated-only is not sufficient).
- [ ] No third-party scripts/trackers on the login page (mirrors invariant #2).

## 7. Email

- [ ] SMTP configured; **email verification required**; password-reset flow tested.
- [ ] Templates themed + translated, plain-language, no PHI/app-identifying content.

## 8. Backups & disaster recovery

- [ ] Automated Postgres backups **with a tested restore** (untested backups don't count).
- [ ] **Realm signing keys backed up** separately (losing them invalidates every live session/token).
- [ ] Availability target stated; a documented restore runbook. (Tracker §3 DR item.)

## 9. Monitoring

- [ ] Health/readiness probes wired; uptime monitoring on the IdP host.
- [ ] Alerts on failed-login spikes and admin-event anomalies.

## 10. Migration (when apps onboard)

- [ ] Follow [ADR-004](adr/004-existing-user-migration.md) — CIT first: import existing users
      (or lazy just-in-time migration on first Keycloak login), preserving each app's user↔`sub`
      mapping via the app's pairwise `oidcSub`.

---

**Exit criterion for Phase 0 (identity side):** a hardened Keycloak is reachable over
HTTPS at its own host, with the CIT client configured (PKCE, pairwise `sub`, audience
scoping) and an accessible login theme, so Phase 1 can define the OIDC contract against
a real IdP.
