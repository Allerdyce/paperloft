# Local phase progression approved

Ali approved the local phase progression proposal on 2026-09-26. The exact authorization and constraints are recorded in AGENTS.md. No further confirmation is required for this scope.

## Small-size icon contrast — APPROVED by Ali 2026-10-01 (tray-front #357C51)

Independent native/built-icon review at daf145d scores16px default tray legibility3/5: the cream receipt remains recognizable, but the green tray merges into the background. Larger32/128px assets and native512px composition score4/5. Evidence: evidence/design/2026-09-27-critique.md and its native/compiled screenshots.

If native material adjustments cannot resolve this while retaining existing asset colors, propose a small increase in tray-front luminance or a slightly stronger top-rim highlight, retaining green hue, exact geometry and composition. No particular replacement color is accepted, no redesign proposed, and no original artwork modified. Compare native16px results before deciding. This is a recorded proposal for later review, not a request interrupting authorized local work.

**Update 2026-09-30: concrete candidate, awaiting the owner's yes.** The 09-30 design review (`evidence/design/2026-09-30-critique.md` §4) measured the built icon's tray at **1.23:1** against the tile at 16 px and 1.18:1 at 32 px. Material-only changes were already tried and reverted (09-27). The candidate:
1. Change only the `04-tray-front` layer fill from `#10462A` to **`#357C51`**, keeping the hue, geometry, other layers and native glass. The mock measures 3.1:1 at 16 px and 2.6:1 at 32 px (`evidence/design/2026-09-30/icon/sheet_small_current_vs_proposed.png`, `proposed_16.png`, `proposed_32.png`).
2. Optional: lift the tile a step in the dark variant (about `#0C4428`) so it separates from dark backgrounds.

SPEC §6.5 keeps the tray "around #10462A" and routes this to the owner, so the icon is unchanged until you say yes. It's a one-line SVG edit plus a rebuild and a 16/32/128 px recheck.

## 2026-09-29 — Sandbox-safe email body PDF rendering

The supplied 1.1 spec requests WebKit for body PDF rendering. A minimal app-sandbox-only probe on this Mac reproduces WebContent termination (renderer diagnostic 1002); standalone WebKit works. The app retains the no-outgoing-network entitlement policy and falls back to native CoreText/CoreGraphics on this explicit startup failure. Both paths use bounded sanitized text and produce selectable header/body PDF pages. This is an implementation deviation, not a claim that sandboxed WebKit passed. Synthetic sandbox and hostile-resource checks are documented in Tests/EmailBodyRendererTests/README.md; final acceptance remains open.

## 2026-09-29 — AC-13: audit findings on system elements (Touch Bar) and one unattributed mismatch — APPROVED by Ali 2026-10-01 (ACCEPTANCE.md amended)

**Evidence:** evidence/a11y-probe/intake11-current/settings-isolation.md and evidence/a11y-probe/report.md. After the app-owned repairs, `performAccessibilityAudit()` reports only elements Paperloft doesn't create:
- a disabled TouchBar group per audited screen ("missing useful accessibility information")
- the system "emoji & symbols" Touch Bar popup when a text field is focused (description + action)
- one parent/child mismatch that XCTest attributes to no element (owner unknown), which appears when a text field is focused

A standalone SwiftUI app with no Paperloft code reproduces all three on this macOS 27 / Xcode 27 machine.

**Proposal:** that the verifier and owner decide whether AC-13's "audit passes" may treat issues on system Touch Bar elements, which the app doesn't own and can't label, as platform findings. Evidence would include a reproduction in a minimal app. Alternatively, a supported way to suppress the automatic text-field Touch Bar items may be found.

**Meanwhile:** the audit test keeps failing on them. The handler returns false, and no audit type or element is filtered.

## 2026-09-30: AC-10 throughput target versus on-device model speed — APPROVED by Ali 2026-10-01, option 1 (ACCEPTANCE.md amended to 400 s)

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

## 2026-10-01: Pro "auto-file" in SPEC 6.3 isn't built (note for the owner)

SPEC 6.3 lists auto-file among Pro features. The app deliberately files nothing without the user's confirmation: the review inbox, App Intents ("Never auto-file") and SUPPORT all say so. The paywall, Help and SUPPORT therefore list only what Pro delivers in this build: every document read automatically, the watched folder, accountant packs and Shortcuts export. If you want auto-file for confident documents as a Pro option, it's a new feature to scope; nothing is promised meanwhile.

## 2026-10-01: StoreKitTest unit tests can't compile under warnings-as-errors (AC-11 "StoreKit tests"; owner decision)

Xcode 27's own `StoreKitTest.framework/Headers/SKTestTransaction.h:34` uses `SKPaymentTransactionState`, which is deprecated since macOS 15. With `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, importing StoreKitTest fails inside Apple's header, before any of our code compiles.

**Approaches tried, all with the identical error** (evidence in `evidence/commerce/`):
1. the implicit-module build setting
2. a macOS 14 deployment target for the test bundle
3. `-Wno-deprecated-declarations`, a diagnostic only, rejected as suppression
4. on 2026-10-01, the developer frameworks treated as system frameworks (`SYSTEM_FRAMEWORK_SEARCH_PATHS`), with testing search paths off

