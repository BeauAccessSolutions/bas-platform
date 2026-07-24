# KindredAccess — first pass against the blocker suite

Date: 2026-07-23 · Matrix: [`multi-role-test-matrix.yaml`](multi-role-test-matrix.yaml) v1
Target: `repos/kindredaccess` @ `2a1aa8a` (`main`, matching the deployed `b5b6036` line)

**Method: static read of the code, not a live run.** Findings are anchored to file and line.
Tests needing a running instance, a device, or a screen reader were **not executed** and are
listed as not-run rather than passed.

KindredAccess is a different shape from Benefits Navigator — not caseload-scoped, so the
dual-hat half of `AUTHZ` largely doesn't apply. What it does have that BN doesn't:
real-time chat over Channels, a staff moderation surface with unrestricted media access, and
a deletion evidence hold. The audit weighted accordingly.

---

## Summary

| Test | Gate | Result |
|---|---|---|
| `AUTHZ-01` BOLA by object ID | blocker | **PASS** |
| `AUTHZ-11` derived artifacts scoped | blocker | **PASS** — media proxy fails closed |
| `TEN-06` storage paths scoped | blocker | **PASS** (fragility, F6) |
| `REV-01` double-submit → one record | blocker | **MOSTLY PASS** (F5) |
| `ERR-01` success only on server ack | blocker | **FAIL — F1** |
| `MOB-07` queued vs synced distinct | blocker | **FAIL — F1** |
| `AUDIT-01` views logged with role | blocker | **FAIL — F2** |
| `AUDIT-02` logs append-only | blocker | **FAIL — F2** |
| `AUDIT-03` elevated access logged | blocker | **FAIL — F2** |
| `SESS-05` absolute reauth timeout | required | **FAIL — F3** |
| `AUTHZ-12` uniform cross-scope denial | required | **FAIL — F4** |
| `DELEG-*` delegation/proxy | blocker | **N/A** — see the age note |

**One check I expected to fail and didn't.** `mysite/settings.py:258-266` has
`SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`, HSTS and `SECURE_SSL_REDIRECT` commented out
under "Uncomment these when deploying to production" — in an app that *is* in production.
They are all correctly set in [`mysite/settings_production.py:241-266`](../../repos/kindredaccess/mysite/settings_production.py), driven by env
with secure defaults. The commented block is dev-settings noise, not a finding. Worth deleting
so the next reader doesn't spend the same ten minutes.

Passes worth naming: every `Match` and `Message` lookup in [core/views.py](../../repos/kindredaccess/core/views.py) performs a
participant check after the fetch, and `Feedback` is scoped by `user=request.user` inside the
query itself. The media proxy blocks path traversal, **fails closed on unknown media types**,
and gates a not-yet-approved chat image to its sender alone — that last one is a subtle rule
implemented correctly.

---

## F1 — `ERR-01`/`MOB-07` blocker: a chat message can be destroyed silently

[`static/js/chat-websocket.js:277`](../../repos/kindredaccess/static/js/chat-websocket.js) and [`templates/chat.html:1032`](../../repos/kindredaccess/templates/chat.html)

```js
sendMessage(body, imageUrl = null, imageAltText = '') {
    if (!this.isConnected) {
        return this.sendMessageHttp(body, imageUrl, imageAltText);
    }
    ...
    this.socket.send(JSON.stringify(message));
}
```

```js
if (chat.isConnected && !imageInput.files.length) {
    chat.sendMessage(body, null, altText);
    // Clear form
    messageInput.value = '';
```

The send is fire-and-forget: no acknowledgment, no timeout, no retry, no pending state. And
the composer is **cleared before any acknowledgment**. Messages render only when they echo
back from the server (`onMessage`, guarded against duplicates by `data-message-id` — that part
is right).

The failure mode is a half-open socket, where `this.isConnected` is still true but the TCP
connection is dead. That is the ordinary case on mobile when a network changes from wifi to
cellular, and KindredAccess ships an iOS wrapper. `socket.send()` then buffers into
`bufferedAmount` and the data is discarded when the socket closes. The user sees their typed
text disappear from the composer, no message appears, and **no error is shown**.

This is worse than the "shows success for a write that never landed" case the matrix is
written against, because the composed text is not merely unacknowledged — it is gone. In an
app whose users may be composing something difficult, or reporting distress to a match, a
silently eaten message is a safety property, not a polish issue.

