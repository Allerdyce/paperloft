# Paperloft development status — 2026-10-01

**Not launch-ready.** Distribution signing, release archives and App Store Connect uploads are authorized once readiness checks pass. Submission and public release remain blocked.

## Latest work (2026-10-01, lead mode)
- **Paperloft Pro** is integrated:
  - StoreKit 2 store and paywall, with Restore always visible.
  - 25 automatic reads a month on Free, with manual entry always free.
  - Pro-gated accountant packs and watched folder.
  - Purchase flows are covered by mock-store UI tests (AC-11, local).
- **Acceptance baseline:** `acceptance-v1` on `770d6db`, after the owner-approved AC-10 (400 s) and AC-13 amendments. `verify_lock.sh` 17/17.
- **Local gate pre-checks** (`evidence/release/local-gates-20261001.md`):
  - AC-01: fresh clone builds with zero warnings.
  - AC-02: PaperloftKit coverage 95.06%.
  - AC-03: system model on 150 fixtures (date 100, total 99.26, vendor 97.78, kind 99.33, category 100).
  - AC-05: parser 99.26 / 99.26.
  - AC-13: passes under the amendment.
- **AC-10 performance** (`evidence/performance/AC-10-2026-10-01.md`):
  - System model: 100/100 in 369 s, worst main-thread stall 176–234 ms, 417 MB.
  - Parser only: 23 s.
  - Two slowdowns fixed on the way (R2-08, R2-09).
  - The signpost metric needs a run with system-log access (owner action).
- **Release materials (AC-18 drafts):**
  - App Store listing, five 2880 × 1800 screenshots and the purchase-review image (`release/`).
  - Site copy on a local `paperloft-site` branch, **not published**.

## Remaining launch gates
- **Owner-led:** AC-16 third design review (the paywall is now reviewable), formal verifier gates, AC-17 personas, AC-04 fresh holdout (verifier).
- **Apple-dependent:** StoreKit products and App Store Connect (AC-19, after the membership conversion).
- **Fixes and checks:** StoreKitTest unit tests (blocked by an SDK header; PROPOSALS.md), live Mail/Share/scan checks.

## Owner action
- Apple's confirmation of the EvidencePair LLC membership conversion; then `docs/OWNER-RELEASE-SETUP.md`.
- Run `scripts/performance_check.sh system` once from Terminal for AC-10 signpost evidence (HANDOFF.md).
- OK to publish the site branch `release/receipts-1.0-copy`.
- Choose a StoreKitTest option in PROPOSALS.md.

No distribution upload has occurred. Evidence and history: REPORT.md; blockers: HANDOFF.md.
