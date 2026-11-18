# Release resumption regression

Full scripts/ci.sh passed on local/signpost-persist 477711c using config/PaulDevelopment.xcconfig. 44 UI tests passed, app-hosted and package tests passed, clean Debug and Release builds passed warning checks.

Log: /Users/builder/Factory/paperloft-signpost/build/release-resume-ci-20261118.log
Hosted result: /Users/builder/Factory/paperloft-signpost/build/Tests-20261118-114950.xcresult

Independent scoped review passed the six-line Pipeline-only persisted-signpost configuration: fixed interval name with no receipt payload. This is regression evidence, not final release readiness.

xcresulttool summary: merged result build/Tests-merged-20261118-121736.xcresult reports 446 passed, 0 failed, 0 skipped (454 runs across configurations).

Runtime diagnostic retained: package-only ResilienceTests.ordinaryImageAndPDFCompleteWithoutCrashing passed in 0.1995 s, with a QoS warning at Recognize.swift:114, VNImageRequestHandler.perform. App-hosted occurrence passed in 0.1706 s without the warning. Independent read-only review found no app-owned queue/semaphore wait; Apple Vision internal scheduling is an inference, not a symbolicated conclusion. AC-01 build warning checks passed; AC-10 responsiveness still assessed separately.