The fix is the standard chat shape: a client-generated message id, an optimistic render in a
visibly *pending* state, a server ack that promotes it to sent, and a timeout that surfaces
failure and offers retry. The `data-message-id` dedup on render already gives the reconciliation
half for free.

## F2 — `AUDIT-01`/`02`/`03` blocker: there is no audit log

There is no audit-trail model anywhere in the application. 39 `models.Model` subclasses across
`core/`, `matching/` and `mysite/` ([core/models.py](../../repos/kindredaccess/core/models.py) holds effectively all of them; `matching/`
declares none), not one of them an access or action log, and no `AuditLog`-shaped class or
reference anywhere in the repo.

This matters most where staff privilege is broadest. The media proxy grants staff unrestricted
access to two categories of private content:

- [`core/media_proxy.py:125`](../../repos/kindredaccess/core/media_proxy.py) — `if requesting_user.is_staff: return True` for **any** user's profile photo, explicitly including photos held under the deletion evidence hold.
- [`core/media_proxy.py:238`](../../repos/kindredaccess/core/media_proxy.py) — staff bypass the participant check for **any** chat image.

Both are deliberate and documented in the code, and both are defensible for a moderation
surface. But successful access writes nothing: the module logs only *denials*
(`logger.info("... access denied")`). There is no record of which moderator viewed which
user's photos or private chat images, when, or why.

Photo-moderation *decisions* are attributed — `reviewed_by` / `reviewed_at` on
`PhotoModerationQueue` ([core/models.py:244](../../repos/kindredaccess/core/models.py)). That is real and worth crediting, but it is
mutable current state on the row, not an append-only trail: a later reviewer overwrites it, it
covers approve/reject only, and it says nothing about views.

For an app that operates a deletion evidence hold and has a drafted NCMEC escalation path, the
gap is specific: an evidence hold with no access log preserves the evidence but not the chain
of custody over it. `AUDIT-05` (a review workflow with a named owner) and `AUDIT-06`
(retention floor) cannot even be evaluated, because there is nothing to review or retain.

Smallest useful first step is not a full audit subsystem: it is logging the two staff media
bypasses above, with actor, target user, media type, and timestamp, to an append-only table.

## F3 — `SESS-05` required: two-week sessions, no idle timeout

[`mysite/settings_production.py:251`](../../repos/kindredaccess/mysite/settings_production.py)

```python
SESSION_COOKIE_AGE = 1209600  # 2 weeks
```

No `SESSION_SAVE_EVERY_REQUEST`, no idle timeout, no absolute reauthentication bound. Against
the verified NIST SP 800-63B-4 figures, two weeks is roughly **14× the AAL2 SHOULD ceiling** of
24 hours, and about 1300× the P1 proposal of 15 minutes idle.

This is a decision, not automatically a defect. At AAL1 the ceiling is 30 days and two weeks is
compliant. The question is whether KindredAccess is AAL1 or AAL2, and the data argues AAL2:
disability status, private messages, photos, and safety reports naming other users. The
counter-argument is real too — this is a consumer social app where a 15-minute timeout would be
hostile, and for users with cognitive or motor disabilities, frequent re-authentication is its
own accessibility harm.

The matrix's own answer applies: a short timeout is only humane once drafts survive it, and
KindredAccess currently destroys in-flight text (F1). **Fix F1 before tightening F3** — in the
other order, the tightening makes the data loss more frequent.

## F4 — `AUTHZ-12` required: denials distinguish existing from nonexistent

Three call sites return a *distinguishable* response for an existing-but-forbidden object:

- [`core/views.py:1303`](../../repos/kindredaccess/core/views.py) `chat_view` — `get_object_or_404(Match, id=match_id)` then, on a participant-check failure, a redirect with "You don't have access to this chat." A nonexistent id 404s instead.
- [`core/views.py:1432`](../../repos/kindredaccess/core/views.py) `load_earlier_messages` — `JsonResponse({'error': 'Access denied'}, status=403)` versus 404.
- [`core/views.py:1772`](../../repos/kindredaccess/core/views.py) `flag_message` — "You can only flag messages sent to you."

