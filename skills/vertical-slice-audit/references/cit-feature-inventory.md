# CIT — parsed feature inventory (26 slices)

Source: produced by Codex in the CIT session, 2026-07-26, derived from `PROJECT_BRIEF.md`,
`docs/TARGET_STATE.md` and `docs/free-vs-paid.md` — i.e. this is a **Phase 1 intent inventory**, read
off the product docs, then annotated with implementation status. Priorities are release-gate
priorities, not effort estimates.

**Re-verify against code before trusting any line here** — it is a captured snapshot, not a live
read, and the status notes (`not yet native`, `planned`) were true only as of capture.

Repos: web `~/Chronic-Illness-Tracker` (Next.js app router + Prisma) · native
`~/projects/bas-apps/apps/cit` (Expo Router).

The universal 20-link lifecycle lives in `../SKILL.md` — apply it to every slice below. The checks
here are the slice-specific additions.

---

## 1. Account creation and identity — P0
- Sign-up opens the hosted identity flow; canceling returns to a usable screen.
- Email verification succeeds with a valid token; expired, reused and malformed tokens fail safely.
- Resending verification invalidates older links.
- Sign-in exchanges the identity token for a CIT session.
- Invalid issuer, audience, expiry or clock skew produces a useful, PHI-free error.
- An expired saved token triggers fresh authentication instead of looping.
- Repeated sign-in taps create at most one usable session.
- Existing local and platform accounts link correctly; session tokens stay in secure storage.
- Logout revokes the CIT session and clears credentials and drafts.
- Password change revokes other sessions; "log out other devices" preserves only the current one.
- Rate limiting blocks brute force without blocking legitimate use.
- Auth failures never reveal whether another person owns an email.

## 2. Onboarding — P1 (incomplete on native)
- New users reach onboarding after account creation; every step can be skipped.
- Confirmed / suspected / ruled-out conditions remain distinct.
- MCAS and other condition suggestions are recommendations, not requirements; accepting or
  rejecting produces the correct preferences.
- Food choices — yes / not now / ask later — remain distinct.
- Standing-regimen setup is optional and editable later.
- Logging-detail mode, locale and timezone persist.
- Refresh or restart does not lose completed state; Back does not duplicate diagnoses.
- Onboarding data appears correctly in settings and export.

## 3. Tracking preferences — P1
For food, energy, sleep, stress, cycle, exposures:
- Toggle state loads correctly; changes apply immediately; a failed save visibly reverts.
- Disabled dimensions disappear from logging surfaces; disabled endpoints reject creation or
  return the documented empty result.
- Disabling preserves historical entries; re-enabling restores access to them.
- No disabled dimension produces reminders or "incomplete" messaging.
- Changes propagate between web and mobile sessions.

## 4. Standing medication regimen — P0
- Reachable from settings and from an empty check-in.
- Name, dose, type, schedule accept valid input; autocomplete is optional and fills **only** the
  medication name — never dose or schedule.
- No medication text is sent to a third party while typing.
- Daily, BID, TID, weekly, PRN and custom schedules behave correctly; start/end dates timezone-safe.
- Editing dose or schedule creates a **new version**; historical dose events stay attached to the old.
- Pausing/discontinuing removes future slots without altering history.
- Duplicate submission does not create duplicate regimen items; PRN items never appear as scheduled
  daily doses.
- Regimen history appears completely in export.
- **Native gap:** editing, pausing and discontinuing are not yet fully exposed — audit explicitly.

## 5. Daily check-in — P0
- Today's active scheduled doses appear once each; changing the day loads that day's schedule and
  statuses; future-day navigation is appropriately limited.
- Untouched doses remain **unknown** through every layer.
- Taken / skipped / partial each selectable; re-tapping clears back to unknown, and clearing
  **deletes** the stored event rather than storing an inferred "unknown."
- Partial permits an optional amount override; skip reasons appear only when skipped; every quick
  reason and freeform "other" persists.
- A status can change later without creating conflicting rows.
- Bulk save is atomic or reports partial failure unambiguously; repeated save/retry is idempotent.
- No background process ever marks a dose taken.
- Check-in never displays adherence scores or completion pressure.
- Review and export distinguish taken / skipped / partial / unknown.
- Offline changes sync without overwriting a newer deliberate action.

## 6. Symptom logging — P0
- Opens from every intended entry point; name field accepts typing, paste and voice-to-text.
- Body-system selection uses only the current user's categories.
- Severity unset until deliberately selected; **0 and 10 both save**.
- Blood pressure, heart rate, temperature enforce sensible formats; notes and tags persist.
- Exact / hour / part-of-day / day-only precision all save; user timezone drives review grouping.
- Failed saves preserve every entered field; draft restores after navigation or app termination and
  clears after successful save, logout or expiry.
