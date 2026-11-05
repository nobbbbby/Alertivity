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
        VStack(alignment: .leading, spacing: 18) {
            featureSummary("pro.summary.monitoring", title: "settings.group.monitoring", symbol: "waveform.path.ecg")
            featureSummary("pro.summary.notifications", title: "settings.tab.notifications", symbol: "bell")
            featureSummary("pro.summary.menuBar", title: "settings.tab.menuBar", symbol: "menubar.rectangle")
        }
    }

    private func featureSummary(_ key: String, title: LocalizedStringKey, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(.tint)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .fontWeight(.semibold)
                Text(LocalizedStringKey(key))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(key)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Purchases stay in Settings, away from monitoring and permission setup.
struct ProSettingsPane: View {
    @ObservedObject var store: ProStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProFeatureList()
            VStack(alignment: .trailing, spacing: 6) {
                purchaseActions
                purchaseMessage
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
        }
    }

    private var purchaseActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Spacer(minLength: 0)
                purchaseControls
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .trailing, spacing: 8) {
                purchaseControls
            }
        }
        .disabled(store.isBusy)
    }

    @ViewBuilder
    private var purchaseControls: some View {
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

    @ViewBuilder
    private var purchaseMessage: some View {
        if let key = store.messageKey {
            SettingsFootnote(key: LocalizedStringKey(key))
                .accessibilityIdentifier("pro.purchaseMessage")
        } else if !store.hasProAccess {
            SettingsFootnote(key: "pro.oneTime")
                .accessibilityIdentifier("pro.purchaseNote")
        }
    }
}
