// Foundation Models availability check for the Paperloft factory.
//
// Run with: xcrun swift scripts/fm_check.swift
// Prints FM_OK when the on-device system language model is ready,
// or FM_UNAVAILABLE: <reason> when it is not (Apple Intelligence off,
// models still downloading, device not eligible).

import FoundationModels

switch SystemLanguageModel.default.availability {
case .available:
    print("FM_OK")
case .unavailable(let reason):
    print("FM_UNAVAILABLE: \(reason)")
@unknown default:
    print("FM_UNAVAILABLE: unrecognized availability state")
}
