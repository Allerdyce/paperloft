# Paperloft status

P0–P2 independently PASS for local development. P2 accepted tests and safety helpers are locked. P3 app and core UX is now active; no owner action is needed.

Engine evidence:32 passing tests,88.08% whole-target coverage,1,000 randomized file operations, and forced-crash recovery restoring all120 originals. Fixture accuracy: date100%, total99.26%, vendor97.78%, kind99.33%, category100%. Independent fresh holdout: date100%, total96.30%, vendor100%, kind100%, category100%. See evidence/gates/P2.md. Optional type-classification failures preserve extracted fields and force review; they are counted explicitly.

P3 core UI checkpoint is built: folder setup, five samples, review/edit/file, search and filters, history/undo, settings, intake and menu bar UI. All34 current tests and clean Debug/Release builds pass (`build/Tests-20260926-230341.xcresult`). Next: QA configuration, remaining UX/duplicate handling, accessibility checks, export and purchases. P3 independent acceptance is pending. Performance and complete app-facing resilience remain unverified until later gates.

Formal release remains blocked: membership/signing/ASC, supervised shakedown and acceptance-v1 are deferred. No release archive, upload, submission or phase-completion tags.
