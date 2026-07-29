# BAS-Platform Cross-App Lessons

**What this is:** transferable mistakes and hard-won lessons that recur **across Beau Access
Solutions apps** but nowhere else — the shared `packages/ui` design system, the Keycloak login
theme + OIDC integration, the §4 accessibility spine, the Django backends, native wrappers, and
cross-app safety conventions. `@import`ed only by BAS app repos' `CLAUDE.md` (alongside the
machine-wide `~/.claude/shared/LESSONS.md`).

**Scope rule:** a lesson belongs here only if *another BAS app would make the same mistake* and
a non-BAS project would not. Truly universal lessons go in `~/.claude/shared/LESSONS.md`;
single-app facts go in that app's own `CLAUDE.md` or memory.

**Budget: ~95 entry-lines** (header + generated index sit on top). It was "~1 page / ~85" while
only four repos imported this file; as of 2026-07-29 **eight** do — a11y-probe, Access Atlas
(`access-directory/`), bas-website (`beau-access-solutions/`), BN, CIT, Disability Wiki,
KindredAccess, page-repair — and it absorbed the BAS-only Django / native-wrapper / DO-hosting
clusters that were taxing all 19 repos from the machine-wide file. **That intake was paid for by
pruning, not by raising a ceiling: the file did not grow** (96 → 96 entry-lines, 8 → 15 entries).
The real gate is `~/.claude/hooks/pre-commit-lessons-nogrowth.sh` — no commit may grow a LESSONS.md,
at any size. After any change run `python3 ~/.claude/skills/prune-lessons/build_index.py LESSONS.md`;
the index below is **generated — never hand-edit it**.

**Governing doc:** [`docs/design-principles.md`](docs/design-principles.md) — the UX/a11y standard
these lessons defend. When a lesson hardens into a reusable primitive, graduate it into
`packages/ui` and cite it in §4 rather than leaving it as prose here.

Format per entry: **Lesson** — what broke → the fix. `(source-app, YYYY-MM-DD)`

---

<!-- INDEX:START -->
## Index — every lesson in one line

*`[G]` enforced machine-wide (entry is just a pointer) · `[T]` regression-tested in one repo (rule still applies elsewhere) · `[!]` a sub-claim is still unguarded.*

**Accessibility spine & shared UI**
- New native *code* needs a build; new *assets* do not
- C1 — how it broke, twice
- C2 — how it broke
- C3 — how it broke
- C4 — a token-hex contrast sweep has three blind spots

**Django backends (BN + KindredAccess)**
- Django ModelForm validation mutates the passed instance in place `[T]`
- Django's test `Client` in `manage.py shell` 400s on everything unless you pass a host in ALLO…
- Django's `{{ x|default:y.z }}` 500s instead of falling back when `y` is `None` `[T]`
- A fix that makes a configured backend "actually apply" applies in *every* environment — inclu… `[G]`

**Identity, OIDC, native wrappers & hosting**
- Changing the shared IdP host silently strands every native wrapper — and each wrapper tech hi…
- BAS realm client IDs are NOT uniformly suffixed — infer one and you'll wire an app to a clien…
- iOS safe-area CSS is doubly inert by default — and `env()` padding can't fix a scrolled overlap
- Webview-wrapper bugs share one signature: "works in a browser, broken only on-device" — a web…
- iOS TestFlight uploads from this Mac: archive UNSIGNED, sign at export — and only App Store C…
- Guessing DNS names is not a domain inventory — read the hosting platform's own config (`doctl…

<!-- INDEX:END -->

## Accessibility spine & shared UI

**Read [`docs/design-principles.md` §4.1](docs/design-principles.md) first** — it holds the four
normative contracts C1–C4 *and* the per-app gate inventory (which app is enforced, partial, or
unenforced, with test paths). That inventory used to be duplicated here; §4.1's is sharper and stays
current, so it was deduped out on 2026-07-29. What's kept below is what §4.1 can't hold: **how each
contract actually broke**, and the sweep techniques no contract row covers.

- **New native *code* needs a build; new *assets* do not.** Adding `@expo/vector-icons` to CIT/Baseline
  I asserted — in a PR body, the remediation tracker and project memory — that the tab icons could only
  reach TestFlight via an EAS build because they ship a `.ttf`. False: `expo` already depended on
  `expo-font` before the change, so the native module was in the shipped build and `expo-updates`
  delivers assets; everything pending went out over the air. → Check the needed native module is already
  shipped (`git show <pre-change-ref>:pnpm-lock.yaml | grep <module>`), and verify the publish from
  `dist/assetmap.json`, not the CLI: `eas update` prints "Uploading assets skipped - no new assets found"
  when it has merely seen those hashes, which reads exactly like an omitted asset. (bas-apps/CIT, 2026-07-27)

