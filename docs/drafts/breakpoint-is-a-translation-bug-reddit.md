# Draft — "Your responsive breakpoint is a localization bug waiting to happen"

**Platform:** Reddit (r/webdev or r/frontend) · **Status:** draft, not posted
**Angle:** short technical war story + a measurement method. Genericized — no product details
beyond "a health-tracking web app with a top nav bar."

---

I added a sign-out button to a nav bar this week and broke the header for every user between
768 and 878 pixels wide. That part is boring. The interesting part is what I found when I
measured it.

The bar held a wordmark, one emergency-action button, six destination links, and now sign-out.
Below 878px the labels wrapped onto two lines — "Sign / out", "Check- / in". Ugly, not fatal,
easy to miss because my laptop is 1440px and my phone test is 375px. The broken range sat in
between, where nobody looks.

So I measured where it actually broke. Two things went wrong before I got a number I could
trust.

**1. Shrinking a container does not simulate a narrow viewport.**

My first instinct was to avoid resizing the window: just clamp the bar's `max-width` and sweep
downward until nothing wraps. It reported the bar needed 924px.

The real answer was 808px. CSS media queries key off the *viewport*, not the element. At a
narrower container the layout was still rendering its wide variant — different wordmark,
different classes — so I was measuring a layout that never exists at that width. The sweep was
also silently clamped by the actual window size, so anything past it returned "never fits" for
a bar that fits fine at 1024.

Resize the real viewport. Then detect wrapping per element instead of squinting at screenshots:

```js
const r = document.createRange();
r.selectNodeContents(el);
const wrapped = r.getClientRects().length > 1;
```

One rect per line box. Cheap, exact, and it tells you *which* label broke rather than "the
header looks off."

**2. A threshold measured in English is not measured.**

Here's the one I didn't see coming. The same bar, same markup, same components, with the
Spanish string catalog: **~910px**, a hundred pixels worse. "Settings" is 8 characters;
"Configuración" is 13. "Sign out" is 8; "Cerrar sesión" is 13.

So a breakpoint chosen against English ships a broken bar in every other locale, and each
language you add moves the number again. My app hasn't even released Spanish yet — the catalog
exists as unreviewed placeholders — and it was already the constraint that mattered.

This reframes the fix. The obvious move is to shave padding until it fits, but the padding you
can remove is bounded by your minimum tap-target size (44px, and one of my links was already
at the floor), and it buys maybe 50px in the language you tested. It doesn't survive
translation. The fix has to be structural: collapse to a menu at a wider breakpoint.

**What I'd do differently, as a checklist:**

- Measure the wrap threshold in a browser, in your **longest** target language, not English.
- Resize the viewport; never simulate width by resizing a container.
- If your nav collapses to a hamburger, assert in a test that the toggle and the laid-out nav
  are exact complements (`lg:hidden` / `lg:flex`). Drift between them opens a width range with
  no way to reach anything, and nothing else catches it.
- Exempt your emergency path from the collapse. Mine is a one-tap "log a reaction now" button
  for people mid-allergic-reaction; ordinary destinations can cost an extra tap, that can't.
- Give translators a **length budget** in the brief instead of a bug report later. Mine now
  says: the six nav labels plus sign-out should total ~55 characters (English is 42, Spanish
  54), and if a natural translation doesn't fit, say so — we'll ship a short form, you don't
  invent an abbreviation nobody uses.

That last one is the part I'd most want to have known a year ago. Nav-label length is a layout
constraint that lives in a file translators never see, enforced by a breakpoint nobody wrote
down, and it fails in a language the person who chose the breakpoint doesn't read.
