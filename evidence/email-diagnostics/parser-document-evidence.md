# Parser document evidence and unreadable-candidate safety

2026-09-29. Synthetic local diagnostic findings only; no formal extraction score.

The five-message parser smoke exposed two different causes. A terms attachment containing “This is not a receipt or invoice” became invoice because the parser treated any incidental occurrence as a document title. A cover note mentioning its attached receipt likewise became receipt without transaction evidence. Separately, the valid receipt PDF in email-001 produced empty text through the production recognizer despite complete selectable text; that is a recognition defect, not negative document evidence.

Parser classification now uses explicit document headings or recognized transaction amount evidence. Non-financial document headings precede transaction content; footer terms do not override an earlier receipt total. A first-row merchant/title column header remains supported with transaction evidence and a structured uppercase title, preserving the frozen adjacent-header regression. Spaced prose and incidental negation cannot impersonate a financial heading. Paid invoices keep their invoice type even when later terms mention receipts.

ReceiptEngine now rejects blank recognized text before invoking any backend. An unreadable attachment remains an unresolved candidate rather than silently causing fallback to a cover message. The API is unchanged. Recognizer rendering repair is independently owned and required to recover the actual valid-PDF path.

Five new generic tests cover incidental mentions/cover notes, non-financial headings with prices, paid invoice/terms and receipt footer precedence, supported document headings/untitled transaction totals, and empty OCR refusing before the backend while preserving original bytes. No fixture-name logic or frozen-test changes were used.

The new blank-text contract exposed two unlocked tests using solid-color images with StubBackend: package TIFF recognition/filing and watched Mail PNG/TIFF review. Those synthetic image generators now render actual receipt text; original byte-identity, source preservation and filing assertions are unchanged. Both paths were verified absent from ACCEPTANCE.lock before editing. No backend-specific empty-input exception was added.

Full package warnings-as-errors suite passed: 28 XCTest + 106 Swift Testing tests (`build/intake11/parser-evidence-full3.log`). Package Release warnings-as-errors build passed (`build/intake11/parser-evidence-release-final.log`). The native full run before the independent PDF raster repair failed on legitimate generated PDFs yielding empty OCR (`build/intake11/parser-native-tests.log`); this failure is retained, not represented as a pass. Combined native verification follows recognition-fix integration.

The strengthened native `WatchedMailIntakeTests` subset passed all four tests (`build/intake11/parser-watched-tests.log`), including stable Mail replacement/relaunch, partial failure preservation and TIFF filing.
