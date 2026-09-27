# Conservative extracted-tax review

The owner-supplied local receipt audit exposed an extracted tax amount without supporting printed tax evidence. Private receipt content, names, amounts and screenshots are excluded from this record and repository.

`ExtractedFields.taxNeedsReview` is an optional persisted diagnostic; legacy JSON remains decodable. System extraction flags tax unless a single clearly labeled printed tax amount agrees. Ambiguous multiple components, repeated lines, surrounding subtotal/rate/total wording and explicit currency conflicts remain flagged. Values are retained for human correction (including potentially valid combined taxes), confidence is capped, and `ExtractionAssessment` adds `taxSourceUnverified` so automatic filing is blocked. This is a conservative source-evidence signal, not tax calculation or accuracy certification. Root adds the visible review warning and tax-field highlight.

Synthetic regression cases cover unsupported multi-charge tax, explicit zero, split label/value, tax rates, invoice titles, unrelated totals, repeated equal components, combined taxes, currency conflicts and persistence/backward compatibility. Frozen tests and scoring thresholds are unchanged.

Validation: full package tests with warnings as errors; optimized package build with warnings as errors. Logs stay in ignored `build/tax-grounding/`. Independent reviewer findings led to stricter label contexts, single occurrence, and currency conflict handling before integration.

Final results: full strict package run passed 12 XCTest plus 68 Swift Testing tests. The lowercase-currency robustness adjustment then passed focused strict tests; independent reviewer reran 3 tax-export XCTest plus all 7 tax-source Swift tests and issued scoped PASS. Optimized strict package build passed. This scoped review is not a full phase or release gate.
