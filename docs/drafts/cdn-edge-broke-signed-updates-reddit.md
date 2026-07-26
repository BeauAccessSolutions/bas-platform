# Draft — "Cloudflare's edge quietly killed our signed update channel, and every test surface lied about it"

**Platform:** Reddit (r/webdev, r/CloudFlare, or r/devops) · **Status:** draft, not posted
**Angle:** debugging war story + a testing lesson. Genericized — "a static site plus an
offline-first mobile app", no product details beyond that it ships safety information.

---

We ship a static site plus an offline-first iOS app. Because the app bundles emergency
phone numbers, we built a signed over-the-air content channel: if a number changes, the
fix reaches installed apps without waiting on App Review.

The design is boring on purpose. The site build emits a manifest — the sha256 of every
content file — plus a detached ed25519 signature. The app fetches both, verifies the
signature against a public key compiled into the binary, downloads only the files whose
hashes changed, checks each one against the hash in the *signed* manifest, stages a
complete new content root, and activates it on the next launch. Nothing unsigned gets in.

It had never worked. Not once, on any device, since the day it shipped.

## The symptom

The in-app status screen said:

```
Source: copy shipped with the app
Last update check: 10:09 AM (offline or unavailable)
```

The phone had wifi and cellular. The server was fine — manifest 200, signature verifying.

## The cause

**Cloudflare rewrites HTML at the edge.**

Two zone features do it, and neither is exotic. **Email Obfuscation** (Scrape Shield)
rewrites `mailto:` links into `/cdn-cgi/l/email-protection`. **Bot Fight Mode's
JavaScript Detections** injects a `__CF$cv$params` script into the response.

So the bytes our app received were never the bytes we hashed at build time. Every update
aborted on the first HTML file it tried to verify — and since a content fix *is* an HTML
change, the channel was dead for precisely the thing it existed to deliver.

Measured against production: **5 of 5** HTML files in the pending delta mismatched.
**77 of 77** non-HTML files matched. The transformation is content-type-driven.

## Why nobody caught it

This is the part worth internalizing.

We had an end-to-end test. It passed. It ran against `wrangler pages dev`, which serves
origin bytes with none of the edge features on.

Fine — so test against a deployed URL instead. We did that too, later. **The `*.pages.dev`
preview deployment doesn't rewrite either.** The zone settings attach to the *custom
domain*. Same commit, three surfaces:

| Surface | Injects `__CF$cv$params`? |
|---|---|
| `wrangler pages dev` / static server | no |
| `https://<branch>.myproject.pages.dev` | **no** |
| `https://myproject.com` | **yes** |

Three plausible places to test. Only one tells the truth. If you hash, sign, or checksum
anything you fetch — SRI, signed update manifests, cache integrity, golden-file tests —
verify against the production hostname or you have verified nothing.

## The fix

We could have turned the zone settings off. We didn't: that leaves a critical path hostage
to a dashboard toggle nobody would connect to the breakage months later.

Instead we publish every file a second time as a content-addressed blob store —
`/ota/blobs/<first-2-hex>/<sha256>`, no extension, pinned in `_headers` to
`Content-Type: application/octet-stream`. The rewriters are content-type-driven, so blobs
sit outside every HTML transform, including whatever ships next. The manifest gained a
schema bump carrying the blob path, and clients now *refuse* a manifest without one rather
than silently falling back to the corruptible path.

Nice side effects: content-addressing makes blobs immutable, so they cache forever and the
host re-uploads only the delta. On disk they're hard links, so the duplicate tree costs
nothing. And two files that were in the manifest but had always 404'd — `_headers` and
`_redirects`, which Pages consumes as config — became fetchable for the first time.

## The second bug, which is really the first one

Every distinct failure — no network, server down, signature rejected, hash mismatch, disk
full — rendered as one string: *"offline or unavailable."*

That's why a permanently broken update channel looked like a phone with bad signal for two
days. The status screen now names the actual outcome and carries a technical detail line.

Our post-merge CI probe had the same disease. It verified the live manifest was fresh
**and signed**, went green every deploy, and proved nothing about whether a client could
apply an update. It now pulls real pages through the real edge and compares hashes.

**A valid signature is not a working channel.** Test the thing you actually depend on,
against the surface your users actually hit.
