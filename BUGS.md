# Open development findings

- P3 / AC-13: default all-types accessibility audit fails. Latest complete UI run before PDF fix: build/Tests-20260926-234415.xcresult (15 findings, remaining five tests pass). System Touch Bar description, emoji popup description/action, and parent-child mismatch reproduce independently without Paperloft code; evidence/a11y-probe/report.md. No suppression/waiver; parked framework findings continue to block acceptance.
- P3 review: native PDF Page description is fixed using public accessibility-protocol page labels, verified by build/P3-pdf-label.xcresult (14remaining findings). Category overlap/contrast is fixed and verified by audit plus live UI.
- P3 settings: contrast findings include native active/inactive window titles and inactive History content; unresolved, no blanket platform exemption claimed.
- P5 isolated branch: StoreKitTest header deprecation fails strict import. Three distinct supported approaches failed; no suppression retained. Runtime purchase flows not verified; component not merged.

- 1.1 Mail selection: synthetic diagnostic smoke `email-001` has a visibly valid receipt PDF but production Vision yields no text, causing parser `not_receipt` and selection of the cover body. Open recognition investigation and fail-closed guard; evidence/intake11/email-diagnostic-smoke.md.
- 1.1 Mail classification: `email-053` terms attachment says it is not a receipt or invoice, but parser marks it invoice from the incidental word; both PDFs are selected. Generic heading/transaction classification repair under review; frozen tests/scorer unchanged.
- Latest full accessibility regression at403f362:18 unsuppressed findings,15functional UI tests pass,1audit test fails. See evidence/intake-queue/native-regression.md. Earlier counts above are historical.

2026-09-29 update: both synthetic Mail selection findings above are repaired in4b919a3 (bounded PDF scaling, document-heading evidence, blank-OCR refusal). Same5 examples and full80 parser diagnostic now match all expected identities. System-model and varied real-world accuracy remain separate; cold OCR latency remains open.
