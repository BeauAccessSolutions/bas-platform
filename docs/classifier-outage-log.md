# Bash Safety-Classifier Outage Log

Passive instrument for diagnosing the recurring **auto-mode classifier unavailability**
that blocks `Bash` commands (typically at commit/push time). Set up 2026-07-20.

## What this is chasing

In auto permission mode, every `Bash` call is vetted by a safety-classifier model before it
runs. When that model's inference endpoint is unreachable, auto mode **fails closed** — the
command is refused with *"<model> is temporarily unavailable, so auto mode cannot determine
the safety of Bash"*. Read/Write/Edit are unaffected (they don't route through it).

**What a client-side log CAN answer:** whether outages correlate with our own session
load/timing (→ actionable: commit before heavy fan-out) or are random (→ retry-with-backoff
is the only lever).
**What it CANNOT answer:** the backend root cause. "Account throttled" and "provider
capacity blip" are indistinguishable from here — both are just a call that doesn't return.
Only the environment operator's logs separate those.

## Two failure modes — do NOT conflate them

| Mode | Looks like | Meaning | Log it here? |
|---|---|---|---|
| **Outage** | "*<model> is temporarily unavailable … cannot determine the safety*" | classifier infra is DOWN | **Yes** |
| **Denial** | "command was denied / not permitted" | classifier is UP and correctly refused a risky command | **No** — that's it working |

## Known sampling bias (why the pattern looks like "always at commit time")

This log only captures outages that **blocked something** — i.e. commits, pushes, deploy
polls. Nobody records "classifier was fine at 10am doing edits." So an apparent "only fails
at commit time" pattern is partly survivorship: commits are just when an outage first *hurts*
and gets noticed. Passive logging shows **when it hurts, not the true base rate**. Breaking
that bias would need an active idle-time heartbeat (declined 2026-07-20 as too costly).

## How to append (future sessions)

When a Bash call fails with the *temporarily-unavailable* error, add one row below. Record
the model named in the error (it varies — see data), what you were doing, retry count, and
whether/when it recovered.

## Data

| Date | Session context | Model in error | Activity when it hit | Retries | Recovered | Notes |
|---|---|---|---|---|---|---|
| 2026-07-19 | CIT lockfile drift | `claude-opus-4-8` | deploy-watch poll loop + commit | several | yes (self) | interrupted a production deploy poll |
| 2026-07-19 | marketing: contact form + dark mode | unrecorded | commit/push | several, ~min | yes | Monitor wait falsely reported "stopped"; commit had silently not landed |
| 2026-07-19 | gate scope + peer-push decision | unrecorded | commit (1-cmd) | 4 | yes | read-only tools kept working throughout |
| 2026-07-19 | marketing: caching + web-perf + style-eval | unrecorded | edits + commit | repeated | yes | Monitor wait falsely reported "stopped" again |
| 2026-07-20 | portfolio style-eval (8 apps) | `claude-sonnet-5[1m]` | commit/push at wrap-up | 3-4 | yes (user ran it) | followed ~8 parallel agents + 8 chips — highest-load session of the set |

## Reading so far (n=5, provisional)

- **All 5 clustered on 2 calendar days (4× on 2026-07-19, 1× on 2026-07-20)** — not evenly
  spread. Suggests bad-window bursts rather than a steady failure rate.
- **All 5 at commit/push or during a sustained poll loop** — but see sampling-bias note; this
  is not yet evidence the *cause* is commit-related.
- **Model name varies** (`opus-4-8`, `sonnet-5[1m]`) — argues against one specific flaky
  model, toward a shared/throttled inference tier that tracks the session's current model.
- **Two false "stopped" Monitor reports** during outages — the wait tooling misreports
  outage-stalls as completion, and commits silently don't land. Independent of the outage
  itself, but worth a fix: always `git log` to confirm a commit after any classifier stall.

Not enough yet to call load-vs-random. Need occurrences on days with *light* sessions (or
their absence) to test the "our own load causes it" hypothesis against the calendar.
