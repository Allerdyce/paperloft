# Live Finder Share check — 2026-09-29

**Current status: RESOLVED for Finder.** The two attempts below were blocked by a blank share window; the Resolution section records the cause, the fix, the A/B test and a successful live Finder share. The "Status" section immediately below is historical.

The owner enabled Paperloft under System Settings → Login Items & Extensions → Sharing. `pluginkit` then showed `+ app.paperloft.receipts.development.share` elected (Paul development signing, team GQ4UA5C6RQ). No settings were changed by the agent.

## What was done
- Synthetic input: a copy of `Tests/Fixtures/document-001.jpg` saved as `build/live-share/Paperloft Live Share Test 1741.jpg` (ignored path, no private data).
- With the GUI lock held and computer use approved by the owner, Finder was driven on the live-share window: toolbar Share → the popover correctly named the synthetic JPEG → Paperloft Receipts. The Finder File menu was deliberately not used, because it reflected a different (Desktop) selection.
- Both attempts launched the extension. LaunchServices chose the identically-signed copy at `paperloft-intake-queue/build/IntentsDataRelease/.../PaperloftShare.appex`; its share-extension code matches root.

## Observed (both attempts)
- The owner watched the second attempt: no Paperloft sheet appeared. The Finder window turned inactive and greyed, with nothing drawn over it.
- CoreGraphics window list: the extension process owned one window with bounds equal to the Finder window (920×436, not the sheet's 430×390) and `onscreen=false`. It was never ordered in.
- `sample` of the extension: its main thread was idle in the NSViewServiceApplication event loop (not hung or crashed). The Info.plist principal class `PaperloftShare.ShareViewController` exists in the binary as `_TtC14PaperloftShare19ShareViewController`. The activation rule matches JPEG and the extension is correctly signed.
- System logs could not be read (`log show`: operation not permitted, even unsandboxed). The computer-use tool also can't grant or capture the extension process, so its UI state was not directly observable.
- Cleanup: the agent terminated the idle extension process (its own test process); Finder recovered. No handoff was confirmed, and the Paperloft inbox was not inspected.
- An unrelated old ad-hoc production-ID build (`build/RootWatchRelease`, Sep 27) was running during the test; it can't share the development extension's app group. It was left untouched.

## Status
The live Finder Share handoff is **unverified and blocked**: the extension launches, but its UI is never presented. The root cause is unknown. It hasn't been established whether this is a product defect (view controller lifecycle / NSHostingView sizing) or a host/system presentation issue; an earlier session saw "Unlock Mac to continue with Siri request" at this step.

Next approaches, each genuinely different:
1. Invoke the same extension through `NSSharingService` from a tiny synthetic host app, to separate Finder from the extension.
2. Add a bounded, test-only launch marker (for example, a file written into the extension's own temporary directory, returned via the handoff proof) so it can be established whether `loadView` runs.
3. Ask the owner to open Console.app filtered on PaperloftShare during one share, since the agent can't read the log store.

## Resolution (same day, later): the share sheet was blank because of a zero-frame hosting view

**Diagnosis**
- A synthetic NSSharingService host (`Tests/Support/ShareHostProbe.swift`, built by `scripts/build_share_host_probe.sh`) separates Finder from the extension. It logs delegate callbacks and window state; its watchdog runs on its own thread, because a sheet's modal run loop starves main-actor work.
- There were 11 duplicate registrations of `app.paperloft.receipts.development.share` (one per local signed build), and the system launched an arbitrary copy. For controlled runs, all but the build under test were unregistered with `pluginkit -r` (list: `build/live-share/unregistered-share-copies.txt`; re-add any with `pluginkit -a`). Registry only: no files deleted, no settings changed.
- `heap` on the extension showed a live `NSHostingView<ShareSheet>` and view graph, so `loadView` ran.
- A/B in the probe host, one registered copy at a time. Earlier probe runs 1 and 2 were inconclusive: the wrong copy launched or the run was cancelled manually before the watchdog fix. The comparison rests on runs 3 and 4:
  - **Unfixed:** the host-side "Paperloft Receipts" window is on screen but renders blank. Its accessibility tree still has Cancel/Add, a Cancel click has no effect, and the probe times out (`probe-run4-old.log`).
  - **Fixed** (`hosting.frame = 430×390` before assigning `view`): the sheet renders ("Add 1 document to Paperloft", Cancel/Add). Add yields `didShareItems` (`probe-run3.log`).

**Live Finder result with the fixed build** (`paperloft-share-present/build/SharePresentRelease`, Paul development signing, strict codesign, privacy PASS, Release 0 warnings)
- Finder live-share window → toolbar Share → Paperloft Receipts. The sheet appeared over Finder ([finder-sheet-fixed.jpg](finder-sheet-fixed.jpg)). Add closed it and Finder recovered.
- The matching development app, launched by exact path: Inbox badge went 1 (after the probe share) → **2** after the Finder share. Items persisted across app quit and relaunch, with no automatic filing.
- Row identity was **not** inspected, because this development container has no library folder chosen and the inbox list is gated behind onboarding.

**Regression check**
ShareSmoke now asserts the handed-over view is 430×390 and matches preferredContentSize. It passes with the fix and fails at that precondition when the pre-fix controller is restored (`build/share-present/smoke*.log`).

**Remaining**
- The candidate name falls back to "Document 1": Finder providers carry no `suggestedName`.
- Preview/Photos hosts, keyboard/VoiceOver on the sheet, larger text sizes and real iPhone scan are unverified.
- Inbox row identity for a shared item needs a configured library.
