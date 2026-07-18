# Webview-wrapper trap checklist (Capacitor / WKWebView)

Every trap here is **invisible in a browser and only real on-device** — that's the
defining signature of this class, and why two of them shipped to TestFlight on
2026-07-18 before anyone noticed. Run this list before any new wrapper build.

Behaviour below is **read from Capacitor's iOS source**
(`@capacitor/ios/Capacitor/Capacitor/WebViewDelegationHandler.swift`, `Router.swift`),
not inferred — re-verify after a major Capacitor upgrade.

## The navigation decision (what actually happens to a tap)

`decidePolicyFor navigationAction` resolves in this order:

1. Plugin `shouldOverrideLoad:` gets first refusal.
2. Host in **`allowNavigation`** → allowed in-app.
3. Otherwise, if it's a **top-level** navigation **not** under `server.url`/`localURL`
   → `UIApplication.shared.open(url)` + `.cancel` — i.e. **kicked out to Safari**.
4. Anything else (subframes, same-origin) → allowed.

`target="_blank"` / `window.open` never reach that path: `WKUIDelegate
createWebViewWith` opens the URL via `UIApplication.shared.open` and returns `nil`
— **always Safari, always a new app switch.**

## Checklist

| # | Trap | Why it bites | Check |
|---|---|---|---|
| 1 | **SPA router assumption** | Default `CapacitorRouter` answers ANY extensionless path with root `index.html` — every link on a bundled MPA "works" but shows home | Bundled (`webDir`) multi-page site? Override `CAPBridgeViewController.router()`. **Hit DW 2026-07-18** |
| 2 | **Host not in `allowNavigation`** | OIDC/IdP hop, `www.` alias, or any second host bounces to Safari mid-flow — session often lost | List every host the app legitimately visits (IdP, `www.`, CDN). **Hit BN 2026-07-18** |
| 3 | **`www.` served directly** | If `www` doesn't 301 to apex, an absolute `www` URL leaves the allowed origin *and* splits host-scoped cookies | `curl -I https://www.<domain>/` — want `301` to apex, not `200` |
| 4 | **Session-protected URL behind `target="_blank"`** | Opens in Safari **without the app's cookies** → user sees a login page instead of their own file | Grep templates for `target="_blank"` on same-origin/auth'd URLs. Drop `_blank`, or route through an in-app view |
| 5 | **`<input type="file">` with no usage strings** | "Take Photo" needs `NSCameraUsageDescription`; missing → iOS kills the app | Any file/media input ⇒ add camera + photo-library strings to `Info.plist`. **Was missing in BN** |
| 6 | **`tel:` / `mailto:` / `sms:`** | Life-safety for crisis apps if broken | ✅ **Verified working from source**: no host ⇒ falls to step 3 ⇒ `UIApplication.shared.open` dials. Closes the DW spike's open question #2 |
| 7 | **Relative API paths in a bundled app** | `action="/api/x"` has no server inside the bundle — form dead-ends | Bundled apps: point forms at the absolute live origin, or hide them in-app |
| 8 | **Stale WKWebView cache** | Testers see old content after a web deploy and report it as a bug | Force-quit + reopen before believing a "content didn't update" report |

## Non-webview gates worth the same pass

- **Export compliance** — now permanently answered via `ITSAppUsesNonExemptEncryption=false`
  in every app's `Info.plist`/`app.json`; no per-build clicking.
- **Guideline 4.2 (minimum functionality)** — a bare URL wrapper fails *external*
  review; internal TestFlight (≤100 testers) is fine. Bundled-offline (DW) and
  native features are the arguments that clear it.
- **Guideline 5.1.1(v)** — an app offering account creation must offer in-app
  account **deletion**. Applies to BN, KA, CIT before any App Store release.
  ⬜ Not yet audited.

## Findings log

- **2026-07-18 audit** (all five apps): DW clean post-router-fix (its 545 absolute
  self-URLs are hreflang/OG metadata, not navigation); AA clean; Baseline N/A
  (native). BN: `www` allowlisted + media usage strings added; found the appeals
  document link 404 (raw `doc.file.url` with nothing serving `/media/`) — a *web*
  bug the wrapper merely surfaced, tracked separately. KA: `www` allowlisted
  (latent — no live `www` links), and note its live site exposes no IdP login yet.
