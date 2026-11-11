//
//  HomeButtonBarPlacement.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Puts the Home button bar under a screen, on the grouped background
/// Settings pages use, and ends the screen above it, so nothing on any of its
/// pages goes under the button. Laid over the screen as a safe area bar, it
/// left Settings' pages running on under the button.
struct HomeButtonBarPlacement: ViewModifier {
    /// What pressing the button does.
    let action: () -> Void
    /// Whether the bar shows. It always does on iPhone. Settings on an iPad
    /// wide enough for its sidebar leaves it out, as it puts the Home button
    /// at the bottom of the sidebar instead.
    let isShown: Bool

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            if isShown {
                HomeButtonBar(action: action)
                    .background {
                        Color(.systemGroupedBackground)
                            .ignoresSafeArea()
                    }
            }
        }
    }
}

extension View {
    /// Shows the Home button centered along the bottom of this screen. Apply
    /// it outside the screen's navigation stack, so every page shows it.
    /// `isShown` false leaves the bar out, for a screen that shows the
    /// button somewhere else.
    func homeButtonBar(isShown: Bool = true, action: @escaping () -> Void) -> some View {
        modifier(HomeButtonBarPlacement(action: action, isShown: isShown))
    }
}