- **C1 — how it broke, twice.** page-repair routed labeling errors, extension errors and clipboard
  failures through the same polite `role="status"` region as the success summary, so a failure queued
  behind the user's current utterance or was missed entirely (SC 4.1.3). Then, in CIT: **fix the shared
  primitive, not just the instances.** `SymptomForm` and `CheckInForm` had been hand-fixed while
  `ApiForm` — the primitive **8 other entry forms delegate to** — still rendered its region conditionally
  and routed success + failure through one polite node, so the defect read as "known and fixed" while
  most surfaces still failed silently. → When a spine fix lands on a hand-written component, grep for the
  shared form/status primitive and check it has the same shape. (page-repair + CIT, 2026-07-13/19)

- **C2 — how it broke.** BN's assistant re-announced its response region on every streamed token
  (machine-gunning the screen reader), and the assertive *error* announce left focus stranded on the
  now-removed "Stop generating" button. The gate only became possible once the inline template script
  was **extracted** to `static/js/assistant.js` — an inline `<script>` is untestable. ⚠️ And BN's pytest
  run **excludes** `tests/e2e`, so a Playwright test parked there gates nothing. (benefits-navigator, 2026-07-13)

- **C3 — how it broke.** KindredAccess added a single `ChatStatusAnnouncer` but left
  `role="status"`/`aria-live` on the visible typing/connection/presence nodes, so every change was read
  twice — the design review caught the *spec* reproducing the very double-read it set out to kill. Same
  trap for a `role="log"` transcript that already voices incoming messages. Note KA's gate is a regex
  over three named node ids: blind to a fourth indicator, nested regions, or `role="log"`. (kindredaccess, 2026-07-13)

