#!/usr/bin/env bash
# Real platform status — reads the actual state of every app repo under repos/
# rather than trusting the hand-maintained TRACKER.md. Pure read-only.
#
# Usage:
#   scripts/platform-status.sh            # human-readable report
#   scripts/platform-status.sh --json     # machine-readable (one JSON object per app)
#   scripts/platform-status.sh --no-fetch # skip `git fetch` (faster, may be stale)
#   scripts/platform-status.sh --no-net   # skip fetch AND deploy health probes
#
# Exit code is always 0; "problems" are reported in the output, not the status.

set -uo pipefail

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOS="$HUB/repos"

JSON=0; DO_FETCH=1; DO_NET=1
for a in "$@"; do
  case "$a" in
    --json) JSON=1 ;;
    --no-fetch) DO_FETCH=0 ;;
    --no-net) DO_FETCH=0; DO_NET=0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

# Known live deploy endpoints -> health-check URL. Extend as apps go live.
# (case-based so it works on macOS's stock bash 3.2, which lacks `declare -A`.)
# NOTE: the CIT / Access Atlas / KindredAccess URLs below are ALSO what the iOS
# TestFlight builds load or call — see TRACKER.md §2b and docs/mobile-and-testflight.md.
health_url() {
  case "$1" in
    chronic-illness-tracker) echo "https://chronic-illness-tracker-7o7fw.ondigitalocean.app" ;;
    access-directory)   echo "https://access-atlas-qd464.ondigitalocean.app" ;;
    kindredaccess)      echo "https://kindredaccess.org" ;;
    benefits-navigator) echo "https://benefits-navigator-staging-3o4rq.ondigitalocean.app" ;;
    page-repair)        echo "https://page-repair-proxy.airboat-webcast-5u.workers.dev" ;;
    *) echo "" ;;
  esac
}

# Infra endpoints that aren't app repos under repos/ but are worth a health line.
# Probed once at the end of the run (see the INFRA loop).
infra_endpoints() {
  cat <<'EOF'
keycloak-prod https://id.kindredaccess.org/realms/bas
EOF
}

slug() { # git remote url -> owner/repo
  sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##' <<<"$1"
}

health_probe() {
  local url="$1"
  [ "$DO_NET" -eq 1 ] || { echo "skipped"; return; }
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$url" 2>/dev/null)
  echo "${code:-000}"
}

emit_json() { # app-name ; then key=val pairs already JSON-escaped by caller
  printf '%s' "$1"
}

