# Native Settings contrast reproduction

A standalone SwiftUI app with no Paperloft dependencies reproduces two remaining contrast findings while its normal Settings window is open: the inactive main window title History and its primary-colored explanatory text. It also reports parent-child, host-group and Touch Bar/emoji findings. All are retained: default all-types audit, handler returns false. This diagnostic does not waive AC-13.

Minimal main content is a VStack with a title, primary Text on an opaque windowBackgroundColor, and SettingsLink. Settings contains standard Text/TextField/Spacer, without custom colors or rendering. No System Settings changed.

One real test ran and failed with eight findings. Result: /Users/builder/Factory/paperloft-audit-probe/evidence/a11y-probe/SettingsProbe2.xcresult. Log: settings-test2.log. Exact source: Tools/AccessibilityProbe/App/ProbeApp.swift and Tests/SettingsProbeTests.swift in that checkout. First command used an incorrect test-target name and executed no test; retained settings-test.log is not verification.

This proves inactive-title/body findings can occur without Paperloft code. The product's foreground Settings title finding was not reproduced in this probe and remains unresolved. The root all-types audit remains FAIL with14findings after PDF page labeling was repaired. No controls/windows were hidden, no audit type removed, no issue ignored.
