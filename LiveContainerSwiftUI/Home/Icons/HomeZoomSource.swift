//
//  HomeZoomSource.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Marks an icon as the place its screen zooms out of on iOS 18 and later,
/// such as Settings out of the Settings icon. Earlier versions open those
/// screens as sheets, and icons outside the Home Screen's pages and dock have
/// no namespace, so those stay as they are.
struct HomeZoomSource: ViewModifier {
    /// The icon's item ID, which the screen's zoom names as its source.
    let id: String
    /// The namespace the zoom is matched in, or nil when nothing zooms out of
    /// this icon.
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}
