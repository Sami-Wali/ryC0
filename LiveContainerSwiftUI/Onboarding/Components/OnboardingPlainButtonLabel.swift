//
//  OnboardingPlainButtonLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// How OnboardingPlainButtonStyle draws a button: its title in the tint
/// color, or dimmed while the button can't be tapped, in a tap area at least
/// as big as iOS asks.
struct OnboardingPlainButtonLabel: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .foregroundStyle(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            .multilineTextAlignment(.center)
            .padding(.horizontal, OnboardingDesign.plainButtonPadding)
            .frame(minHeight: OnboardingDesign.minimumTapTarget)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.4 : 1)
    }
}
