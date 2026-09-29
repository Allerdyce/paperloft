# Parser document evidence and unreadable-candidate safety

2026-09-29. Synthetic local diagnostic findings only; no formal extraction score.

The five-message parser smoke exposed two different causes. A terms attachment containing “This is not a receipt or invoice” became invoice because the parser treated any incidental occurrence as a document title. A cover note mentioning its attached receipt likewise became receipt without transaction evidence. Separately, the valid receipt PDF in email-001 produced empty text through the production recognizer despite complete selectable text; that is a recognition defect, not negative document evidence.

Parser classification now uses explicit document headings or recognized transaction amount evidence. Non-financial document headings precede transaction content; footer terms do not override an earlier receipt total. A first-row merchant/title column header remains supported with transaction evidence and a structured uppercase title, preserving the frozen adjacent-header regression. Spaced prose and incidental negation cannot impersonate a financial heading. Paid invoices keep their invoice type even when later terms mention receipts.

ReceiptEngine now rejects blank recognized text before invoking any backend. An unreadable attachment remains an unresolved candidate rather than silently causing fallback to a cover message. The API is unchanged. Recognizer rendering repair is independently owned and required to recover the actual valid-PDF path.

Five new generic tests cover incidental mentions/cover notes, non-financial headings with prices, paid invoice/terms and receipt footer precedence, supported document headings/untitled transaction totals, and empty OCR refusing before the backend while preserving original bytes. No fixture-name logic or frozen-test changes were used.

The new blank-text contract exposed two unlocked tests using solid-color images with StubBackend: package TIFF recognition/filing and watched Mail PNG/TIFF review. Those synthetic image generators now render actual receipt text; original byte-identity, source preservation and filing assertions are unchanged. Both paths were verified absent from ACCEPTANCE.lock before editing. No backend-specific empty-input exception was added.

Full package warnings-as-errors suite passed: 28 XCTest + 106 Swift Testing tests (`build/intake11/parser-evidence-full3.log`). Package Release warnings-as-errors build passed (`build/intake11/parser-evidence-release-final.log`). The native full run before the independent PDF raster repair failed on legitimate generated PDFs yielding empty OCR (`build/intake11/parser-native-tests.log`); this failure is retained, not represented as a pass. Combined native verification follows recognition-fix integration.

The strengthened native `WatchedMailIntakeTests` subset passed all four tests (`build/intake11/parser-watched-tests.log`), including stable Mail replacement/relaunch, partial failure preservation and TIFF filing.

## Combined recognition verification and review repairs

Independent review also required preserving whole-line paid/unpaid annotations, such as `PAID INVOICE`, `INVOICE — PAID` and `INVOICE (UNPAID)`. These bounded status prefixes/suffixes now preserve invoice type with or without a readable total; cover-note/negation controls remain. No arbitrary trailing prose is accepted as a heading.

Recognition fixes `dae2de8` and `61f79c3` were integrated locally as `55d2382` and `fbeee52`. The combined native hostless run then passed **99 XCTest + 109 Swift Testing tests**, zero failures (`build/intake11/parser-recognizer-native-final2.log`); the earlier legitimate generated-PDF failures passed without editing those fixtures/tests. Incremental Release with Swift warnings as errors passed (`build/intake11/parser-recognizer-release-final.log`). This is not a fresh warning-free claim; the root separately records the Share AppIntents metadata warning from a fresh build.

The recognizer's roughly 64-second cold Vision startup observed by the recognition investigator remains a performance finding. No final email accuracy score or full 1.1 readiness is asserted by these component tests; the production synthetic diagnostic rerun remains separate.