- Save creates exactly one record; review renders severity and notes correctly; filters find it.
- Export includes every structured and freeform field.
- Deleting removes tag **links** without deleting the tags.

## 7. Reaction now / acute capture — P0 · known suspected defect
- Home control reachable one-handed, one tap; modal presented before requesting keyboard focus;
  Cancel closes and returns focus to the trigger.
- **Field accepts continuous typing; every keystroke stays visible; keyboard does not dismiss after
  rerender; screen navigation options are not reconfigured on every character.** ← the suspected bug
- Save disabled only while the reaction name is empty.
- Timestamp captured when acute capture opens; save uses `isAcuteCapture=true`; exactly one record.
- Appears under the correct day and time; review distinguishes it as acute; export includes the flag.
- Network failure preserves the entered reaction **and** the original timestamp.
- Confirm the deliberate no-draft behavior does not cause unacceptable data loss.
- Passes VoiceOver/TalkBack and large-text testing.

## 8. PRN / rescue medication logging — P0
- Accepts medication, dose, reason, time; autocomplete optional and private.
- PRN events are **not** linked to scheduled regimen slots.
- Missing dose allowed if product rules say it is optional; retroactive and fuzzy time work.
- Draft restores and clears correctly; review includes dose and reason; export includes every field.
- Deleting a PRN event does not alter the standing regimen.

## 9. Freeform notes — P1
- Empty notes cannot be submitted; long notes stay usable within documented size limits.
- Newlines, punctuation, Unicode and voice dictation survive round-trip; draft preserves exact content.
- Appear in the unified timeline; tags add without duplicates; search/filtering behaves as designed.
- Export preserves content and timestamps; deletion removes the note and its tag joins.

## 10. Food tracking and barcode lookup — P1
- Absent entirely when tracking is disabled.
- Description accepts manual entry regardless of barcode availability; freshness,
  preparation-source and cross-contact notes persist; histamine-liberator defaults to false/unset.
- Barcode lookup requires authentication and goes to **CIT's same-origin endpoint**, never directly
  to OpenFoodFacts.
- Result fills only product name/brand — never infers freshness, cross-contact or histamine status.
- Invalid barcode, no match, timeout and upstream outage each fall back to typing.
- Barcode and result never enter logs.
- Turning food tracking off retains previously saved entries.

## 11. Exposure logging — P1 (not yet native)
- Preference gating works; type, intensity, location/context, notes persist; optional intensity
  stays unset until touched; fuzzy and retroactive time work.
- Appears in review, filters and export; disabling tracking preserves records.

## 12. Energy and pacing — P1 (not yet native)
- Energy level validates its documented range; **spoon count supports zero**; PEM flag is a
  deliberate selection.
- Entries group under the correct local day; review, comparison, export and deletion work.
- No energy score becomes judgmental messaging.

## 13. Sleep — P1 (not yet native)
- Date, duration, quality, wake-ups validate; **zero wake-ups is preserved, not treated as missing**;
  optional quality stays unset until touched.
- Overnight sleep groups per the documented convention; review/chart/export values agree.

## 14. Stress — P1 (not yet native)
- Required stress level validates; source and notes optional.
- Stress is never framed as *causing* a reaction.
- Review, overlays and export preserve recorded values.

## 15. Cycle tracking — P1 (not yet native)
- Hidden when disabled; phase, flow, date, notes persist; optional where specified.
- Review and overlays communicate meaning **without color alone**; export and deletion work.

## 16. Adverse-intervention reactions — P1 (planned)
- Trial, outcome and decision stay distinct fields; discontinued / reduced /
  continued-with-management / paused each persist.
- Links to the relevant intervention without rewriting regimen history.
- "Tried and failed" appears in review and clinician reports.
- AI does not reinterpret the decision as treatment advice; export includes the complete history.

## 17. Diagnoses, hypotheses and body systems — P1
- Confirmed / suspected / ruled-out cannot collapse into one another.
- Partial dates (a year alone) survive round-trip.
- Hypotheses support active / supported / refuted / paused and are **never promoted to diagnoses**.
- Custom body systems are scoped to their owner; renaming a category does not corrupt history.
- Negative findings appear in review, reports and export.

## 18. Tags — P1
- Names unique per user; unreadable and unattachable across accounts.
- Same tag attaches to different entry types, but not twice to one entry.
- Deleting an entry removes only its joins; deleting a tag removes joins but not entries.
- Filtering and export return correct associations.

## 19. Review, timeline and filters — P1 (partial on native)
- Every supported entry type appears; sorted correctly by timestamp.
- Fuzzy times render honestly rather than inventing precision.
- Local-day grouping correct around midnight and DST; empty states neutral.
- Filters combine correctly and clear; date boundaries include the first and last moments.
- Pagination cannot make old data unreachable; deleted entries disappear immediately.
- **Native gap:** review is limited to a seven-day symptom-and-food subset.

