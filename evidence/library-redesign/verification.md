# Library visual-reference correction — 2026-09-27

Owner's screenshot showed older UI (Export Pack, Quick Look, no direct Delete), and owner correctly said the previously completed functional changes were not enough of a visual redesign.

- Found simultaneous older QA process37318 and Release process71410. Opening a rebuilt path had not guaranteed reloading the binary. Gracefully quit both, tested, then launched exact rebuilt Release path with `open -n`. Bound Computer Use to that exact path, clicked Library and viewed fresh native window screenshot. New controls/rounded rows/category icons present on owner's existing five receipts. No owner receipt data changed.
- UI now uses warm adaptive canvas/sidebar, prominent serif heading, large search, bounded filter chips, individually rounded native list rows, category-colored receipt icons and per-row View pills. No empty zebra-striped rows. Retains native selection/double-click/context actions, delete/recovery, search and date/category/type data paths.
- Full local preflight and protected baseline PASS: build/library-redesign-preflight.log, build/library-redesign-final-baseline.log.
- Strict optimized builds PASS, final build/library-redesign-release2.log. No compiler warnings/errors.
- build/LibraryRedesign.xcresult: appearance persistence and double-click/source preview/delete/restart/restore/export tests PASS. New gallery/filter test initially failed because SwiftUI Menu has menu-button AX role rather than AppKit pop-up role. Corrected new test lookup by stable identifier; no frozen tests modified.
- build/LibraryRedesign2.xcresult: five parser-sample filing, search and clear, Type filtering/reset, row View and Light/Dark screenshots PASS (56.441s). Exported screenshots build/library-redesign2-attachments.
- Independent receipt_ux_verifier source/test/visual review PASS. Review identified unbounded category menu label; removed fixedSize, bounded width with truncation and preserved full accessibility value.
- Root and independent reviewer viewed final Light/Dark sample screenshots. Root additionally viewed exact Release app via Computer Use, on owner's existing library with five distinct categories; category colors displayed correctly. This successful binding supersedes prior generic Paperloft Computer Use pipe-failure assumption for the current app session.

Scope limits: native List replaces Table column semantics; full accessibility audit remains open. Existing performance and distribution/full-phase gates remain open. No release or upload.
