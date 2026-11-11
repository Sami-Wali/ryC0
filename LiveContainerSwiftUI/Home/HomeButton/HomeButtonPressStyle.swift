//
//  HomeButtonPressStyle.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// How the Home button reacts to a touch where Liquid Glass doesn't react on
/// its own: it shrinks a little while the finger is on it and springs back,
/// or dims with Reduce Motion on. Liquid Glass already answers touches, so
/// the button is left to it on iOS 26 and later.
struct HomeButtonPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && !Self.glassReacts

        configuration.label
            .scaleEffect(isPressed && !reduceMotion ? HomeDesign.homeButtonPressedScale : 1)
            .opacity(isPressed && reduceMotion ? 0.7 : 1)
            .animation(HomeDesign.modeChange, value: isPressed)
    }

    /// Whether the button's glass is interactive Liquid Glass, which reacts to
    /// touches itself.
    private static var glassReacts: Bool {
        if #available(iOS 26.0, *) {
            SharedModel.isLiquidGlassEnabled
        } else {
            false
        }
    }
}
