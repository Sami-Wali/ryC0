//
//  HomeStatusBarVisibility.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Hides the status bar while edit mode's buttons take its place, using the
/// status bar toolbar placement on iOS 27 and later. That placement only
/// exists in the iOS 27 SDK (SwiftUI 8), so builds with an older SDK, such as
/// the Xcode 26 CI build, use the older modifier on every version.
struct HomeStatusBarVisibility: ViewModifier {
    /// Whether the status bar is hidden.
    let isHidden: Bool

    func body(content: Content) -> some View {
        #if canImport(SwiftUI, _version: 8.0)
        if #available(iOS 27.0, *) {
            content.toolbarVisibility(isHidden ? .hidden : .automatic, for: .statusBar)
        } else {
            content.statusBarHidden(isHidden)
        }
        #else
        content.statusBarHidden(isHidden)
        #endif
    }
}

extension View {
    /// Hides the status bar while `isHidden` is true.
    func homeStatusBarHidden(_ isHidden: Bool) -> some View {
        modifier(HomeStatusBarVisibility(isHidden: isHidden))
    }
}
