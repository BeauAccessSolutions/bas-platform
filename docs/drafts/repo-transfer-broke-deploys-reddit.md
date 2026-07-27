# Draft — "A GitHub org transfer silently broke my production deploys for six months"

**Platform:** Reddit (r/devops or r/selfhosted) · **Status:** draft, not posted
**Angle:** war story + checklist. Genericized — no product details beyond "a Django app on a DO droplet."

---

I deployed to my production droplet last week for the first time in months and discovered
that every deploy since January had silently been impossible. Nothing errored. Nothing
alerted. The site just... stayed old.

The cause was a GitHub repo transfer from my personal account into an org, which broke
deployment in **three stacked ways**, each hiding behind the previous one:

1. **The droplet's `origin` still pointed at the old owner.** Git redirects fetches for
   *user* credentials, so local pushes kept working — but the server's deploy key is
   repo-scoped, and scoped credentials don't follow redirects. `ERROR: Repository not found.`
2. **The transfer auto-disabled the deploy key.** Here's the cruel part: a disabled key
   still *authenticates*. `ssh -T git@github.com` cheerfully greeted `Hi org/repo!` while
   every fetch 404'd. That contradiction — greeting works, fetch says the repo doesn't
   exist — is the diagnostic signature. Check `gh api repos/ORG/REPO/keys` and look for
   `"enabled": false`.
3. **The org itself had deploy keys switched off** (`deploy_keys_enabled_for_repositories:
   false` — visible via `gh api orgs/ORG`). Re-adding the key just bounced with
   "Deploy keys are disabled for this repository" until the org toggle flipped.

Fix, in order: re-point origin → enable the org toggle → delete + re-add the same public
key (read-only this time — a deploy pull never needs push).

The checklist I wish I'd had — **after any repo transfer or rename, audit every machine
credential, not just the webhooks:**
- [ ] CI/CD host's GitHub App re-authorized for the new owner (Netlify/Vercel/DO App Platform all break here)
- [ ] Every server's `git remote -v` re-pointed
- [ ] Deploy keys: still `enabled: true`? Org policy still allows them?
- [ ] Force one deploy and verify a string only the new commit contains — a green push proves nothing

This was my org's *fourth* transfer-related deploy breakage across different hosts
(Netlify GitHub App ×1, DO App Platform webhook ×2, now SSH deploy key). Same root cause
every time: integrations bind to the *owner*, and transfers only migrate what Git itself
sees.
