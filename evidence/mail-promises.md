# Native Mail promise adapter checkpoint

Implementation complete for review; **real promised-file delivery remains unverified**. This is not a full P4 PASS and does not establish actual Mail-source interaction. No mailbox, account, private sample or network was accessed.

## Implementation and SDK basis

Read the installed macOS 27 SDK AppKit headers NSFilePromiseReceiver.h, NSFilePromiseProvider.h and NSDragging.h. The receiving view registers NSFilePromiseReceiver.readableDraggedTypes and reads real NSFilePromiseReceiver objects from the drag pasteboard. It requests delivery only from performDragOperation, uses one new app-owned destination per drag, and supplies a serial operation queue. AppKit documents that modern provider callbacks are inside read coordination; the helper snapshots bytes before that reader callback returns. The receiver is retained across asynchronous delivery.

The native NSHostingView bridge surrounds existing SwiftUI window/menu content without replacing file-URL drop or keyboard handlers. It has a public accessibility label, keeping all children and actions. SwiftUI content is evaluated in its original view body so observation remains tracked. Existing scene actions are captured by the original MenuBarInbox view; an explicit menu-bar reopen check remains unverified.

Advertised file-type counts are capped at 20 before requesting delivery. A shared lock-protected 20-file budget also bounds delivered files because the SDK warns that legacy receivers may advertise only unique types. AppKit does not expose a promise cancellation API; a provider may still write surplus files into the isolated receiving directory, but they are not snapshotted or enqueued beyond that budget.

The received callback must identify a direct .eml child of the receiving folder. A no-follow descriptor pins that folder; no-follow openat rejects a symlink source, regular-file fstat checks size before allocation, and bounded chunk reads detect growth over 32 MB. A separate exclusive descriptor-relative output preserves an app-owned snapshot with a unique name. The reviewed ordinary Mail import path then produces PDFs for manual review. Sender names never choose final output paths, and the source email is unchanged.

## Checks run on this checkpoint

- Xcode Debug app/actual-AppModel unit run: build/MailPromisesUnitFinal.xcresult, exit 0; 13 XCTest + 47 Swift Testing cases passed, no warning/error lines. Command used scheme PaperloftApp, destination platform=macOS, derivedDataPath build/MailIntegrationDebug, SWIFT_TREAT_WARNINGS_AS_ERRORS=YES, only-testing:PaperloftKitTests. Log: build/mail-promises-unit-final.log.
- Final Release app build: exit 0, no warning/error lines. DerivedData build/MailIntegrationRelease; log build/mail-promises-final-release.log.
- Existing real-panel MailFlowTests rerun after introducing the native wrapper: build/MailPromisePanelRegression.xcresult, exit 0; 1 case passed in 36.706 seconds, no warning/error lines. It exercises Settings, keyboard/file-picker input, body/attachment review, durable notices after relaunch, zero automatic filing and original email byte preservation. Later changes only added a label and promised-file count bounds.
- Live CUA accessibility tree showed nested container `Receipt workspace and email drop destination`, original workspace/split labels and native `Receipt document content` PDF page labels. No accessibility child hiding or filtering was introduced. This tree observation is not a complete accessibility audit.
- Unit provider recognition uses a real NSFilePromiseProvider and unique NSPasteboard; rejects ordinary text and rejects 21 advertised promises before requesting delivery. Snapshot tests cover unique exact-byte copies, wrong types, outside paths and symlinks. AppKit explicitly rejects receivePromisedFiles outside prepare/perform/conclude drag; the initial direct-receive test was invalid and replaced by recognition/bounds tests, not a product exemption.

## Remaining GUI evidence

Standalone synthetic source: Tests/Support/MailPromiseSource.swift, compiled with `swiftc -swift-version 6 -warnings-as-errors` into build/MailPromiseSource.app/Contents/MacOS/MailPromiseSource. Its bundle ID is app.paperloft.synthetic-mail-source. Argument: absolute path to Tests/PaperloftUITests/Resources/mail-receipt.eml. It offers a real NSFilePromiseProvider via a normal NSDraggingSession and logs DRAG_STARTED/PROMISE_DELIVERED. It is not linked into the product and adds no launch hook.

CUA positively reached DRAG_STARTED, but neither the source drag-ended callback nor promised-file delivery was observed. Different source initiation events were tried; no destination defect was established, so destination code was not changed speculatively. A genuinely different remaining approach is XCUITest cross-app `press(forDuration:thenDragTo:)` from that standalone source into the actual app. Also verify the menu-bar Open Inbox action with the main window closed. Both checks are explicitly pending, as is any actual Mail drag source interaction.

The GUI lock was acquired atomically and released; both owned GUI processes were terminated. The remaining measurements in another branch received the quiet resource window. All earlier failed diagnostic bundles/logs remain under ignored build for inspection. The incidental preflight refresh is excluded from the commit. Parent independent review must decide merge readiness with these limits visible.
