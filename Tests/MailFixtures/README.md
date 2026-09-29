# Synthetic email development corpus

80 generated messages, with the requested mix: 28 PDF receipts, 24 body receipts
(plain text and HTML), 12 receipts with a non-receipt PDF, and 16 non-receipt emails.
All merchants, messages, addresses and values are synthetic. No owner receipts or
holdout data are included. Transport headers deliberately differ from receipt
merchant/date values.

`labels.jsonl` records MIME part counts and expected receipt selection/fields.
`Tests/Support/GenerateMailFixtures.swift` recreates the corpus. PDF bytes may vary
in creation metadata; labels and document content are deterministic.

`MailFixtureCorpusTests` checks mix, MIME materialization, selectable attached PDF
text, exact attachment bytes and preservation of the original EML. It does not
measure extraction or candidate-selection accuracy. The corpus is a development
baseline with eight text layouts; independent realism/difficulty review and a
separate fresh holdout remain required. It does not replace the existing MIME
edge-case/fuzz tests.

Formal AC-103–105 scores remain pending: the frozen 1.0 scorer has no email modes.
No scorer modification, threshold waiver or acceptance claim is made here.