The authorization itself is correct in all three; what leaks is existence. Iterating match ids
against `load_earlier_messages` cleanly separates real matches from unused ids. It does not
reveal who is in them, so severity is bounded — but on a platform where being matched at all is
sensitive, the population size and activity level of the service are inferable, and the fix is
to raise `Http404` on the authorization failure rather than a distinct response.

## F5 — `REV-01` medium: no idempotency on message creation

`REV-01` mostly passes, and by a legitimate route: `Like`, `Match`, `Block`, and `Profile` all
go through `get_or_create` on natural keys, and `Report` has an explicit
exact-duplicate fold window ([core/views.py:1520](../../repos/kindredaccess/core/views.py)) with a comment explaining the
reasoning. Natural keys are a valid alternative to idempotency tokens.

The gap is `create_message` ([core/consumers.py:553](../../repos/kindredaccess/core/consumers.py)), which has no natural key and no
dedup. A resend after a reconnect duplicates the message. Severity is low on its own — a
duplicate chat message is noise, not harm — but it is the same client-message-id that F1's fix
requires, so the two should be fixed together rather than separately.

## F6 — `TEN-06` low: media ownership is resolved by fuzzy suffix match

[`core/media_proxy.py:49`](../../repos/kindredaccess/core/media_proxy.py)

```python
filename = os.path.basename(file_path)
profile = Profile.objects.select_related('user').get(photo__endswith=filename)
```

Authorization is keyed on an `endswith` match while the file served is the literal requested
path — check one thing, serve another. `photo__endswith='1.jpg'` also matches a stored
`abc_1.jpg`.

**I tested whether this is exploitable as a cross-user leak and it is not.** To serve a
victim's file the requested path must be the victim's real path, and the victim's own row
always matches its own basename — so a suffix collision yields `MultipleObjectsReturned`
rather than the wrong owner. That exception is not in the narrow `except Profile.DoesNotExist`
clause, so it falls through to the outer `except Exception` and becomes a 404.

So the impact is availability and correctness, not disclosure: a filename collision makes a
legitimate photo permanently un-servable, and the broad `except Exception` at
[`core/media_proxy.py:281`](../../repos/kindredaccess/core/media_proxy.py) converts every internal error into "Media not found," which
would make that very bug hard to diagnose. Key on the stored path or a FileField lookup rather
than a basename suffix.

---

## The age posture is worth a decision

`DELEG` is marked N/A because KindredAccess has no proxy or guardian model — correctly, since
the app is 18+: a signup attestation ("I confirm that I am 18 years of age or older",
[core/forms.py:238](../../repos/kindredaccess/core/forms.py)) and `MinValueValidator(18)` on a user-entered
`Profile.age` integer ([core/models.py:549](../../repos/kindredaccess/core/models.py)). There is no date of birth stored and no
verification of any kind.

That leaves two postures in tension. The product asserts no minors are present. The safety
apparatus — the deletion evidence hold, the drafted NCMEC escalation runbook, the §2258A
preservation question in the counsel brief — is built on the assumption that minors may be
present, which is the correct assumption, because a self-attested checkbox is not an age check.

Both cannot be load-bearing. This does not change any test in this audit, but it is the kind of
thing that reads badly in an incident review, and it belongs alongside D1–D8 in the existing
counsel brief rather than in an engineering backlog. The matrix parameter it touches is **P5**,
which is already `pending_counsel`.

---

## Not run

`SESS-01`/`02`/`03` (draft survival, silent expiry, timeout warning), `SESS-10` (biometric
binding in the iOS wrapper), all of `MOB-01`…`MOB-06` (the revocation gap on a device, hardware-backed
key storage, predictive back), all of `A11Y`, `TEN-02` (cache cross-serve), `CONC-01`/`03`
(concurrent and offline edits), and `AUDIT-04`/`05`/`06` — the last three unevaluable until F2
gives them something to evaluate.

`MOB` deserves its own pass: KindredAccess is the portfolio's most safety-sensitive app *and*
ships a native wrapper, which is exactly the intersection the `MOB` suite was written for.

```bash
./scripts/testmatrix.py issues --repo BeauAccessSolutions/kindredaccess --gate blocker
```

Suggested order: **F1 first** — it is the only finding that destroys user data, it gates F3, and
it shares a fix with F5. Then F2's minimal version (log the two staff media bypasses). F4 and F6
are small and independent.
