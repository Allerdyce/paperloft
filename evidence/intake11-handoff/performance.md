# Local handoff writer performance — 2026-09-29

Synthetic standalone harness: Tests/Support/HandoffPerformance.swift. Twenty files of5,000,000bytes each, staged with production HandoffStore. Payload creation is outside the timed interval. Darwin getrusage maximum resident bytes is sampled immediately after publication and includes process/runtime/setup; subsequent byte comparisons are outside this sample. No private receipts.

Before fix:108,756,992bytes peak,0.113seconds. Failed60MB budget.
After per-chunk autoreleasepool:8,978,432bytes peak,0.188seconds. Passed writer budget; source/copy equality checked. Independent source review passed. This is writer-process evidence, not a claim about live Share-extension UI memory or formal AC-111 completion.

Reproduce from repo root:

```sh
mkdir -p build/handoff-performance
xcrun swiftc -O -swift-version 6 -warnings-as-errors -emit-library -emit-module -module-name PaperloftHandoff Packages/PaperloftHandoff/Sources/PaperloftHandoff/*.swift -emit-module-path build/handoff-performance/PaperloftHandoff.swiftmodule -o build/handoff-performance/libPaperloftHandoff.dylib
xcrun swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library -I build/handoff-performance -L build/handoff-performance -lPaperloftHandoff -Xlinker -rpath -Xlinker @executable_path Tests/Support/HandoffPerformance.swift -o build/handoff-performance/HandoffPerformance
build/handoff-performance/HandoffPerformance build/handoff-performance
```