apps=()
for p in "$REPOS"/*; do
  [ -e "$p" ] && apps+=("$(basename "$p")")
done

[ "$JSON" -eq 1 ] || {
  echo "# Platform status — real state ($(date '+%Y-%m-%d %H:%M'))"
  echo "# hub: $HUB"
  echo
}

for app in "${apps[@]}"; do
  p="$REPOS/$app"
  root=$(git -C "$p" rev-parse --show-toplevel 2>/dev/null)

  if [ -z "$root" ]; then
    if [ "$JSON" -eq 1 ]; then
      printf '{"app":"%s","git":false}\n' "$app"
    else
      printf '## %-24s  (not a git repo)\n\n' "$app"
    fi
    continue
  fi

  [ "$DO_FETCH" -eq 1 ] && git -C "$p" fetch --quiet --prune 2>/dev/null

  branch=$(git -C "$p" rev-parse --abbrev-ref HEAD 2>/dev/null)
  dirty=$(git -C "$p" status --porcelain 2>/dev/null | grep -c . )
  last=$(git -C "$p" log -1 --format='%h · %cr · %s' 2>/dev/null)

  # Collect every GitHub remote (repos often have >1: a new origin plus an
  # old/upstream). Querying only `origin` misses PRs on the canonical repo.
  slugs=""
  for r in $(git -C "$p" remote 2>/dev/null); do
    u=$(git -C "$p" remote get-url "$r" 2>/dev/null)
    case "$u" in *github.com*) : ;; *) continue ;; esac
    s=$(slug "$u")
    case " $slugs " in *" $s "*) ;; *) slugs="$slugs $s" ;; esac
  done
  slugs=$(echo $slugs | xargs 2>/dev/null)
  repo_slug=$(echo "$slugs" | tr ' ' ',')

  pushed="no"; ahead="?"; behind="?"; prs="[]"; prcount=0
  if [ -n "$slugs" ]; then
    # is the current branch on any remote?
    for r in $(git -C "$p" remote 2>/dev/null); do
      if [ -n "$(git -C "$p" ls-remote --heads "$r" "$branch" 2>/dev/null)" ]; then
        pushed="yes"; break
      fi
    done
    # ahead/behind current branch vs origin/main (falls back silently if absent)
    if git -C "$p" rev-parse --verify -q origin/main >/dev/null 2>&1; then
      read -r behind ahead < <(git -C "$p" rev-list --left-right --count origin/main...HEAD 2>/dev/null || echo "? ?")
    fi
    # open PRs across every remote, each tagged with its repo slug
    if command -v gh >/dev/null 2>&1; then
      lines=""
      for s in $slugs; do
        out=$(gh pr list -R "$s" --state open \
                --json number,title,headRefName \
                -q ".[] | {repo:\"$s\",number,headRefName,title} | @json" 2>/dev/null)
        [ -n "$out" ] && lines="$lines$out"$'\n'
      done
      prcount=$(printf '%s' "$lines" | grep -c . )
      if [ "$prcount" -gt 0 ]; then
        prs=$(printf '%s\n' "$lines" | grep . | paste -sd, - | sed 's/^/[/; s/$/]/')
      fi
    fi
  fi

  health="n/a"
  hurl="$(health_url "$app")"
  if [ -n "$hurl" ]; then
    health="$(health_probe "$hurl") $hurl"
  fi

  if [ "$JSON" -eq 1 ]; then
    # compact JSON line per app
    printf '{"app":"%s","git":true,"branch":"%s","dirty":%s,"repo":"%s","pushed":"%s","ahead":"%s","behind":"%s","open_prs":%s,"health":"%s","last":%s,"prs":%s}\n' \
      "$app" "$branch" "${dirty:-0}" "$repo_slug" "$pushed" "$ahead" "$behind" \
      "${prcount:-0}" "${health%% *}" \
      "$(printf '%s' "$last" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""')" \
      "$prs"
  else
    printf '## %s\n' "$app"
    printf '   repo      : %s\n' "${repo_slug:-<no remote>}"
    printf '   branch    : %s  (pushed: %s)\n' "$branch" "$pushed"
    if [ "$ahead" != "?" ]; then
      printf '   vs main   : %s ahead, %s behind origin/main\n' "$ahead" "$behind"
    fi
    printf '   worktree  : %s uncommitted change(s)\n' "${dirty:-0}"
    printf '   last      : %s\n' "$last"
    printf '   open PRs  : %s\n' "$prcount"
    if [ "$prcount" -gt 0 ] && command -v python3 >/dev/null 2>&1; then
      python3 - "$prs" <<'PY' 2>/dev/null
import json,sys
for pr in json.loads(sys.argv[1]):
    print(f"               {pr.get('repo','?')}#{pr['number']} [{pr['headRefName']}] {pr['title']}")
PY
    fi
    [ "$health" != "n/a" ] && printf '   deploy    : HTTP %s\n' "$health"
    echo
  fi
done

# Infra endpoints that aren't app repos under repos/ (Keycloak prod, etc.).
# Human output only; JSON consumers get the per-app lines above.
if [ "$JSON" -ne 1 ]; then
  printf '## infra\n'
  infra_endpoints | while read -r name url; do
    [ -n "$name" ] || continue
    printf '   %-14s: HTTP %s %s\n' "$name" "$(health_probe "$url")" "$url"
  done
  echo
fi