- **C4 — a token-hex contrast sweep has three blind spots.** page-repair's options page declared no
  `color-scheme` at all, so its dark theme was never verified; but even a token sweep misses three
  things, all found on bas-website and now gated by its `test/contrast.mjs` (both themes, wired into the
  build command so a regression can't publish): (a) a token *used but never defined* emits no CSS and
  fails silently — scan that every `text-|bg-|border-<family>-<step>` resolves to a `--color-` var; (b)
  `/opacity` backgrounds are distinct pairs — alpha-composite before comparing (body text was clean on
  white, 3.93:1 on a 30% tint); (c) a sweep only checks pairs someone listed, so a second theme audits
  the *pair list itself* — dark mode surfaced a light-theme logo failure two prior sweeps had missed.
  Corollary: **half a theme is worse than none** — migrate raw `text-gray-*`/`bg-white` to a semantic
  layer (canvas/surface/ink/…/on-accent) first, or dark mode leaves half the page light; `text-white` on a
  button is the killer (in dark the accent lightens, its label must go near-black). (bas-website, 2026-07-13/19)

## Django backends (BN + KindredAccess)

Both BAS Django apps repeat each other's mistakes, and no non-BAS project on this machine runs Django —
so these sat in the machine-wide file taxing 19 repos for nothing. Relocated 2026-07-29.

- **Django ModelForm validation mutates the passed instance in place.** Reading "old" values *after*
  `form.is_valid()` sees the new values, so `if old != new` branches silently never fire (availability
  history + match notifications were dead code). → Capture prior values *before* binding, and test the
  change-detection branch, not just the save. *Tested:* KA `test_views.py::StatusChangeNotificationTest`.
  (kindredaccess, 2026-07-13)

- **Django's test `Client` in `manage.py shell` 400s on everything unless you pass a host in
  ALLOWED_HOSTS.** `testserver` is auto-added by the *test runner's* setup, not a plain shell — so a
  uniform 400 reads as "the whole page is broken" and sends you hunting a template/view bug. → Pass
  `SERVER_NAME="localhost"` to the Client and each request, or drive it under the test runner. (BN, 2026-07-13)

- **Django's `{{ x|default:y.z }}` 500s instead of falling back when `y` is `None`.**
  `FilterExpression.resolve()` guards the *primary* variable but resolves filter **arguments** with a
  bare `arg.resolve(context)`, so the exception propagates uncaught — it reached 3 templates before
  anyone caught it. → Never chain `|default:some.nullable.attr.chain`; guard with `{% if %}` or
  precompute in the view. *Tested:* include a null-FK case in template render tests. (BN, 2026-07-22)

- **A fix that makes a configured backend "actually apply" applies in *every* environment — including
  tests.** Moving Django's staticfiles backend into `STORAGES` activated whitenoise's manifest storage,
  which resolves `{% static %}` through a manifest test runs lack → every page-render test 500'd, reading
  like a view bug. → When enabling a previously-inert setting, enumerate the environments it now reaches
  ("configured" ≠ "exercised"); fix by satisfying the requirement, not disabling it untested.
  *Gate graduated:* BN `Dockerfile.prod` + `core/tests.py`. (benefits-navigator, 2026-07-23/24)

## Identity, OIDC, native wrappers & hosting

- **Changing the shared IdP host silently strands every native wrapper — and each wrapper tech hides
  the host in a different place.** Migrating Keycloak to `id.beauaccesssolutions.com` was a one-line env
  change for the web apps, but three native surfaces had the old host baked in and would have bounced
  in-app login to Safari or blocked it: Access Atlas's Capacitor `server.allowNavigation`; KindredAccess
  with **no** `allowNavigation` *and* `WKAppBoundDomains` locked to its own domain under
  `limitsNavigationsToAppBoundDomains: true`; and CIT/Baseline baking `EXPO_PUBLIC_KEYCLOAK_ISSUER` into
  `eas.json` at **build** time. A green web `/oidc/…` redirect proves nothing about any of them. → Treat
  any issuer change as a **native release**: enumerate every wrapper in the same change, and keep the OLD
  host serving until the replacement builds ship. (bas-platform, 2026-07-17)

- **BAS realm client IDs are NOT uniformly suffixed — infer one and you'll wire an app to a client that
  doesn't exist.** The `bas` realm holds `cit-web`, `kindredaccess-web`, `benefits-navigator-web`,
  `disability-wiki-web` … but `access-atlas` (bare). Setting Disability Wiki's id to `disability-wiki` by
  analogy pointed it at a nonexistent client: configured-looking, failing only at login. → Verify against
  the realm, no admin creds needed: GET the authorize endpoint with the candidate id and **read the HTTP
  status, not the page body** — `302` = exists; `400` + "Invalid parameter: redirect_uri" = exists but
  that redirect isn't registered; `400` + "Client not found" = wrong id. ⚠️ Never discriminate on the
  themed "Sign in to bas" heading — Keycloak's *error* page carries an identical `<title>`. (bas-platform, 2026-07-17)

- **iOS safe-area CSS is doubly inert by default — and `env()` padding can't fix a scrolled overlap.**
  All four BAS apps (Capacitor/PWA on iOS) rendered content under the notch/status bar. Two traps, both
  bit at once: (1) `env(safe-area-inset-*)` resolves to **0** unless the viewport meta carries
  `viewport-fit=cover` — so KindredAccess's *existing* inset rules were already dead no-ops; (2)
  `padding-top: env()` on the body/scroll container **scrolls away** with the content, so only a
  `position:fixed` backdrop strip (or a `sticky` header padded with the inset) stays put over that zone.
  → Non-sticky header: `viewport-fit=cover` + a fixed `body::before` strip in the header colour. Sticky
  header (CIT): pad the header — a fixed strip would clip it. Mind the CSP: BN's `style-src 'self'` forced
  a linked stylesheet. All inert on desktop (`env()`=0) → **verify on a real notched device**. (bas-platform, 2026-07-24)

- **Webview-wrapper bugs share one signature: "works in a browser, broken only on-device" — a web QA
  pass can never catch them.** e.g. Capacitor's router answers any extensionless path with `/index.html`
  (directory links served HOME); `target="_blank"` leaves for Safari (session URL → login); a file input
  with no `NSCameraUsageDescription` lets iOS terminate the app. → Read the framework's source, don't
  guess. Checklist: [`docs/webview-wrapper-traps.md`](docs/webview-wrapper-traps.md). (disability-wiki + BN, 2026-07-18)

- **iOS TestFlight uploads from this Mac: archive UNSIGNED, sign at export — and only App Store
  Connect knows the real build number.** Zero registered devices → a normal archive fails "no devices";
  archive `CODE_SIGNING_ALLOWED=NO`, `-exportArchive -allowProvisioningUpdates`, bump the build past
  ASC's not local state. Runbook: [`docs/mobile-and-testflight.md`](docs/mobile-and-testflight.md). (bas-platform, 2026-07-18)

- **Guessing DNS names is not a domain inventory — read the hosting platform's own config (`doctl apps
  spec get` → `domains:`).** "BN has no prod domain" was wrong: `vabenefitsnavigator.org` was PRIMARY in
  the spec, and an iOS wrapper shipped baked to the `ondigitalocean.app` URL where Keycloak registers no
  callback, dead-ending login. → Enumerate from the platform's spec/API; grep the *whole* spec. (bas-platform, 2026-07-18)
