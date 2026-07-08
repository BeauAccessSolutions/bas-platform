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
#     bash /opt/keycloak/data/import/realm/bootstrap.sh
set -euo pipefail

KC=/opt/keycloak/bin/kcadm.sh
REALM="${REALM:-bas}"
CIT_REDIRECT_WEB="${CIT_REDIRECT_WEB:-http://localhost:3000/api/auth/session*}"
CIT_REDIRECT_NATIVE="${CIT_REDIRECT_NATIVE:-com.beauaccesssolutions.cit://oauth*}" # Expo AppAuth scheme
ACCESS_TOKEN_LIFESPAN="${ACCESS_TOKEN_LIFESPAN:-300}"  # 5 min — short-lived identity token

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
"$KC" create "clients/$CID/protocol-mappers/models" -r "$REALM" \
  -s name=pairwise-subject \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-sha256-pairwise-sub-mapper \
  -s 'config."pairwiseSubAlgorithmSalt"=cit-sector-salt-dev' \
  -s 'config."id.token.claim"=true' \
  -s 'config."access.token.claim"=true' \
  || echo "pairwise mapper may already exist"

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

# Reveal the generated client secret (KindredAccess needs it as OIDC_RP_CLIENT_SECRET).
"$KC" get "clients/$KA_CID/client-secret" -r "$REALM" \
  && echo "^ set this as KindredAccess OIDC_RP_CLIENT_SECRET"

# Pairwise `sub` (ADR-003) — KA's sub never correlates with cit-web's.
# (see the cit-web mapper above for the provider-id / salt rationale)
"$KC" create "clients/$KA_CID/protocol-mappers/models" -r "$REALM" \
  -s name=pairwise-subject \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-sha256-pairwise-sub-mapper \
  -s 'config."pairwiseSubAlgorithmSalt"=ka-sector-salt-dev' \
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

cat <<EOF

Done (reference run). Next:
  - Enable 2FA/step-up + apply the accessible login theme (hardening §5, §6).
  - Add a test user with a verified email.
  - Export the realm and commit it as the authoritative config:
      $KC get realms/$REALM -r $REALM > /opt/keycloak/data/import/realm/bas-realm.json
  - Set CIT env: KEYCLOAK_ISSUER=<issuer>/realms/$REALM, KEYCLOAK_CLIENT_ID=cit-web
EOF
