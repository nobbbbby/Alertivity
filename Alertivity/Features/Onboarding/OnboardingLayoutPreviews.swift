#if DEBUG && !DISABLE_PREVIEWS
import SwiftUI

/// Fixture-only coverage of the selected layout across short and long metric readings.
#Preview("Fixed divider · CPU, network, status") {
    VStack(spacing: 16) {
        ForEach([MenuIconType.cpu, .network, .status]) { type in
            OnboardingLivePreview(
                metrics: .previewNormal, iconType: .constant(type),
                savedIconType: .status, applyStyle: {}
            )
        }
    }
    .padding(28)
    .frame(width: 520)
}
#endif
