//
//  AppsSectionIndexVisibility.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Shows the index of letters along the trailing edge of Settings > Apps, as
/// the Settings app's list of apps has, on iOS 26 and later.
struct AppsSectionIndexVisibility: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.listSectionIndexVisibility(.visible)
        } else {
            content
        }
    }
}
