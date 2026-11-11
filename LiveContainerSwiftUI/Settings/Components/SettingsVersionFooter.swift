//
//  SettingsVersionFooter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// ryC0's version and build, centered under the last section of
/// Settings > Advanced. Tapping it five times turns on developer mode, which
/// shows the Developer page until ryC0 quits, as tapping the version at
/// the bottom of LiveContainer's settings did.
struct SettingsVersionFooter: View {
    @EnvironmentObject private var sharedModel: SharedModel

    var body: some View {
        Text(LCUtils.getVersionInfo())
            .frame(maxWidth: .infinity)
            // Five taps are the point, which only a tap gesture can count.
            .onTapGesture(count: 5, perform: turnOnDeveloperMode)
            .accessibilityAddTraits(.isButton)
    }

    private func turnOnDeveloperMode() {
        withAnimation {
            sharedModel.developerMode = true
        }
    }
}
