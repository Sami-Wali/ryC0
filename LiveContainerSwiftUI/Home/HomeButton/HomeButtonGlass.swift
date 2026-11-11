//
//  HomeButtonGlass.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home button's glass: dark tinted Liquid Glass on iOS 26 and later, and
/// before that a dark material with a light rim and a soft shadow. It stays
/// dark whatever the appearance, like AssistiveTouch, so the white rings read
/// over any screen.
struct HomeButtonGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled {
            content
                .glassEffect(.regular.tint(HomeDesign.homeButtonTint).interactive(), in: .circle)
        } else {
            content
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(HomeDesign.homeButtonTint)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(HomeDesign.homeButtonRim, lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                        .environment(\.colorScheme, .dark)
                }
        }
    }
}

extension View {
    /// Puts the Home button's round glass behind this view.
    func homeButtonGlass() -> some View {
        modifier(HomeButtonGlass())
    }
}
