# Draft — "Cloudflare skipped my config file on every build for weeks and only one line anywhere said so"

**Platform:** Reddit (r/CloudFlare, or r/devops for the general lesson) · **Status:** draft, not posted
**Angle:** short war story about config that is *ignored* rather than *rejected*, and why duplicated
values make it invisible. Genericized — no product details beyond "a static site with a couple of
serverless functions."

---

I added a D1 database binding to a Cloudflare Pages project this week. Committed it to
`wrangler.jsonc`, bound it by database id, watched the deploy go green, and hit the endpoint.

503. "Not configured."

The binding was right there in the file. I checked the id against the dashboard's database list —
match. Checked the binding name against what the function reads — match. Redeployed, because
bindings only apply to new deployments. Still 503.

The config was correct. It had never been read.

## The one line that said so

Cloudflare Pages requires `pages_build_output_dir` in a wrangler config file. Mine didn't have it.
That is not an error. This is what the build log says, in the middle of an otherwise perfect build:

```
Found wrangler.json file. Reading build configuration...
A Wrangler configuration file was found but it does not appear to be valid.
Did you mean to use wrangler.toml to configure Pages? If so, then make sure the
file is valid and contains the `pages_build_output_dir` property.
Skipping file and continuing.
```

**Skipping file and continuing.** The build succeeds. The site deploys. Every setting in that file
is discarded, and the project silently falls back to the dashboard's values.

This had been happening on every single build since the day the file was added.

## Why nobody noticed for weeks

Here's the part I think is actually generalizable.

When someone "moves the config into version control," they usually add the values to the file and
leave the dashboard copies alone. That's what happened here — four environment variables, identical
in both places.

So it did not matter which source won. The site behaved exactly the same either way. There was no
symptom, no warning, and no way to tell from the outside which one was live. The setup was broken
and *indistinguishable from working* for as long as the two copies agreed.

It only broke when I added something that existed in exactly one of them. A binding lives in the
config file and nowhere else, so the moment I needed the file to be real, it wasn't.

## Four surfaces, one of them honest

What made this genuinely hard is that most of the things you'd naturally check agreed with the
wrong story:

- **The committed file** — looked correct, because it was correct. It just wasn't being read.
- **The dashboard**, which displayed a banner reading *"Environment variables for this project are
  being managed through wrangler.toml. Only Secrets can be managed here."* That banner appears when
  a config file is **detected**. Not when it's valid. It will confidently tell you a file Cloudflare
  is throwing away is in charge.
- **CI, green** — it built the site and ran the tests. It has no idea what the deployment received.
- **The build log** — the only place the skip is reported.

There's a fifth surface I wish I'd checked first: in the Pages dashboard, each deployment has a
**Functions** tab listing the bindings *that deployment actually got*. Mine showed an empty card.
Thirty seconds, and it would have told me the problem was upstream of anything I could fix by
editing the binding.

## The lesson I'm keeping

I had a rule written down from an earlier incident: "once a wrangler config file exists, Cloudflare
ignores dashboard-set variables." I'd inferred it from behavior. It was wrong — or rather, it was
conditional on something I didn't know was a condition, and I'd never seen the condition fail
because the duplicated values hid it.

So, two things:

**When config is ignored rather than rejected, every fix to its contents is a no-op.** If you've
corrected a config three times and nothing changed, stop editing it and go find out whether it's
being read at all. Loud failures teach you where to look; silent ones teach you nothing, so you keep
looking where the error isn't.

**Don't write down a precedence rule you inferred from behavior both sources would produce.** If
config A and dashboard B hold the same values, observing the expected result tells you nothing about
which one won. Change one of them, or find the log line. Otherwise you're writing documentation from
a coin flip — and mine got copied into two runbooks and a tooling description before anyone
questioned it.

The fix was one line. Finding it took reading a log I'd never had a reason to open.
