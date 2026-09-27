# Independent Mail UI diagnostic

Root fresh build at bfa8fae plus new diagnostic tests: build/IndependentMailUI.xcresult. Local EML file-picker/body/attachment/relaunch/original-preservation test PASS. Two new tests FAIL; no full Mail promise component pass.

Menu-bar test closes the main window, finds/clicks the actual menubar.status and menubar.open controls, then no main window appears within10seconds. The next drag test fails its initial toolbar wait after relaunch, so its drag has not executed. Preserve this as an unresolved reopening/setup issue rather than claiming promise-delivery failure. Log build/independent-mail-ui.log. Fresh compile succeeded; logs also include Xcode internal diagnostics, so no blanket zero-runtime-warning claim.

The synthetic provider is reproducibly built with scripts/build_mail_promise_probe.sh (ad-hoc local signature only), public AppKit and no product hook. Tests use public XCUITest cross-app coordinate gestures. No Mail account or mailbox access.

Root ended its own windowless app process and released GUI lock. Product repair/recheck required before acceptance; no tests skipped or thresholds relaxed.
