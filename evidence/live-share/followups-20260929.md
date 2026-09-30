# Follow-ups after the Share and App Intents integration — 2026-09-29

Branch `local/followups`. Independent review: PASS (no blockers). The reviewer's intent-race item is fixed (age threshold), and its test gaps for staging-folder pruning and mapped data are added.

1. **Finder share filenames.** Finder providers carry no `suggestedName`. Staging now uses the provider file URL's name inside the `loadFileRepresentation` callback, so `HandoffItem.originalName` keeps the real name. `resolveNames()` replaces the "Document N" display fallback via `loadObject(ofClass: URL.self)`, for file URLs only.
   - ShareSmoke: an unnamed provider stages as `Acorn Receipt.pdf` and displays that name.
   - Live probe host: the sheet showed "Paperloft Live Share Test 1741.jpg" ([probe-sheet-filename.jpg](probe-sheet-filename.jpg)), and Add completed (`didShareItems`).
2. **Intent export retention.** Each Shortcuts export previously left an unzipped folder plus its ZIP in Application Support/Intent-Exports forever.
   - The unzipped copy is now removed after zipping.
   - Exporter-created entries older than 10 minutes (packs and `.Paperloft-export-incomplete-` staging folders) are pruned at the next export.
   - Unlinking never truncates, so mapped results stay readable (tested).
3. **Shortcuts limit.** The action description states that packs over 100 MB must be exported in the app, and NOTES.md records it as required P8 Help/SUPPORT content.

**Checks**
- Signed unit run: 123 XCTest + 113 Swift Testing PASS, 0 warnings (`build/followups/unit3.log`).
- Signed Release: 0 warnings. Privacy and strict codesign PASS.

**Not claimed**
- The originalName of a real cross-process Finder share, inspected in a configured library.
- Unnamed data-backed providers still display "Document N"; they stage under a system name.
