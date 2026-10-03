# Owner confirmation

I, Paul Allerdyce, confirm the following from my own GitHub account on 2026-10-02.

1. **Acceptance amendments.** I approved the 2026-10-01 amendments recorded in ACCEPTANCE.md under "Owner-approved amendments":
   - AC-10: 400 s per 100 documents with the system model.
   - AC-13: audit findings on system-owned elements don't count when a minimal non-Paperloft app reproduces them.

   The `acceptance-v1` tag on commit 770d6db is the baseline I approved.

2. **Distribution.** I authorize distribution signing, release archives and App Store Connect uploads once the readiness checks pass, as recorded in docs/DISTRIBUTION-AUTHORIZATION.md. For those actions only, this overrides the local-exception restriction in AGENTS.md. Submission for review and public release stay blocked until I say otherwise.

3. **StoreKit evidence (AC-11, SPEC 6.7).** Xcode 27's StoreKitTest framework can't compile under warnings-as-errors because of a deprecation in Apple's own header. I chose option (a) in PROPOSALS.md:
   - AC-11's "StoreKit tests" are the mock-store XCUITests (buy yearly, buy lifetime, restore, expiry, paywall at document 26) plus real StoreKit purchases from the local `.storekit` file in the supervised shakedown.
   - This also covers SPEC 6.7's "StoreKit test configuration loads under test" and shakedown step 7.
