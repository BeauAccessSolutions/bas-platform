#!/usr/bin/env bash
# Realm-as-code (reference bootstrap) for the platform Keycloak.
#
# Creates the `bas` realm and the `cit-web` client with the settings CIT's
# /api/auth/session endpoint expects: Authorization-Code + PKCE (S256), a
# PAIRWISE `sub` (BAS ADR-003), and audience/azp scoped to the client so a token
# minted for a sibling app is rejected.
#
# This is a REFERENCE script — kcadm syntax and mapper names are version-specific.
# Validate against the pinned Keycloak (identity/dev/docker-compose.yml, 26.x),
# then EXPORT the resulting realm to identity/dev/realm/bas-realm.json — the export
# is the authoritative artifact (--import-realm loads it). See ../README.md.
#
# Usage (against the local dev Keycloak):
#   docker compose -f identity/dev/docker-compose.yml exec keycloak \
#     bash /opt/keycloak/data/import/bootstrap.sh
# (The compose mounts ./realm -> /opt/keycloak/data/import, so the script lands at
#  /opt/keycloak/data/import/bootstrap.sh — NOT under a realm/ subdir.)
set -euo pipefail

KC=/opt/keycloak/bin/kcadm.sh
REALM="${REALM:-bas}"
CIT_REDIRECT_WEB="${CIT_REDIRECT_WEB:-http://localhost:3000/api/auth/session*}"
# Native redirect for the CIT Expo app (bas-apps/apps/cit). cit-web is the single
# CIT public/PKCE client for BOTH web and native, so the same user has one pairwise
# sub across surfaces and the backend needs no azp change. The scheme is the app's
# reverse-DNS scheme registered in app.json; Expo's makeRedirectUri({scheme, path:'oauth'})
# produces exactly this. A separate cit-mobile client is a possible future hardening
# (needs the backend to allow azp ∈ {cit-web, cit-mobile}).
CIT_REDIRECT_NATIVE="${CIT_REDIRECT_NATIVE:-com.beauaccesssolutions.cit://oauth*}"
ACCESS_TOKEN_LIFESPAN="${ACCESS_TOKEN_LIFESPAN:-300}"  # 5 min — short-lived identity token

# Pairwise-sub salts (ADR-003). Dev defaults are placeholders; PROD MUST pass strong,
# secret, STABLE per-client salts (see identity/prod/gen-secrets.sh).
# ⚠️ Never rotate a live salt — it changes every user's `sub` and orphans each app's
#    stored identity rows (KindredAccess KeycloakIdentity, CIT oidcSub, ...).
CIT_PAIRWISE_SALT="${CIT_PAIRWISE_SALT:-cit-sector-salt-dev}"
KA_PAIRWISE_SALT="${KA_PAIRWISE_SALT:-ka-sector-salt-dev}"
AA_PAIRWISE_SALT="${AA_PAIRWISE_SALT:-aa-sector-salt-dev}"
DW_PAIRWISE_SALT="${DW_PAIRWISE_SALT:-dw-sector-salt-dev}"
BN_PAIRWISE_SALT="${BN_PAIRWISE_SALT:-bn-sector-salt-dev}"

# Sector Identifier URI for cit-web (ADR-003). cit-web serves BOTH web and native, so its
# redirect URIs span multiple hosts — and Keycloak's pairwise-sub mapper then REQUIRES a
# Sector Identifier URI: a reachable HTTPS doc returning a JSON array of cit-web's redirect
# URIs. Keycloak FETCHES and validates it at mapper-create time. Without it the pairwise
# mapper is REJECTED and cit-web silently falls back to a NON-pairwise (correlatable) sub —
# an ADR-003 breach. Prod: host it at e.g. https://id.<domain>/oidc/cit-web-sector.json (see
# the deploy runbook) and set CIT_SECTOR_URI to it. Leave empty ONLY for a throwaway dev run
# — the guard at the end WARNs loudly in that case and FAILs hard when the URI is set but bad.
CIT_SECTOR_URI="${CIT_SECTOR_URI:-}"

# 1. Authenticate (dev creds; prod uses a locked-down admin — hardening §2).
"$KC" config credentials --server http://localhost:8080 --realm master \
  --user "${KC_ADMIN:-admin}" --password "${KC_ADMIN_PASSWORD:-admin}"

