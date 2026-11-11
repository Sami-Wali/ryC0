//
//  HomeIconButtonStyle.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// How a Home Screen icon reacts to a touch: it darkens while the finger is
/// on it, as iOS icons do.
struct HomeIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.3 : 0)
    }
}
