# One-call classifier investigation — 2026-09-29

## Predeclared scope

Exactly one newly authored synthetic invoice, never previously submitted: Cedar Quay Instrument Repair, invoice CQ-1047, issued 2026-09-29, bench inspection/calibration, total due USD 48.00, payment within 14 days. This was a classifier-only diagnostic, not receipt extraction, OCR, candidate selection, pipeline evaluation or accuracy scoring. No prior refused input was resubmitted.

The schema and classifier instructions were extracted verbatim from production Extraction.swift. Default guardrails, temperature 0 and maximumResponseTokens 64 were unchanged. The isolated strict Swift 6 warnings-as-errors executable made one respond call. Typed refusal handling would retain debugDescription and metadata locally; it did not access asynchronous explanation or make a second generation call.

GUI/model lock was acquired atomically, coordinated with tax_export, and released immediately after completion. No UI was driven. Production source was unchanged from c3d5dbd; root had advanced to b0e620d through unrelated work before the manifest was written.

## Result and limits

The single call returned `invoice` in 2.888 seconds, with no error. No refusal payload exists to inspect. This confirms only that the current supported schema/options can produce a response for this one fresh input. It does not explain, repair or invalidate the 37 refusals in the earlier 80-message run. No retry, alternate wording/schema, guardrail change, parser substitution or production edit followed the success.

## Provenance

Predeclaration time: 2026-09-29T23:52:17.594647+00:00. Generation began 2026-09-29T23:52:48Z.

| Item | SHA-256 |
| --- | --- |
| Production Extraction.swift | `786b8aab0cccf205434b2538186b9cceac689178088c8b992b889c98b09d39f8` |
| Classifier schema snippet | `3d78e1a8bc5afc8db82077c5164210dd0b72f136a198cbc035c08c65b1c3fa7e` |
| Classifier instruction string | `dbb934824a6ea2c96602db70c8924d1a774865d25d68976a769cd4d06ef4def1` |
| Fresh input bytes | `e609a83cc08f903f04a4e444302990bcfadb737819ff04a447d1e85537d0fb0a` |
| Actual document prompt | `8e9605ab5838d402a23ef2f057e31b9056bc9f771b690a83de8ed7890e70be79` |
| Probe source | `5e113730ce909f173356c8094c726bb6ad0362f2e426b94c457f4ba9c7d7f1aa` |
| Binary | `c61334f142874e7cd55fe2ff66ea03513c8da4e9f2d7cb35625d992e00d0ef71` |
| Predeclared manifest | `9c4c7bb7c38bb60855dc2843c29e4b66195c1646dd6461996f979d9e3dd8138b` |
| Raw result | `69d0db0909633d5117ddba497dc2feab13ec70949f89c74b8dd51423f5f89d23` |

Raw input, probe, executable, predeclaration, one-time invocation marker and result remain in ignored `build/classifier-once-20260929`; only this sanitized evidence is committed.

## Read-only technical conclusion

Apple documents String anyOf guides as supported fixed-choice generation, so no schema misuse was established. Its refusal documentation distinguishes a refusal from a guardrail violation and notes that a model can refuse when it cannot provide the requested response. The existing reflection-based diagnostic discards native refusal details; this one successful call cannot recover them. The 64-token bound is not proven causal: Apple describes token-limit truncation separately. Neither changing schema representation nor removing the separate classifier is justified by this result.

Primary references: [String anyOf](https://developer.apple.com/documentation/foundationmodels/generationguide/anyof(_:)), [refusal](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/refusal(_:)), [refusal details](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/refusal), [maximumResponseTokens](https://developer.apple.com/documentation/foundationmodels/generationoptions/maximumresponsetokens). Local SDK27 Swift interface also confirms typed Refusal.debugDescription/metadata and asynchronous explanation.

Prior project evidence already contained optional classifier refusals before email integration. Unsupported light reasoning and combined type/numeric extraction experiments remain rejected; this diagnostic does not reverse those findings. Further work requires a distinct evidence-backed proposal, not repeated attempts against refused content.