# 2. Realm.
#    loginTheme=bas is the platform's WCAG 2.2 AA accessible login theme
#    (identity/themes/bas). It must be mounted into the container — the dev
#    compose bind-mounts identity/themes -> /opt/keycloak/themes; prod ships it
#    to /opt/keycloak/themes/bas. Set it here so a realm rebuilt from this script
#    (or its exported bas-realm.json) renders the accessible theme, not the
#    default. NOTE: also set loginTheme=bas on the `master` realm so the admin
#    login matches, and mirror this line into the prod parameterized bootstrap.
"$KC" create realms -s realm="$REALM" -s enabled=true \
  -s accessTokenLifespan="$ACCESS_TOKEN_LIFESPAN" \
  -s loginTheme=bas \
  -s sslRequired=external || echo "realm may already exist"

# 2b. Relax the declarative user profile: make firstName/lastName OPTIONAL (username +
#     email stay required). KindredAccess has a single display_name — no first/last split
#     (also more inclusive) — and Keycloak 24+ flags accounts missing required attributes
#     as "not fully set up", which blocks login for migrated KA users (ADR-004). Verified
#     against KC 26: with this relaxation a user with no last name authenticates fine.
cat > /tmp/bas-user-profile.json <<'JSON'
{
  "attributes": [
    { "name": "username", "displayName": "${username}",
      "permissions": { "view": ["admin","user"], "edit": ["admin","user"] } },
    { "name": "email", "displayName": "${email}",
      "permissions": { "view": ["admin","user"], "edit": ["admin","user"] },
      "required": { "roles": ["user"] },
      "validations": { "email": {}, "length": { "max": 255 } } },
    { "name": "firstName", "displayName": "${firstName}",
      "permissions": { "view": ["admin","user"], "edit": ["admin","user"] } },
    { "name": "lastName", "displayName": "${lastName}",
      "permissions": { "view": ["admin","user"], "edit": ["admin","user"] } }
  ]
}
JSON
"$KC" update "users/profile" -r "$REALM" -f /tmp/bas-user-profile.json \
  && echo "relaxed user profile: firstName/lastName optional" \
  || echo "NOTE: user-profile update failed — verify kcadm path for your KC version"

# 3. cit-web client: public, PKCE, standard flow only.
CID=$("$KC" create clients -r "$REALM" \
  -s clientId=cit-web \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s implicitFlowEnabled=false \
  -s directAccessGrantsEnabled=false \
  -s 'attributes."pkce.code.challenge.method"=S256' \
  -s "redirectUris=[\"$CIT_REDIRECT_WEB\",\"$CIT_REDIRECT_NATIVE\"]" \
  -i)
echo "created cit-web client: $CID"

# 4. Pairwise `sub` (ADR-003): the same user gets a different, stable sub per app,
#    so CIT's sub never correlates with KindredAccess / Benefits Navigator.
#    Provider id is `oidc-sha256-pairwise-sub-mapper` (verified on KC 26 via
#    `kcadm get serverinfo`); salt config key is `pairwiseSubAlgorithmSalt`. The
#    older `oidc-sub-mapper` is the *non*-pairwise sub mapper and leaves sub = the
#    raw user id — do not use it here.
CIT_PW_ARGS=( -s name=pairwise-subject \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-sha256-pairwise-sub-mapper \
  -s "config.\"pairwiseSubAlgorithmSalt\"=$CIT_PAIRWISE_SALT" \
  -s 'config."id.token.claim"=true' \
  -s 'config."access.token.claim"=true' )
# Multi-host redirect (web + native) => Keycloak requires a Sector Identifier URI here.
[[ -n "$CIT_SECTOR_URI" ]] && CIT_PW_ARGS+=( -s "config.\"sectorIdentifierUri\"=$CIT_SECTOR_URI" )
"$KC" create "clients/$CID/protocol-mappers/models" -r "$REALM" "${CIT_PW_ARGS[@]}" \
  || echo "NOTE: cit-web pairwise mapper create returned non-zero (exists on re-run, or CIT_SECTOR_URI unreachable — the guard below decides if that's fatal)"

# 5. Audience: ensure aud includes cit-web so CIT's verifier can enforce it.
"$KC" create "clients/$CID/protocol-mappers/models" -r "$REALM" \
  -s name=cit-web-audience \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-audience-mapper \
  -s 'config."included.client.audience"=cit-web' \
  -s 'config."access.token.claim"=true' \
  || echo "audience mapper may already exist"

