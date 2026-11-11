//
//  OnboardingHeader.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The top of a step, laid out like iOS's own setup: a symbol, a large title
/// and a short explanation, all centered.
struct OnboardingHeader<Symbol: View>: View {
    /// The title, already localized.
    let title: String
    /// The explanation, already localized.
    let message: String
    @ViewBuilder let symbol: Symbol

    var body: some View {
        VStack(spacing: OnboardingDesign.headerSpacing) {
            symbol

            VStack(spacing: OnboardingDesign.titleSpacing) {
                Text(title)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .foregroundStyle(.secondary)
                    // The explanation changes as the step does, like when a
                    // check passes.
                    .contentTransition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

extension OnboardingHeader where Symbol == OnboardingHeaderSymbol {
    /// A header under a white symbol on a tile of ryC0's pink, as most
    /// steps have.
    init(systemImage: String, title: String, message: String) {
        self.init(title: title, message: message) {
            OnboardingHeaderSymbol(systemImage: systemImage)
        }
    }
}
