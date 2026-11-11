//
//  OnboardingFeatureRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One thing ryC0 does, on the welcome screen: a squircle icon beside
/// a title and a line about it.
struct OnboardingFeatureRow: View {
    let feature: OnboardingFeature

    var body: some View {
        HStack(spacing: OnboardingDesign.rowSpacing) {
            OnboardingIcon(systemImage: feature.systemImage)

            VStack(alignment: .leading, spacing: OnboardingDesign.rowTextSpacing) {
                Text(feature.title)
                    .font(.headline)

                Text(feature.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
