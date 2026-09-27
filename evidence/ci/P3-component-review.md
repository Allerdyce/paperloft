# Independent P3 component review

Read-only reviewer ux_review identified two issues: library switching could overlap suspended filing/undo/export, and exported PDF preview outlived destination access. Both repaired and independently re-reviewed: busy guards reserve the entire operation including panels/startup; controls disabled; refresh generation checks reject stale results; file/undo/export retain their associated grants; export destination grant persists with its result.

Two regression tests exercise busy-entry rejection and preservation of an existing preview. build/P3-appmodel-final.xcresult passes44unit cases (34SwiftTesting+10XCTest), no warnings. External sandbox preview separately verified in evidence/export/external-sandbox-review.md. Reviewer finds no further concrete issue in these fixes; this is not phase-gate approval.

Latest complete UI diagnostic build/P3-owned-audit.xcresult: five functional tests PASS, default accessibility audit FAIL with15findings. Native picker layout fix removes Category contrast finding and Computer Use confirms label/menu no longer overlap. Remaining native PDF Page description, native/inactive-window contrast, TouchBar/emoji and parent-child findings remain open. Full CI is not claimed green.
