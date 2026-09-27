# Combined saved-email and scanner regression

At a17e86a, local preflight: 38 PASS, 1 WARN, 0 FAIL, 0 TFAIL; protected baseline PASS with formal acceptance tag deferred. Swift package regression: 9 XCTest + 55 Swift Testing tests PASS, zero compiler warnings. Strict Release build PASS, zero compiler warnings. Logs: build/root-combined-package.log, build/root-combined-release.log, build/root-resume-preflight.log and build/root-resume-baseline.log.

This verifies combined compilation and package behavior only. It is not a new full CI or P3 pass. Native promised-file dragging, window lifecycle, watched-folder app integration and accessibility remain separately unverified or failing. Last fully green CI remains d9454df.
