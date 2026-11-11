//
//  SettingsSidebarHomeButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Puts the Home button at the bottom of Settings' sidebar on iPad, centered
/// under the rows, while the sidebar shows beside a page. It takes the place
/// of the bar across the whole screen that HomeButtonBarPlacement draws on
/// iPhone and in narrow windows. On iOS 26 and later it's a safe area bar, so
/// rows scrolling beneath it fade as they do under toolbars; before that the
/// sidebar's own color keeps them from showing through the button.
struct SettingsSidebarHomeButton: ViewModifier {
    /// Whether the button shows. Without it the sidebar runs to the bottom.
    let isShown: Bool
    /// What pressing the button does.
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .bottom) {
                if isShown {
                    HomeButtonBar(action: action)
                        .background {
                            if !SharedModel.isLiquidGlassEnabled {
                                Color(.systemGroupedBackground)
                                    .ignoresSafeArea()
                            }
                        }
                }
            }
        } else {
            content.safeAreaInset(edge: .bottom) {
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
}

extension View {
    /// Shows the Home button at the bottom of this sidebar while `isShown`.
    func settingsSidebarHomeButton(isShown: Bool, action: @escaping () -> Void) -> some View {
        modifier(SettingsSidebarHomeButton(isShown: isShown, action: action))
    }
}
