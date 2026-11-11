//
//  HomeIconPointerLift.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Lifts an icon under a trackpad or mouse pointer, as iPadOS Home Screen
/// icons do: the icon alone, in its own shape, while its name stays put. It
/// goes on the icon's artwork, so icons on the pages, in the dock and in
/// search all get it. Touch screens never show it, so an iPhone looks the same.
struct HomeIconPointerLift: ViewModifier {
    /// The icon's corner radius, which the lifted icon's shadow follows.
    let cornerRadius: Double

    func body(content: Content) -> some View {
        content
            .contentShape(.hoverEffect, .rect(cornerRadius: cornerRadius))
            .hoverEffect(.lift)
    }
}
