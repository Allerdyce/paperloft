# Current-root menu-bar Open Inbox diagnostic

Base product revision:13db8a4 (startup/watch integration included; no native Mail promise wrapper). New diagnostic only; product source and all existing acceptance tests unchanged.

`MenuReopenDiagnosticTests.testMenuOpenInboxAfterClosingMain` passed17.485seconds on the first current-root run. It launches with only the documented sample/stub arguments, primes the public Window menu if necessary, selects Library, verifies its heading, closes main and verifies absence, opens the actual menu-bar status item, verifies Open Inbox is enabled and hittable, clicks it, verifies main reappears within the unchanged10second bound, and verifies the Inbox workspace heading. The app terminates in test cleanup.

Result:`build/MenuReopenRoot1.xcresult`; strict Debug build/test log:`build/menu-reopen-root1.log` (zero compiler-warning lines). The log contains complete before/after accessibility trees. Native screenshots are `before-open-inbox.png` and `after-open-inbox.png`. Local preflight38PASS/1WARN/0FAIL/0TFAIL; protected baselinePASS (`build/menu-preflight.log`, `build/menu-baseline.log`). GUI lock released after completion.

The earlier local/mail branch isolated diagnostic failed while its native promise wrapper was present. Captured OpenWindowAction, presented launch/restoration and environment-propagation experiments are historical failed evidence on that different product revision; none was repeated or retained here. This pass establishes current-root behavior only and does not identify the cause of the earlier failure or certify the excluded native promise wrapper. No source repair was necessary. No whole-phase/formal gate or release claim.