# =============================================================================
# kindredaccess-web client (BAS app #2, Django).
# Unlike cit-web (public: browser/native front-end), KindredAccess's Django backend
# is a CONFIDENTIAL client — it can hold a secret — so we use confidential + PKCE
# (strictly stronger). Same pairwise `sub` + audience isolation as cit-web.
# Redirect URI is mozilla-django-oidc's callback: <origin>/oidc/callback/.
# =============================================================================
KA_REDIRECT_WEB="${KA_REDIRECT_WEB:-http://localhost:8000/oidc/callback/*}"
KA_POST_LOGOUT="${KA_POST_LOGOUT:-http://localhost:8000/*}"

KA_CID=$("$KC" create clients -r "$REALM" \
  -s clientId=kindredaccess-web \
  -s publicClient=false \
  -s standardFlowEnabled=true \
  -s implicitFlowEnabled=false \
  -s directAccessGrantsEnabled=false \
  -s 'attributes."pkce.code.challenge.method"=S256' \
  -s "redirectUris=[\"$KA_REDIRECT_WEB\"]" \
  -s "attributes.\"post.logout.redirect.uris\"=$KA_POST_LOGOUT" \
  -i)
echo "created kindredaccess-web client: $KA_CID"

# Client secret (KindredAccess needs it as OIDC_RP_CLIENT_SECRET). In prod, set it
# explicitly from KA_CLIENT_SECRET (identity/prod/secrets.env) so the value is known and
# reproducible; in dev, just reveal the auto-generated one.
if [[ -n "${KA_CLIENT_SECRET:-}" ]]; then
  "$KC" update "clients/$KA_CID" -r "$REALM" -s "secret=$KA_CLIENT_SECRET" \
    && echo "set kindredaccess-web secret from KA_CLIENT_SECRET"
else
  "$KC" get "clients/$KA_CID/client-secret" -r "$REALM" \
    && echo "^ dev: set this as KindredAccess OIDC_RP_CLIENT_SECRET"
fi

# Pairwise `sub` (ADR-003) — KA's sub never correlates with cit-web's.
# (see the cit-web mapper above for the provider-id / salt rationale)
"$KC" create "clients/$KA_CID/protocol-mappers/models" -r "$REALM" \
  -s name=pairwise-subject \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-sha256-pairwise-sub-mapper \
  -s "config.\"pairwiseSubAlgorithmSalt\"=$KA_PAIRWISE_SALT" \
  -s 'config."id.token.claim"=true' \
  -s 'config."access.token.claim"=true' \
  || echo "pairwise mapper may already exist"

# Audience: ensure aud/azp includes kindredaccess-web so KA can reject foreign tokens.
"$KC" create "clients/$KA_CID/protocol-mappers/models" -r "$REALM" \
  -s name=kindredaccess-web-audience \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-audience-mapper \
  -s 'config."included.client.audience"=kindredaccess-web' \
  -s 'config."access.token.claim"=true' \
  || echo "audience mapper may already exist"

# =============================================================================
# access-atlas client (BAS app #3) — "Atlas-shaped": an Astro app with a server-side
# BFF (/api/auth/*) that runs the Authorization-Code + PKCE flow. PUBLIC client, no
# secret (the BFF exchanges the code with PKCE). Single redirect host, so — unlike
# cit-web — NO Sector Identifier URI is needed and the pairwise mapper lands directly.
# =============================================================================
AA_REDIRECT_WEB="${AA_REDIRECT_WEB:-http://localhost:4321/api/auth/callback}"
AA_POST_LOGOUT="${AA_POST_LOGOUT:-http://localhost:4321/*}"

AA_CID=$("$KC" create clients -r "$REALM" \
  -s clientId=access-atlas \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s implicitFlowEnabled=false \
  -s directAccessGrantsEnabled=false \
  -s 'attributes."pkce.code.challenge.method"=S256' \
  -s "redirectUris=[\"$AA_REDIRECT_WEB\"]" \
  -s "attributes.\"post.logout.redirect.uris\"=$AA_POST_LOGOUT" \
  -i)
echo "created access-atlas client: $AA_CID"

