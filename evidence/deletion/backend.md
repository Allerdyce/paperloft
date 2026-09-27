# Receipt deletion and recovery — author verification

Owner requested direct Library deletion, replacing reliance on filing History Undo. This component supplies `DeletedReceipt`, `LibraryStore.delete/restore/deletedDocuments`, and AppModel `deletedDocuments`, `deleteDocument`, `restoreDocument`. UI lives in the coordinating worktree.

Deleted files are exclusively renamed into the selected library's hidden `.paperloft/deleted` directory, never permanently removed. Journals are written before movement, fsynced, and replay interrupted deletion/restoration. Recently Deleted persists across a fresh store/model. Restore refuses target collisions, duplicate active receipt/hash, changed bytes and symbolic links. Library path validation requires year/category/file and excludes hidden components. Existing filing Undo consumes a deleted receipt into its ordinary undo recovery while preserving Move original restoration. Originals outside the library are not changed by deletion/restoration.

AppModel serializes mutations with busy/readiness guards and retains the library access grant. It removes deleted IDs from the cache and filters visible cache results against current active documents, so a stale search cache cannot resurface deleted entries. Exports already enumerate the active library's files.

Validation:
- Session local preflight and protected baseline PASS. Release prerequisites remain deferred.
- Initial `swift test --package-path Packages/PaperloftKit`: 59 tests PASS.
- Final strict Xcode test (`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, only PaperloftKitTests): 29 XCTest + 60 Swift Testing = 89 PASS, no compiler warning/error. `build/DeleteTestsFinal.xcresult`, `build-delete-final.log`.
- New core cases: restart/restore/original preservation, deletion followed by Move filing Undo, collision preservation and retry, changed bytes/symlink rejection, interruption before and after restore rename and after delete rename.
- New actual-model case: delete refresh removes active/search rows, busy prevents mutation, fresh model retains Recently Deleted, restore refreshes index and leaves original bytes unchanged.
- Existing malformed-PDF/bookmark/Apple OCR diagnostics appear in resilience tests; those tests pass. No UI, release archive, upload or phase acceptance performed.

Independent source review is required before integration.
