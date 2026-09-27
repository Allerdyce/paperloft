# Open development findings

- P3 / AC-13: default all-types accessibility audit fails. Latest complete UI run: build/Tests-20260926-234415.xcresult (15 findings, remaining five tests pass). System Touch Bar description, emoji popup description/action, and parent-child mismatch reproduce independently without Paperloft code; evidence/a11y-probe/report.md. No suppression/waiver; parked framework findings continue to block acceptance.
- P3 review: native PDF Page content has no description. PDFView/documentView labeling did not resolve the page proxy; public protocol diagnostic underway. Category overlap/contrast is fixed and verified by audit plus live UI.
- P3 settings: contrast findings include native active/inactive window titles and inactive History content; unresolved, no blanket platform exemption claimed.
- P5 isolated branch: StoreKitTest header deprecation fails strict import. Three distinct supported approaches failed; no suppression retained. Runtime purchase flows not verified; component not merged.