**What ships now:**
- The app's commerce code (StoreController, PaywallView, the monthly quota) is integrated and builds with zero warnings.
- AC-11's purchase flows are covered by XCUITests through the Debug/QA mock store: the paywall at the 26th document, buy yearly, buy lifetime, restore, expiry, and the export paywall.
- `CommerceModelTests` and `UnderstandingQuotaTests` cover the model.
- Real StoreKit purchases are exercised in the supervised shakedown with the local StoreKit file.
- The StoreKitTest-based `StoreControllerTests` stay on `local/commerce`, unmerged.

**Options:**
- (a) Accept the mock-store XCUITests plus the shakedown as AC-11's StoreKit evidence.
- (b) Allow a scoped exception: warnings-as-errors off for the store-test target only, which would still show one Apple-header warning.
- (c) Wait for an SDK fix.

Recommendation: (a).

**2026-10-02 update:** SPEC 6.7's "StoreKit test configuration loads under test" depends on the same block, because loading a configuration in tests is what StoreKitTest's `SKTestSession` does.
- **Now on run/1:** `Tests/StoreKit/Paperloft.storekit`, with both products, the prices and the one-week yearly trial. It's attached to the scheme's Run action, so supervised and persona sessions run from Xcode buy through real StoreKit locally, with no account.
- **Tried without StoreKitTest:** a scheme Test-action reference, with two path forms. Hosted StoreKit 2 tests still got no products, and the generated `.xctestrun` carries no configuration. So tests can't load it without the blocked framework.
- **Your choice of option covers this too.**


## 2026-10-01: First App Store version number — 1.0 or 1.1 (owner decision)

The project builds as version **1.1** (`MARKETING_VERSION`, app and Share targets). The working name "1.1" comes from the intake plan (`docs/INTAKE-1.1-PLAN.md`). But AC-19 (frozen) says "Build 1.0 archived, exported, uploaded", and the listing draft (`release/metadata.md`) is titled 1.0. The release check flagged the mismatch (`evidence/release/2026-10-01-review.md`).

- **Option 1 (recommended):** ship the first App Store release as **1.0**. It matches AC-19 and the listing. The agent sets `MARKETING_VERSION = 1.0` for both targets just before the archive; nothing else changes.
- **Option 2:** keep 1.1. The listing draft gets retitled, and AC-19's "1.0" is read as "the first build" (that would need your amendment, like the AC-10 one).

Until you decide, the agent follows the frozen criterion and archives as 1.0. *2026-10-02:* `config/Distribution.xcconfig` sets 1.0 for distribution builds only. Development builds still say 1.1.

## 2026-10-01: Reference-design elements the third design review wants changed (AC-16; owner decision)

The third review (`evidence/design/2026-10-01-critique.md`) scores some lines below 4 because of elements that came from your reference-design work on 2026-09-27 (REPORT.md: "Expensify references informed styling"), or that a locked test pins. AC-16 needs 4 or better everywhere, but these are look-and-feel choices you made, so I haven't changed them. The P1s and most P2s are fixed (BUGS.md R3 notes, commit 5c02333).

| Element today | Critic's recommendation | My recommendation |
| --- | --- | --- |
| **Settings row in the sidebar**, showing Settings inside the main window (alongside the real ⌘, Settings window) | Remove it; settings live only in the Settings window | Keep the row for the look, but have it open the real Settings window, so there's one place to change things |
| **Serif heading "A place for your paperwork"** under the toolbar title "Inbox" (about 125 px of titles) | One title: "Inbox" with a subtitle like "2 receipts to review" | Needs your call: the locked NavigationTests pins this heading text, so changing it would need an acceptance amendment. Otherwise keep it and accept the extra band |
| **Coloured status chips** (All, Ready, Processing, Duplicates, Issues) | A segmented control in the toolbar, or a filter pop-up | Keep the chips (they're part of the look); or switch to a segmented control if you prefer native. *Checked 2026-10-02:* the chips already report which one is selected to VoiceOver (`StatusChipAccessibilityTests`), and with Full Keyboard Access on they take keyboard focus like any Mac button. Keeping them needs no further work |
| **Row checkboxes and "Select all"** | Native list multi-selection (⌘-click, ⇧-click, Edit › Select All) with batch actions in the toolbar | Switch to native multi-selection. The checkboxes are the least Mac-like element |
| **Date as a text field plus calendar button** | One `DatePicker` field | Switch to `DatePicker(.field)`; it also localizes the date |
| **Library card rows with a "View" pill and in-content search** | A SwiftUI `Table` with sortable columns and toolbar search | Switch to `Table`. More rows fit, and sorting is native |

If you agree with my column, I'll make those changes together, with the UI tests updated, and run another review.

**Fourth review update (2026-10-01):** the critic confirmed that my recommendations would bring the Review inbox, Library and Settings HIG lines to 4. The critic suggested hiding the toolbar title so the serif heading is the only title. I tried that, but without a title macOS put the toolbar buttons at the leading edge, so I reverted it. The double band stays until you decide about the heading. The critic also flagged the grey circle behind the sidebar toggle. That's macOS 27's standard glass toolbar button, not a custom control, so I'd leave it.

**P6 note (2026-10-02):** the in-window Settings page is the one screen without an accessibility audit (BUGS.md A6-05). Its long scroll view makes the audit report contrast failures for off-screen text. My recommendation for the Settings row would remove that page, and the real Settings window's panes are already audited. If you keep the page, I'll split it into shorter sections so it can be audited.
