# Open development findings

- P3 / AC-13: default all-types accessibility audit fails. Latest complete UI run before PDF fix: build/Tests-20260926-234415.xcresult (15 findings, remaining five tests pass). System Touch Bar description, emoji popup description/action, and parent-child mismatch reproduce independently without Paperloft code; evidence/a11y-probe/report.md. No suppression/waiver; parked framework findings continue to block acceptance.
- P3 review: native PDF Page description is fixed using public accessibility-protocol page labels, verified by build/P3-pdf-label.xcresult (14remaining findings). Category overlap/contrast is fixed and verified by audit plus live UI.
- P3 settings: contrast findings include native active/inactive window titles and inactive History content; unresolved, no blanket platform exemption claimed.
- P5 isolated branch: StoreKitTest header deprecation fails strict import. Three distinct supported approaches failed; no suppression retained. Runtime purchase flows not verified; component not merged.
