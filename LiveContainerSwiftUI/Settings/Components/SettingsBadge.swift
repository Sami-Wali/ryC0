//
//  SettingsBadge.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The red badge with a number that the Settings app puts on a row asking
/// for attention, such as "Finish Setting Up Your iPhone".
struct SettingsBadge: View {
    /// The number on the badge.
    let count: Int

    @ScaledMetric(relativeTo: .body) private var size = SettingsDesign.badgeSize

    var body: some View {
        Text(count, format: .number)
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, size * SettingsDesign.badgePaddingRatio)
            .frame(minWidth: size, minHeight: size)
            .background(.red, in: .capsule)
    }
}