"$KC" create "clients/$AA_CID/protocol-mappers/models" -r "$REALM" \
  -s name=pairwise-subject \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-sha256-pairwise-sub-mapper \
  -s "config.\"pairwiseSubAlgorithmSalt\"=$AA_PAIRWISE_SALT" \
  -s 'config."id.token.claim"=true' \
  -s 'config."access.token.claim"=true' \
  || echo "pairwise mapper may already exist"

"$KC" create "clients/$AA_CID/protocol-mappers/models" -r "$REALM" \
  -s name=access-atlas-audience \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-audience-mapper \
  -s 'config."included.client.audience"=access-atlas' \
  -s 'config."access.token.claim"=true' \
  || echo "audience mapper may already exist"

# =============================================================================
# disability-wiki-web client (BAS app #4) — same Atlas-shaped public + PKCE + BFF pattern as
# access-atlas (identity gates *contribution* only; public browsing never authenticates).
# Single redirect host → no Sector Identifier URI. Callback: <origin>/api/auth/callback.
# =============================================================================
DW_REDIRECT_WEB="${DW_REDIRECT_WEB:-http://localhost:4321/api/auth/callback}"
DW_POST_LOGOUT="${DW_POST_LOGOUT:-http://localhost:4321/*}"

DW_CID=$("$KC" create clients -r "$REALM" \
  -s clientId=disability-wiki-web \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s implicitFlowEnabled=false \
  -s directAccessGrantsEnabled=false \
  -s 'attributes."pkce.code.challenge.method"=S256' \
  -s "redirectUris=[\"$DW_REDIRECT_WEB\"]" \
  -s "attributes.\"post.logout.redirect.uris\"=$DW_POST_LOGOUT" \
  -i)
echo "created disability-wiki-web client: $DW_CID"

"$KC" create "clients/$DW_CID/protocol-mappers/models" -r "$REALM" \
  -s name=pairwise-subject \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-sha256-pairwise-sub-mapper \
  -s "config.\"pairwiseSubAlgorithmSalt\"=$DW_PAIRWISE_SALT" \
  -s 'config."id.token.claim"=true' \
  -s 'config."access.token.claim"=true' \
  || echo "pairwise mapper may already exist"

"$KC" create "clients/$DW_CID/protocol-mappers/models" -r "$REALM" \
  -s name=disability-wiki-web-audience \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-audience-mapper \
  -s 'config."included.client.audience"=disability-wiki-web' \
  -s 'config."access.token.claim"=true' \
  || echo "audience mapper may already exist"

# =============================================================================
# benefits-navigator-web client (BAS app #5, Django) — STUB / not yet integrated.
# BN currently authenticates with django-allauth (local); it has NO OIDC RP wired yet
# (see docs/deploy/keycloak-prod-standup-checklist.md follow-ups). Mirror kindredaccess-web
# (CONFIDENTIAL + PKCE, pairwise + audience) once BN's OIDC lands. This block stays INERT
# until you supply BN_REDIRECT_WEB — the exact callback path depends on the chosen library
# (mozilla-django-oidc → /oidc/callback/ ; allauth openid_connect → /accounts/oidc/<id>/login/callback/).
# =============================================================================
BN_CREATED=""
BN_REDIRECT_WEB="${BN_REDIRECT_WEB:-}"
if [[ -n "$BN_REDIRECT_WEB" ]]; then
  BN_POST_LOGOUT="${BN_POST_LOGOUT:-${BN_REDIRECT_WEB%/*}/*}"
  BN_CID=$("$KC" create clients -r "$REALM" \
    -s clientId=benefits-navigator-web \
    -s publicClient=false \
    -s standardFlowEnabled=true \
    -s implicitFlowEnabled=false \
    -s directAccessGrantsEnabled=false \
    -s 'attributes."pkce.code.challenge.method"=S256' \
    -s "redirectUris=[\"$BN_REDIRECT_WEB\"]" \
    -s "attributes.\"post.logout.redirect.uris\"=$BN_POST_LOGOUT" \
    -i)
  echo "created benefits-navigator-web client: $BN_CID"

  if [[ -n "${BN_CLIENT_SECRET:-}" ]]; then
    "$KC" update "clients/$BN_CID" -r "$REALM" -s "secret=$BN_CLIENT_SECRET" \
      && echo "set benefits-navigator-web secret from BN_CLIENT_SECRET"
  else
    "$KC" get "clients/$BN_CID/client-secret" -r "$REALM" \
      && echo "^ dev: set this as Benefits Navigator's OIDC client secret"
  fi

  "$KC" create "clients/$BN_CID/protocol-mappers/models" -r "$REALM" \
    -s name=pairwise-subject \
    -s protocol=openid-connect \
    -s protocolMapper=oidc-sha256-pairwise-sub-mapper \
    -s "config.\"pairwiseSubAlgorithmSalt\"=$BN_PAIRWISE_SALT" \
    -s 'config."id.token.claim"=true' \
    -s 'config."access.token.claim"=true' \
    || echo "pairwise mapper may already exist"

  "$KC" create "clients/$BN_CID/protocol-mappers/models" -r "$REALM" \
    -s name=benefits-navigator-web-audience \
    -s protocol=openid-connect \
    -s protocolMapper=oidc-audience-mapper \
    -s 'config."included.client.audience"=benefits-navigator-web' \
    -s 'config."access.token.claim"=true' \
    || echo "audience mapper may already exist"
  BN_CREATED=1
