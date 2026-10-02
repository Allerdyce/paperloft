import SwiftUI

struct PaywallView: View {
    @Bindable var store: StoreController
    /// Why the sheet opened; the headline leads with it.
    var reason = AppModel.PaywallReason.settings
    var resetDate: Date? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var plan = StoreController.yearlyID
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.isPro { proContent } else { offer }
            HStack(spacing: 14) {
                Link("Privacy Policy", destination: URL(string: "https://paperloft.app/privacy/")!).accessibilityIdentifier("paywall.privacy")
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!).accessibilityIdentifier("paywall.terms")
                Link("Manage Subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!).accessibilityIdentifier("paywall.manage")
            }.font(.callout)
        }
        .padding(28).frame(width: 520)
        .task { await store.start() }
        .onDisappear { store.clearStatus() }
    }

    // MARK: Free: the offer

    private var headline: String {
        switch reason {
        case .settings: return "Get Paperloft Pro"
        case .export: return "Tax & Accountant Export is part of Pro"
        case .limit: return "This month's 25 automatic reads are used"
        }
    }
    private var subheadline: String {
        switch reason {
        case .settings: return "Read every document automatically, with Pro tools for tax time."
        case .export: return "Give your accountant a summary PDF, a spreadsheet of transactions and every document, sorted by category."
        case .limit:
            let date = (resetDate ?? .now).formatted(.dateTime.month(.wide).day())
            return "New documents wait in your Inbox until automatic reads start again on \(date). Pro reads every document as it arrives."
        }
    }
    @ViewBuilder private var offer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headline).font(.title2.bold()).accessibilityIdentifier("paywall.headline")
            Text(subheadline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
        VStack(alignment: .leading, spacing: 8) {
            Label("Every document read automatically", systemImage: "doc.text.viewfinder")
            Label("A watched folder that sends new files to your Inbox", systemImage: "folder.badge.plus")
            Label("Tax & Accountant Export and Shortcuts export", systemImage: "square.and.arrow.up")
        }
        Text("Free includes 25 automatic reads a month. Filling in details yourself, browsing and undo are always free. Samples don't count.")
            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        if !store.ready { ProgressView("Checking purchases…").accessibilityIdentifier("paywall.loading") }
        Picker("Plan", selection: $plan) {
            Text("Yearly · \(price(StoreController.yearlyID, mock: "$29.99")) a year").tag(StoreController.yearlyID)
            Text("Lifetime · \(price(StoreController.lifetimeID, mock: "$69.99")) once").tag(StoreController.lifetimeID)
        }
        .pickerStyle(.radioGroup).labelsHidden().accessibilityIdentifier("paywall.plan")
        Text(planTerms).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("paywall.terms.detail")
        statusLine
        HStack {
            Button("Restore Purchases") { Task { await store.restore() } }.accessibilityIdentifier("paywall.restore")
            if showsReload {
                Button("Reload Prices") { Task { await store.loadProducts() } }.accessibilityIdentifier("paywall.reload")
            }
            Spacer()
            Button("Not Now") { dismiss() }.keyboardShortcut(.cancelAction).accessibilityIdentifier("paywall.continue")
            Button(buyTitle) { Task { await store.purchase(productID: plan) } }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .disabled(!available(plan)).accessibilityIdentifier("paywall.buy")
        }.disabled(store.busy)
    }
    private var planTerms: String {
        if plan == StoreController.lifetimeID { return "One payment. Pro stays yours, with no subscription." }
        let yearly = price(StoreController.yearlyID, mock: "$29.99")
        return store.trialEligible || store.isMock
            ? "7 days free, then \(yearly) a year. Renews automatically until you cancel."
            : "\(yearly) a year. Renews automatically until you cancel."
    }
    private var buyTitle: String {
        if plan == StoreController.lifetimeID { return "Buy Lifetime" }
        return store.trialEligible || store.isMock ? "Start Free Trial" : "Subscribe"
    }
    /// Only when prices didn't load, so there's something to retry.
    private var showsReload: Bool { !store.isMock && store.ready && store.products.isEmpty }

    // MARK: Pro

    @ViewBuilder private var proContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("You have Paperloft Pro").font(.title2.bold()).accessibilityIdentifier("paywall.headline")
            Text(planSummary).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall.planSummary")
        }
        Text("Every document is read automatically, and the watched folder and Tax & Accountant Export are on.")
            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        statusLine
        HStack {
            Button("Restore Purchases") { Task { await store.restore() } }.accessibilityIdentifier("paywall.restore")
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("paywall.continue")
        }.disabled(store.busy)
    }
    private var planSummary: String {
        let yearly = price(StoreController.yearlyID, mock: "$29.99")
        switch store.plan {
        case .lifetime: return "Lifetime purchase. Pro stays yours."
        case .yearly(_, let trialEnds?): return "Your free trial ends on \(trialEnds.formatted(date: .abbreviated, time: .omitted)), then \(yearly) a year."
        case .yearly(let renews?, nil): return "Yearly. Renews on \(renews.formatted(date: .abbreviated, time: .omitted))."
        default: return "Pro is active on this Mac."
        }
    }

    /// The last purchase or restore result. The line keeps its space so the sheet doesn't jump.
    private var statusLine: some View {
        Text(store.status.isEmpty ? " " : store.status)
            .font(.callout).fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(store.status.isEmpty).accessibilityIdentifier("paywall.status")
    }
    private func available(_ id: String) -> Bool { !store.busy && (store.isMock || store.products.contains { $0.id == id }) }
    private func price(_ id: String, mock: String) -> String { store.isMock ? mock : (store.products.first { $0.id == id }?.displayPrice ?? "Price unavailable") }
}
