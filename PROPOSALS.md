# Local phase progression approved

Ali approved the local phase progression proposal on 2026-09-26. The exact authorization and constraints are recorded in AGENTS.md. No further confirmation is required for this scope.

## Small-size icon contrast — pending, no artwork change

Independent native/built-icon review at daf145d scores16px default tray legibility3/5: the cream receipt remains recognizable, but the green tray merges into the background. Larger32/128px assets and native512px composition score4/5. Evidence: evidence/design/2026-09-27-critique.md and its native/compiled screenshots.

If native material adjustments cannot resolve this while retaining existing asset colors, propose a small increase in tray-front luminance or a slightly stronger top-rim highlight, retaining green hue, exact geometry and composition. No particular replacement color is accepted, no redesign proposed, and no original artwork modified. Compare native16px results before deciding. This is a recorded proposal for later review, not a request interrupting authorized local work.

**Update 2026-09-30: concrete candidate, awaiting the owner's yes.** The 09-30 design review (`evidence/design/2026-09-30-critique.md` §4) measured the built icon's tray at **1.23:1** against the tile at 16 px and 1.18:1 at 32 px. Material-only changes were already tried and reverted (09-27). The candidate:
1. Change only the `04-tray-front` layer fill from `#10462A` to **`#357C51`**, keeping the hue, geometry, other layers and native glass. The mock measures 3.1:1 at 16 px and 2.6:1 at 32 px (`evidence/design/2026-09-30/icon/sheet_small_current_vs_proposed.png`, `proposed_16.png`, `proposed_32.png`).
2. Optional: lift the tile a step in the dark variant (about `#0C4428`) so it separates from dark backgrounds.

SPEC §6.5 keeps the tray "around #10462A" and routes this to the owner, so the icon is unchanged until you say yes. It's a one-line SVG edit plus a rebuild and a 16/32/128 px recheck.

## 2026-09-29 — Sandbox-safe email body PDF rendering

The supplied 1.1 spec requests WebKit for body PDF rendering. A minimal app-sandbox-only probe on this Mac reproduces WebContent termination (renderer diagnostic 1002); standalone WebKit works. The app retains the no-outgoing-network entitlement policy and falls back to native CoreText/CoreGraphics on this explicit startup failure. Both paths use bounded sanitized text and produce selectable header/body PDF pages. This is an implementation deviation, not a claim that sandboxed WebKit passed. Synthetic sandbox and hostile-resource checks are documented in Tests/EmailBodyRendererTests/README.md; final acceptance remains open.

## 2026-09-29 — AC-13: audit findings on system elements (Touch Bar) and one unattributed mismatch

**Evidence:** evidence/a11y-probe/intake11-current/settings-isolation.md and evidence/a11y-probe/report.md. After the app-owned repairs, `performAccessibilityAudit()` reports only elements Paperloft doesn't create:
- a disabled TouchBar group per audited screen ("missing useful accessibility information")
- the system "emoji & symbols" Touch Bar popup when a text field is focused (description + action)
- one parent/child mismatch that XCTest attributes to no element (owner unknown), which appears when a text field is focused

A standalone SwiftUI app with no Paperloft code reproduces all three on this macOS 27 / Xcode 27 machine.

**Proposal:** that the verifier and owner decide whether AC-13's "audit passes" may treat issues on system Touch Bar elements, which the app doesn't own and can't label, as platform findings. Evidence would include a reproduction in a minimal app. Alternatively, a supported way to suppress the automatic text-field Touch Bar items may be found.

**Meanwhile:** the audit test keeps failing on them. The handler returns false, and no audit type or element is filtered.

## 2026-09-30: AC-10 throughput target versus on-device model speed (owner decision)

AC-10 asks for 100 mixed documents understood in ≤ 240 s with the system model, about 2.4 s each including OCR.

**Measured:**
- Field extraction alone averages about 2.56 s and the document-type classifier about 1.36 s. Run concurrently (adopted), a document takes about 3.1–3.6 s of model time, roughly 340–360 s per 100. OCR adds about 0.2 s.
- Short synthetic documents still take about 2.8 s.

**Tried:**
- prewarming (rejected earlier)
- concurrent classification (5–10% faster, adopted; `evidence/performance/concurrent-classification-20260930.md`)
- understanding two documents at once (no gain, because the model serializes sessions; `evidence/performance/concurrency-probe-20260930.md`)

The 240 s target can't be reached by scheduling. What's left changes what the model is asked, and each option needs a full AC-03 accuracy re-run:
1. **Keep the current pipeline and relax AC-10** to about 400 s per 100 documents on this Mac. Accuracy stays as scored: total 99.26%, kind 99.33%.
2. **Drop the separate classifier call** and take the document type from field extraction. This saves roughly 0.5–1.0 s per document. The classifier was added for invoice/bill/receipt accuracy and the bill guardrail workaround, so kind accuracy may fall.
3. **Leaner extraction schema:** shorter guides, and no model-generated confidence. The saving is likely small, since earlier prompt changes moved totals.

Recommendation: option 1. Documents are processed in the background with progress shown, and accuracy matters more than about a minute per 100 documents. The acceptance criterion is frozen, so this needs your decision; nothing has been changed.

