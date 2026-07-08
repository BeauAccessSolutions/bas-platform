#!/usr/bin/env bash
# Generate the per-client secrets the prod realm needs, into identity/prod/secrets.env.
#
# These are SECRETS — secrets.env is gitignored and must never be committed. Copy it to
# the Keycloak host (chmod 600) and source it before running the realm bootstrap.
#
# ⚠️ IDEMPOTENT ON PURPOSE: if secrets.env already exists this script REFUSES to
#    overwrite it. The pairwise salts must be STABLE forever — regenerating them changes
#    every user's `sub` and orphans each app's stored identity rows. Rotate only with a
#    deliberate, planned data migration.
set -euo pipefail
cd "$(dirname "$0")"

OUT="secrets.env"
if [[ -e "$OUT" ]]; then
  echo "ERROR: $OUT already exists — refusing to overwrite (salts must stay stable)." >&2
  echo "Delete it manually only if you intend to rotate salts (a breaking migration)." >&2
  exit 1
fi

rand() { openssl rand -hex 32; }

cat > "$OUT" <<EOF
# BAS prod Keycloak secrets — generated $(date -u +%Y-%m-%dT%H:%M:%SZ). DO NOT COMMIT.
# Source before running the realm bootstrap against prod:  set -a; . secrets.env; set +a
#
# Pairwise-sub salts (ADR-003) — STABLE FOREVER, never rotate on a live realm.
CIT_PAIRWISE_SALT=$(rand)
KA_PAIRWISE_SALT=$(rand)
#
# KindredAccess confidential-client secret (OIDC_RP_CLIENT_SECRET on the KA side).
KA_CLIENT_SECRET=$(rand)
EOF

chmod 600 "$OUT"
echo "Wrote $OUT (chmod 600). Keep it off git and out of shared storage."
echo "Next: copy to the Keycloak host, then \`set -a; . secrets.env; set +a\` before the bootstrap."
