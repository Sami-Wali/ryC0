//
//  HomeButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// ryC0's stand-in for the iPhone's Home button: a round glass button
/// with AssistiveTouch's rings that does what pressing Home does. It looks the
/// same over the wallpaper, over Settings in light or dark mode, and
/// over apps, where TweakLoader draws the same button in UIKit.
struct HomeButton: View {
    /// What pressing it does, which is HomeScreenModel's `goHome()`.
    let action: () -> Void

    /// Counts the presses, so each one plays a light tap.
    @State private var presses = 0

    var body: some View {
        Button(action: press) {
            Label {
                Text("ryc0.home.homeButton".loc)
            } icon: {
                HomeButtonGlyph()
            }
            .labelStyle(.iconOnly)
            .frame(width: HomeDesign.homeButtonSize, height: HomeDesign.homeButtonSize)
            .homeButtonGlass()
            .contentShape(.circle)
        }
        .buttonStyle(HomeButtonPressStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: presses)
        .accessibilityHint("ryc0.home.homeButtonHint".loc)
    }

    private func press() {
        presses += 1
        action()
    }
}
