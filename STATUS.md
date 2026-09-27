# Paperloft status

P0–P2 independently accepted for local development. P3 is active. No further owner approval is needed for routine local phases. Release and uploads remain blocked.

Current checks: 45 unit tests pass (34 Swift Testing + 9 export XCTest + 2 app-model regressions), QA build passes with zero warnings, and all five functional UI tests pass, including sample review/file/search/export/undo, invalid input, duplicate refresh, draft relaunch and navigation. Export engine independently reviewed PASS. Evidence: build/Tests-20260926-234415.xcresult, evidence/export/independent-review.md, evidence/ci/QA.log, build/Tests-20260926-234415.xcresult.

The full UI run is FAIL: the default accessibility audit reports 14 findings. Product-owned label/menu issues have been repaired; Picker layout is fixed; PDF page description is fixed through public accessibility labels. A separate minimal app reproduces system Touch Bar/emoji and parent-child failures. These remain failures, not waivers. Last fully green CI commit: d9454df. P3 self-gate FAIL; preflight, baseline and source integrity PASS. P3 is not independently accepted.

External-folder ZIP export and subsequent PDF preview verified through the real sandbox UI. App Intents work is isolated with framework discovery failures; local logic checks pass. Mail parsing is in progress on a separate branch. Purchase work remains isolated because strict StoreKitTest import fails in an Apple SDK header; no warnings are suppressed. Membership, signing, ASC, supervised shakedown and acceptance-v1 remain deferred. No phase-completion tags, release archives, uploads or submission.
