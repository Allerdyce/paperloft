# Live Finder Share check — 2026-09-29 (two attempts, BLOCKED)

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