else
  echo "SKIP: benefits-navigator-web not created (BN_REDIRECT_WEB unset — BN still on django-allauth, no OIDC RP yet)"
fi

# -----------------------------------------------------------------------------
# GUARD (ADR-003). Every client MUST carry a pairwise-sub mapper, or its `sub` is the
# raw, correlatable user id — a platform-invariant breach. cit-web loses the mapper
# silently when CIT_SECTOR_URI is unset/unreachable (multi-host redirect). This turns
# that silent failure into a hard stop for anything real, and a loud warning in dev.
# -----------------------------------------------------------------------------
GUARD_CLIENTS=(cit-web kindredaccess-web access-atlas disability-wiki-web)
[[ -n "$BN_CREATED" ]] && GUARD_CLIENTS+=(benefits-navigator-web)
for c in "${GUARD_CLIENTS[@]}"; do
  ccid=$("$KC" get clients -r "$REALM" -q clientId="$c" --fields id --format csv --noquotes)
  if "$KC" get "clients/$ccid/protocol-mappers/models" -r "$REALM" --fields protocolMapper 2>/dev/null \
       | grep -q oidc-sha256-pairwise-sub-mapper; then
    echo "OK: $c has a pairwise-sub mapper (ADR-003)"
  elif [[ "$c" == "cit-web" && -z "$CIT_SECTOR_URI" ]]; then
    echo "WARNING: cit-web has NO pairwise-sub mapper — CIT_SECTOR_URI is unset, so its sub is" >&2
    echo "         NON-pairwise (correlatable). Acceptable for a THROWAWAY dev run only. Before" >&2
    echo "         prod, host a sector-identifier doc and set CIT_SECTOR_URI (see deploy runbook)." >&2
  else
    echo "FATAL: $c is MISSING its pairwise-sub mapper — ADR-003 breach." >&2
    [[ "$c" == "cit-web" ]] && echo "       CIT_SECTOR_URI is set but the mapper didn't land: the sector doc is unreachable or malformed." >&2
    exit 1
  fi
done

cat <<EOF

Done (reference run). Next:
  - Enable 2FA/step-up + apply the accessible login theme (hardening §5, §6).
  - Add a test user with a verified email.
  - Export the realm and commit it as the authoritative config (mount ./realm rw first):
      $KC get realms/$REALM -r $REALM > /opt/keycloak/data/import/bas-realm.json
  - Set CIT backend env: KEYCLOAK_ISSUER=<issuer>/realms/$REALM, KEYCLOAK_CLIENT_ID=cit-web
  - Set Access Atlas / Disability Wiki env: KEYCLOAK_ISSUER=<issuer>/realms/$REALM,
      KEYCLOAK_CLIENT_ID=access-atlas|disability-wiki-web, KEYCLOAK_REDIRECT_URI=<origin>/api/auth/callback
  - Set CIT native app env (bas-apps/apps/cit/.env):
      EXPO_PUBLIC_KEYCLOAK_ISSUER=<issuer>/realms/$REALM
      EXPO_PUBLIC_KEYCLOAK_CLIENT_ID=cit-web
      EXPO_PUBLIC_APP_SCHEME=com.beauaccesssolutions.cit
EOF
