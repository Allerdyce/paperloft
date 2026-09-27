# Root integration regression

Source checkpoint:1d1bff7 on run/1. Reviewed watched-folder/startup protection is combined with saved EML intake, assessment reuse and row rendering.

- Protected baseline PASS: build/root-watch-baseline.log.
- Debug core tests PASS:28 XCTest and55 Swift Testing,83total; build/RootWatchIntegrated.xcresult and build/root-watch-tests.log.
- Strict Release build PASS, no compiler warnings: build/root-watch-release.log (build/RootWatchRelease).
- Full UI suite executed9tests,8functionalPASS and1accessibilityFAIL containing14findings. Result: build/RootWatchUI.xcresult, log: build/root-watch-ui.log. No skipped tests or filtered audit issues.
- Functional passes: draft relaunch16.107s; duplicate/undo22.595s; invalid amount/set-aside14.653s; keyboard/file/search/undo31.856s; row selection/status/duplicate undo34.316s; native saved-EML import39.312s; original navigation5.849s; native watched-folder grant/pause/resume/relaunch/main-window-closed intake76.117s.

Accessibility remains unresolved. This is not green full CI, phase acceptance, distribution or release verification. Last fully green CI remains d9454df. Release and uploads remain blocked.
