//
//  SettingsPageLink.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A row of Settings that opens one of its pages. On iPhone it pushes the
/// page with NavigationLink's destination form, like the links on the pages
/// themselves. On iPad, where the list is the sidebar of a split view, it
/// picks the page instead, and the split view shows it in the detail column.
struct SettingsPageLink<Label: View>: View {
    /// The page the row opens.
    let page: SettingsPage
    @ViewBuilder let label: Label

    var body: some View {
        // SharedModel.isPhone never changes while ryC0 runs, so a row
        // never switches between the two kinds of link.
        if SharedModel.isPhone {
            NavigationLink {
                SettingsPageView(page: page)
            } label: {
                label
            }
        } else {
            NavigationLink(value: page) {
                label
            }
        }
    }
}
