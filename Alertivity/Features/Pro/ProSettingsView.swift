import SwiftUI

/// Kept outside disabled controls so pointer hover and VoiceOver can explain the restriction.
struct ProLockHint: View {
    let help: LocalizedStringKey
    let identifier: String

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .help(help)
            .accessibilityLabel(Text("pro.requiresPro"))
            .accessibilityHint(Text(help))
            .accessibilityIdentifier(identifier)
    }
}

/// The same concise feature list appears in Settings and the optional Pro introduction.
struct ProFeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            featureRow("pro.feature.thresholds")
            featureRow("pro.feature.cooldown")
            featureRow("pro.feature.duration")
            featureRow("pro.feature.metricPriority")
            featureRow("pro.feature.samplingActivation")
        }
    }

    private func featureRow(_ key: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "•").accessibilityHidden(true)
            Text(LocalizedStringKey(key))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(key)
        }
    }
}

/// Purchases stay in Settings, away from monitoring and permission setup.
struct ProSettingsPane: View {
    @ObservedObject var store: ProStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(store.hasProAccess ? "pro.unlocked" : "pro.title", systemImage: "star")
                .font(.headline)
            ProFeatureList()
            VStack(alignment: .trailing, spacing: 4) {
                // Keep full action labels and the price visible in compact localized windows.
                ViewThatFits(in: .horizontal) {
                    HStack { purchaseActions }
                        .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .trailing) {
                        purchaseActions
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(store.isBusy)

                if let key = store.messageKey {
                    SettingsFootnote(key: LocalizedStringKey(key))
                        .accessibilityIdentifier("pro.purchaseMessage")
                } else if !store.hasProAccess {
                    SettingsFootnote(key: "pro.oneTime")
                        .accessibilityIdentifier("pro.purchaseNote")
                }
            }
            .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder private var purchaseActions: some View {
        if !store.hasProAccess {
            if let product = store.product {
                Button(L10n.format("pro.buy", product.displayPrice)) {
                    Task { await store.purchase() }
                }
                .accessibilityIdentifier("pro.purchase")
            } else {
                Button("pro.retry") { Task { await store.loadProduct() } }
            }
        }
        Button("pro.restore") { Task { await store.restore() } }
            .accessibilityIdentifier("pro.restore")
        if store.isBusy { ProgressView().controlSize(.small) }
    }
}
