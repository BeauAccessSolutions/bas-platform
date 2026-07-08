# BAS accessible login theme (`bas`)

The platform Keycloak login theme, built to genuinely meet **WCAG 2.2 AA**. This
is the surface every user of every BAS app meets before anything else, so it
clears the accessibility bar the platform asks its apps to clear (PLATFORM.md).

## What it is

A **CSS-only override** of Keycloak 26's *default* login theme —
`keycloak.v2` (PatternFly v5) — plus one tiny script. It ships no `.ftl`
template copies, so it survives Keycloak upgrades and keeps every built-in i18n
message bundle intact (platform invariant #5: no hardcoded strings).

> A previous scaffold extended the **classic** `keycloak` theme. Keycloak 26
> renders `keycloak.v2` by default, so those overrides targeted a DOM that never
> renders. This theme targets the real PatternFly-v5 markup
> (`.pf-v5-c-login`, `.pf-v5-c-form-control`, `.pf-v5-c-button.pf-m-primary`, …).

```
login/
├── theme.properties                 # parent=keycloak.v2; appends bas-a11y.css; adds lang script
└── resources/
    ├── css/bas-a11y.css             # the accessible overrides (loaded LAST, so it wins)
    └── js/bas-a11y.js               # sets html[lang] for WCAG 3.1.1 (see below)
```

`theme.properties` **replaces** the parent's `styles` (Keycloak does not merge
it), so it relists `css/styles.css` before `css/bas-a11y.css`. It does **not**
redeclare `stylesCommon` — the PatternFly vendor CSS is inherited from the
parent; redeclaring it would drop PatternFly and break the base layout.

## WCAG 2.2 AA coverage

| Criterion | How |
|---|---|
| 1.4.3 Contrast (min) | Palette chosen for ≥4.5:1 text on its surface (light **and** dark) |
| 1.4.10 Reflow | No horizontal scroll to 320px — the fixed `34rem` grid track is capped to the viewport |
| 1.4.11 Non-text contrast | 2px input borders & 3px focus rings, ≥3:1 on their surface |
| 1.4.12 Text spacing | `line-height:1.5`, `min-height` (never fixed height) so user spacing never clips |
| 2.3.3 Animation from interactions | `prefers-reduced-motion` neutralizes transitions/animations |
| 2.4.7 Focus visible | Thick, high-contrast ring on every interactive element |
| 2.4.11 Focus not obscured | `scroll-margin` keeps a focused field clear of any sticky chrome |
| 2.5.8 Target size | Inputs, buttons, and the password toggle are ≥44px (≫ the 24px floor) |
| 3.1.1 Language of page | `js/bas-a11y.js` sets `html[lang]` (see note) |
| dark mode | Full `prefers-color-scheme: dark` palette via `html.pf-v5-theme-dark` |

### Why a script for `lang`

Keycloak only renders `lang` on `<html>` when the realm has
internationalization enabled; the `bas` realm does not, so the default page
ships without it — an axe *serious* violation (3.1.1, Level A). `js/bas-a11y.js`
sets the platform default `lang="en"` **only if the server didn't provide one**,
so it stays correct if realm i18n is enabled later. It runs synchronously from
`<head>`, before assistive tech builds its buffer. This keeps the fix inside the
committed theme rather than in shared realm state that wouldn't travel with it.

## Deploy (production)

```bash
# 1. Ship the theme to the droplet (bind-mounted read-only into the container).
scp -r identity/themes/bas root@<droplet>:/opt/keycloak/themes/

# 2. Pick up the change. Use --force-recreate, NOT `restart`.
cd /opt/keycloak && docker compose up -d --force-recreate keycloak
```

> **Gotcha — `restart` is not enough.** `command: start` (production) caches
> themes, and the compose stack mounts **no** volume for `/opt/keycloak/data`,
> so Keycloak's extracted resource cache lives in the container's writable
> layer. `docker compose restart` reuses that layer and serves the **stale**
> CSS; `up -d --force-recreate` gives a fresh layer and rebuilds the cache from
> the mounted files. `start-dev` (the dev compose) does not cache themes, so a
> page reload is enough there.

## Activate (per realm — select *and* it's saved)

`loginTheme` is per-realm. The `basadmin` account has TOTP enrolled and cannot
do headless kcadm, so use the `bas-automation` service account (client
credentials; `SA_SECRET` in `/opt/keycloak/secrets.env`):

```bash
cd /opt/keycloak && set -a; . ./secrets.env; set +a
docker compose exec -T -e SA_SECRET keycloak bash -c '
  KC=/opt/keycloak/bin/kcadm.sh
  $KC config credentials --server http://localhost:8080 --realm master \
    --client bas-automation --secret "$SA_SECRET"
  $KC update realms/bas    -s loginTheme=bas
  $KC update realms/master -s loginTheme=bas
'
```

The dev reference bootstrap (`identity/dev/realm/bootstrap.sh`) sets
`loginTheme=bas` on realm create so a rebuilt realm is themed by default; mirror
that line into the prod parameterized bootstrap when it lands.

## Validate

Audited headless with axe-core (Playwright) against the live login form, light
**and** dark: **0 critical / 0 serious / 0 moderate / 0 minor**, 19 passes each.
Confirmed: custom stylesheet loaded and the photo background removed; inputs,
login button, and password toggle all ≥44px; 3px focus ring visible on keyboard
focus in both modes; no horizontal scroll at 320px.
