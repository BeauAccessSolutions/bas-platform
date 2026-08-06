# Draft — "Your error message is on screen and completely silent"

**Platform:** Reddit (r/accessibility, cross-post r/reactnative) · **Status:** draft, not posted
**Angle:** two adjacent gotchas, one per platform, that both produce a visible error no screen
reader ever announces. Genericized — no product details beyond "a health-tracking app."

---

I spent a day auditing error handling in a web app and its React Native sibling, and found the same
class of bug on both — an error message that renders perfectly and is never announced. The two
causes are completely different, which is what makes them worth writing down together.

## Web: the region has to exist before the text does

This looks correct, and it's what I found in fifteen places:

```jsx
{error && <p role="alert">{error}</p>}
```

The element and its content are created in the same commit. Several screen reader/browser pairs
don't announce that reliably — the live region has to be in the accessibility tree *before* the
text arrives, so there's something already being watched when it changes.

```jsx
<p role="alert" className="empty:hidden">{error}</p>
```

Same visual result (`:empty` keeps it out of the layout), completely different behaviour. The
region is mounted from first render; only its text changes.

The part that bit me: **auditing for `role="alert"` would have passed all fifteen.** The attribute
was right in every one. So if you're grepping a codebase for this, grep for the *shape* —
`{something && <... role="alert"` — not for the missing role.

## React Native: `accessibilityRole="alert"` doesn't speak

Same team, same reasoning, ported across:

```jsx
<Text accessibilityRole="alert">{error}</Text>
```

On React Native this marks a trait on the node. It does not announce anything, on either platform.
There's no live-region equivalent — announcing is an explicit call:

```js
AccessibilityInfo.announceForAccessibility(message)
```

Two details that matter once you start calling it:

- **Delay it.** An announcement made while a screen is unmounting or a navigation transition is
  running gets swallowed on iOS — and "save succeeded, now go back" is exactly that moment. A few
  hundred ms after the transition starts is the difference between hearing it and not.
- **Queue it on iOS.** `announceForAccessibilityWithOptions(msg, { queue: true })` stops a second
  announcement truncating the first, which happens the moment a save and an error land close
  together on a retry.

## Why the pair is the interesting bit

If you've done accessible web work, `role="alert"` is muscle memory, and porting it to RN produces
code that looks right to every reviewer who knows the web rule. The web version fails on *timing*.
The native version fails because the API doesn't do what the name implies. Neither shows up in a
visual review, neither shows up in a snapshot test, and both leave a user who can't see the screen
tapping Save and getting silence.

The tests worth writing are boring and specific: on web, assert the alert region is in the DOM
*before* anything goes wrong; on native, assert the announce call actually happened.

While I was there, axe caught something I'd never have found by reading: both email fields declared
`autocomplete="username email"`. That's not valid — the attribute takes one field name, not two
alternatives — so it was ignored and password managers had quietly stopped filling. Autofill is
WCAG 1.3.5, not a convenience, if your users are typing one-handed on a bad day.