## 20. Raw export — P0 (not yet native)
- CSV and JSON available to **free** users; includes every user-owned model and field.
- Optional disabled dimensions still included historically; unknown scheduled doses represented honestly.
- Unicode, newlines and spreadsheet-sensitive values escaped safely.
- Date/time fields preserve value, timezone and precision.
- Generation rate-limited without limiting content; download requires ownership **and** the signed
  token; tokens expire as documented; expired files removed.
- One user cannot download another user's export.

## 21. Charts and clinician reports — P1/P2 (planned)
- Only paid users get paid presentation; raw source data stays free.
- Chart values match exported raw records; meal and dose markers align to correct timestamps.
- Layers toggle independently; missing/unknown data is **not plotted as zero**.
- Legends work with screen readers and never rely on color alone.
- PNG matches the displayed chart; PDF variants carry the correct focus-specific sections.
- Medication history and dose summaries neutral and complete; generated PDFs protected and expiring.

## 22. AI insights — P0 privacy / P2 functionality
- **Off by default**; disabled AI sends no health data to any provider.
- Free/paid entitlement enforced server-side; date range and source entries explicit.
- Output carries association-not-causation framing; the safety validator blocks diagnoses, causal
  claims and treatment recommendations; unsafe output is neither displayed nor stored.
- Provider failures never damage user-entered data; AI artifacts stay separate from raw records.
- Pagination reaches every artifact; user can purge AI artifacts independently; retention sweep
  removes expired ones.
- Export labels AI content as generated interpretation.
- Freeform-to-structured conversion requires confirmation before writing.

## 23. Account deletion — P0 (not yet native)
- Reachable without contacting support; confirmation describes consequences without pressure;
  reauthentication required where appropriate.
- Attachments/files removed **before** their database references; all user-owned rows cascade or are
  explicitly deleted; sessions and verification tokens revoked.
- Secure local tokens and drafts cleared; export and AI files removed.
- Deleted credentials cannot continue using APIs; backup-removal schedule matches the privacy policy.
- Repeating the request does not leave a half-deleted account.

## 24. Drafts, offline operation and synchronization — P0
- Drafts stored only in protected local storage; each form overwrites **one** draft, no history.
- Draft expires after the documented period; successful save removes it; logout and account
  deletion clear every draft; storage failure never crashes the form.
- Offline saves queue; reconnecting creates one server record; retry after timeout does not duplicate.
- Sync conflicts favor the latest deliberate user action; deleted records are never resurrected.
- Different users on the same device cannot see each other's drafts.

## 25. Accessibility, language and themes — release gate
- Unique title/heading per screen; visible label per input; touch targets meet the project's 44×44 rule.
- Logical focus order and Back/Cancel; modals trap and restore focus.
- Save success uses a **polite** live region; failures use an **assertive** alert.
- Large text does not clip controls or hide actions; orientation and keyboard do not obscure fields.
- Light/dark meet contrast requirements; selected status conveyed by more than color;
  reduced-motion honored.
- No hardcoded-string leaks in English; Spanish stays unreleased pending human review.
- Dates, numbers and fuzzy-time labels follow locale.
- **No screen displays streaks, adherence scores or completeness pressure.**

## 26. Privacy, security and operations — release gate
- No PHI in application, proxy, AI, email or crash logs; health values covered by automated
  PHI-field drift checks.
- Every API route enforces authentication and record ownership; mutating browser requests keep CSRF
  protection; bearer-authenticated native requests work without weakening cookie security.
- Secrets outside the repository; database and HTTP connections use TLS.
- Export and AI cleanup jobs run successfully; health endpoints report availability without leaking
  internals.
- Production migrations run before deployment; production config matches the committed deployment spec.
- Latest TestFlight build corresponds to an identifiable source commit; production builds come from
  the canonical branch; rollback procedure tested.
- CI blocks release on lint, tests, database integration tests, accessibility checks and
  production-build failures.

---

## Recommended audit order

1. Identity and sessions
2. **Reaction-now typing defect** ← start here
3. Symptom logging and drafts
4. Regimen and daily check-in integrity
5. PRN, notes and food
6. Preferences and optional dimensions
7. Review and timezone correctness
8. Export and deletion
9. Accessibility and privacy gates
10. Paid reporting and AI
11. Offline synchronization
12. Future integrations, only once implementation begins

**Why the reaction box goes first:** it is the smallest workflow that exercises native navigation,
keyboard focus, controlled input, API creation, review, export and deletion in one pass — so it
validates the audit method itself while clearing a known P0.
