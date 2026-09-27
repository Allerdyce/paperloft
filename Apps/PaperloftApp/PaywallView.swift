import SwiftUI

struct PaywallView: View {
    @Bindable var store: StoreController
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(store.isPro ? "Paperloft Pro is active" : "Make room for every receipt").font(.title2.bold())
                Spacer()
                Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly).accessibilityIdentifier("paywall.close")
            }
            Text("Unlimited understanding, auto-file, a watched folder, and accountant packs.")
            Text("Free includes 25 automatically understood documents each calendar month. Manual entry and browsing are always unlimited. Samples don’t count.").foregroundStyle(.secondary)
            if !store.ready { ProgressView("Checking purchases…").accessibilityIdentifier("paywall.loading") }
            if !store.isPro {
                Button { Task { await store.purchase(productID: StoreController.yearlyID) } } label: {
                    VStack(alignment: .leading) {
                        Text("Yearly · \(price(StoreController.yearlyID, mock: "$29.99"))/year").font(.headline)
                        Text(store.trialEligible ? "7 days free, then the yearly price. Renews automatically until cancelled." : "Renews automatically each year until cancelled.").font(.caption)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }.accessibilityIdentifier("paywall.yearly").disabled(!available(StoreController.yearlyID))
                Button { Task { await store.purchase(productID: StoreController.lifetimeID) } } label: {
                    Text("Lifetime · \(price(StoreController.lifetimeID, mock: "$69.99")) once").frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }.accessibilityIdentifier("paywall.lifetime").disabled(!available(StoreController.lifetimeID))
            }
            if !store.status.isEmpty { Text(store.status).accessibilityIdentifier("paywall.status") }
            HStack {
                Button("Restore Purchases") { Task { await store.restore() } }.accessibilityIdentifier("paywall.restore")
                Button("Reload Prices") { Task { await store.loadProducts() } }.accessibilityIdentifier("paywall.reload")
                Spacer()
                Button(store.isPro ? "Done" : "Continue with Free") { dismiss() }.accessibilityIdentifier("paywall.continue")
            }.disabled(store.busy)
            HStack {
                Link("Privacy", destination: URL(string: "https://paperloft.app/privacy/")!).accessibilityIdentifier("paywall.privacy")
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!).accessibilityIdentifier("paywall.terms")
                Link("Manage Subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!).accessibilityIdentifier("paywall.manage")
            }.font(.caption)
            #if DEBUG || QA
            if store.isMock {
                DisclosureGroup("Mock store controls") {
                    Picker("Purchase outcome", selection: $store.mockOutcome) {
                        ForEach(StoreController.MockOutcome.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.accessibilityIdentifier("storeMock.outcome")
                    HStack {
                        Button("Expire purchase") { store.mockExpire() }.accessibilityIdentifier("storeMock.expire")
                        Button("Clear local entitlement") { store.mockHideEntitlement() }.accessibilityIdentifier("storeMock.clear")
                        Button("Approve pending") { store.mockApprovePending() }.accessibilityIdentifier("storeMock.approve")
                    }
                }.accessibilityIdentifier("storeMock.controls")
            }
            #endif
        }.padding(28).frame(width: 550).task { await store.start() }
    }
    private func available(_ id: String) -> Bool { !store.busy && (store.isMock || store.products.contains { $0.id == id }) }
    private func price(_ id: String, mock: String) -> String { store.isMock ? mock : (store.products.first { $0.id == id }?.displayPrice ?? "Price unavailable") }
}
