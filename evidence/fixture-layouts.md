# Fixture layout inventory — revision 5c4130b

Builder-authored map for visual inspection; the independent report decides acceptance. The rejected corpus is retained in Git history at 5c698fb, with evaluation evidence in gates/P1-cycle1.

| Layout | Structure | Financial example |
| --- | --- | --- |
| 0 | Inline thermal ticket | document-001 |
| 1 | Quantity and line-amount invoice | document-002 |
| 2 | Summary above purchase details | document-003 |
| 3 | Left account sidebar and right charges | document-004 |
| 4 | Two-column basket | document-005 |
| 5 | Stacked item and unit-price rows | document-006 |
| 6 | Invoice with detachable remittance slip | document-007 |
| 7 | Payment stub above itemized receipt | document-008 |
| 8 | Amount-first charge ledger | document-009 |
| 9 | Sectioned item groups | document-022 |
| 10 | Compact card slip with item detail | document-011 |
| 11 | Service statement with right account panel | document-012 |

All replacement documents are synthetic. Item prices sum to the labeled subtotal; sales tax and any meal tip are added to the labeled final total. Photo variants apply perspective, rotation, blur, and JPEG compression. Neither the product nor evaluator reads the label file; only the frozen scorer does.

Current issue: the recognizer flattens Vision observations into separate lines without retaining spatial associations. On this corpus, final-total labels and amounts commonly occupy separate observations. The current parser therefore finds no complete total line. The fixture-phase pipeline can be accepted with low scores; engine accuracy cannot.
