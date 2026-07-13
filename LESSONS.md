# BAS-Platform Cross-App Lessons

**What this is:** transferable mistakes and hard-won lessons that recur **across Beau Access
Solutions apps** but nowhere else — the shared `packages/ui` design system, the Keycloak login
theme + OIDC integration, the §4 accessibility spine, mobile-wrapper patterns, and cross-app
safety conventions. `@import`ed only by BAS app repos' `CLAUDE.md` (alongside the machine-wide
`~/.claude/shared/LESSONS.md`).

**Scope rule:** a lesson belongs here only if *another BAS app would make the same mistake* and
a non-BAS project would not. Truly universal lessons go in `~/.claude/shared/LESSONS.md`;
single-app facts go in that app's own `CLAUDE.md` or memory. Prune if this grows past ~1 screen.

**Governing doc:** [`docs/design-principles.md`](docs/design-principles.md) — the UX/a11y standard
these lessons defend. When a lesson hardens into a reusable primitive, graduate it into
`packages/ui` and cite it in §4 rather than leaving it as prose here.

Format per entry: **Lesson** — what broke → the fix. `(source-app, YYYY-MM-DD)`

---

## Accessibility spine & shared UI

- **One live region for all status announces failures as politely as successes — failures need
  their own assertive channel, warmed at injection.** page-repair routed labeling errors,
  extension errors, and clipboard failures through the same `aria-live="polite"` / `role="status"`
  region as the success summary; a polite failure queues behind the user's current utterance or is
  missed entirely if they've navigated on — exactly the SC 4.1.3 (Status Messages) case that must be
  assertive. → Keep a second `role="alert"` / `aria-live="assertive"` region and route only genuine
  failures to it (partial-progress like "labeled 40 of 60, run again" stays polite); **pre-create
  both regions before the first message** — a live region that enters the DOM in the same breath as
  its content mutates gets dropped by screen readers, so an alert region created only when the error
  fires may never speak. This is the §4 spine contract; every BAS app's dynamic-status surface has
  the same trap. (page-repair, 2026-07-13)

- **A UI with no `color-scheme` declaration has only been verified in the theme you happened to
  view — dark mode is untested by default, and the browser may auto-darken it unpredictably.**
  page-repair's options page set no colors and no `<meta name="color-scheme">`, so its contrast held
  in light but was unverified in dark; a `kbd` border at `#999` was already sub-3:1 (SC 1.4.11) even
  in light. design-principles.md §4 requires contrast verified in **both** themes. → Declare
  `color-scheme: light dark` (meta + `:root`), drive colors from tokens with a
  `@media (prefers-color-scheme: dark)` override, and verify every text (≥4.5:1) and UI-boundary
  (≥3:1) pair **numerically in both themes** with a luminance script — not by eyeballing one theme.
  Applies to any BAS surface with authored CSS (options pages, `packages/ui` components, the
  Keycloak theme). (page-repair, 2026-07-13)
