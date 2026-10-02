#!/bin/bash
# Verifier raw build: clean Debug and Release, warnings as errors, from the fresh clone.
cd /Users/builder/Factory/paperloft/evidence/checkouts/p3-3dfb51d || exit 1
E=/Users/builder/Factory/paperloft/evidence/verifier-P3-20261001
mkdir -p build/ModuleCache
export CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache"
for cfg in Debug Release; do
  xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' \
    -configuration "$cfg" -derivedDataPath build/DerivedData SWIFT_TREAT_WARNINGS_AS_ERRORS=YES clean build > "$E/raw-$cfg.log" 2>&1
  echo "$cfg exit=$?" >> "$E/raw-build-exits.txt"
done
