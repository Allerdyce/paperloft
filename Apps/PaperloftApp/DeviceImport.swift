import SwiftUI
import UniformTypeIdentifiers
import PaperloftKit

@MainActor private final class DeviceImportCoordinator {
    static let shared = DeviceImportCoordinator()
    private var receiving = false
    func receive(_ providers: [NSItemProvider], model: AppModel) -> Bool {
        guard !receiving else { model.message = "Wait for the current scan to finish, then scan again."; return false }
        guard !providers.isEmpty, providers.count <= 20 else { model.message = "Import up to 20 scans at a time."; return false }
        let supported = providers.compactMap { provider -> (NSItemProvider, UTType)? in
            guard let type = ScanImport.supportedTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) else { return nil }
            return (provider, type)
        }
        guard supported.count == providers.count else { model.message = "Scan a PDF, JPEG, PNG, HEIC or TIFF image."; return false }
        receiving = true
        Task { @MainActor in
            defer { receiving = false }
            var remaining = ScanImport.maximumBytes
            for (provider, type) in supported {
                let folder = model.scanProviderDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    defer { try? FileManager.default.removeItem(at: folder) }
                    let owned = folder.appendingPathComponent("scan." + (type.preferredFilenameExtension ?? "data"))
                    let budget = remaining
                    let count: Int = try await withCheckedThrowingContinuation { continuation in
                        provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { source, error in
                            do {
                                if let error { throw error }
                                guard let source else { throw ScanImport.Failure.invalid }
                                // The provider may delete source immediately after this callback.
                                let copied = try ScanImport.capture(source, destination: owned, budget: budget)
                                continuation.resume(returning: copied)
                            } catch { continuation.resume(throwing: error) }
                        }
                    }
                    remaining -= count
                    let bytes = try Data(contentsOf: owned, options: .mappedIfSafe)
                    await model.importScan(bytes, typeIdentifier: type.identifier)
                } catch { model.message = error.localizedDescription; break }
            }
        }
        return true
    }
}

extension View {
    func receiptDeviceImport(model: AppModel) -> some View {
        importsItemProviders(ScanImport.supportedTypes) { providers in
            DeviceImportCoordinator.shared.receive(providers, model: model)
        }
    }
}
