# App-model resilience checks

Scoped local PASS for three new tests on the intent-adapter base db1a3f3. These compile the real AppModel and exercise actual inbox persistence and recognition; no fake recognizer, UI hook or product change was added.

The invalid-document test imports five synthetic inputs into a real temporary library: empty PDF, corrupt PDF, password-locked PDF, exactly200-page PDF, and exactly50-megapixel PNG. Each reaches failed status with a specific actionable message, cannot be filed, leaves the original SHA256 unchanged, and retains its message/status in a newly initialized AppModel. A20-second completion ceiling catches stalled processing; the three-test suite completed in under one second. This is not an AC-10 responsiveness metric.

The other tests check a missing library and invalid bookmark: startup releases busy state, reports a folder-recovery action, preserves existing inbox bytes and does not invent a replacement library.

Fresh strict Debug build/test passed all3tests, zero warning/error diagnostics: build/AppResilienceFinal.xcresult and build/app-resilience-final.log. Earlier run also passed; final run strengthened missing-library message verification and bounded the assertion loop. Local preflight38PASS,1WARN,0FAIL/TFAIL; protected baseline/hashes pass. No frozen tests changed.

Limits: this is actual app-model behavior, not a visible UI interaction or literal process relaunch. A newly instantiated model reads the persisted inbox. Real stale security-scoped bookmark renewal, non-receipt review UI, in-flight missing-source recovery and actual app crash/relaunch remain outside this evidence. No full AC-09/P6 acceptance or release claim. Independent review is pending.
