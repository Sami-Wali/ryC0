//
//  SettingsRootList.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The list Settings opens on, holding SettingsRootSections' rows. On iPhone
/// each row pushes its page. On iPad the list is the sidebar of Settings'
/// split view and picks the page that shows beside it, as in the iPad's
/// Settings app.
struct SettingsRootList: View {
    /// On iPad, the page picked in the sidebar. Nil on iPhone, where the list
    /// has nothing to pick and each row pushes its page.
    var selection: Binding<SettingsPage?>?

    @Environment(SigningStatus.self) private var connection

    var body: some View {
        Group {
            // Only the iPad passes a selection, and the device never changes,
            // so the list never switches between the two.
            if let selection {
                List(selection: selection) {
                    SettingsRootSections()
                }
            } else {
                List {
                    SettingsRootSections()
                }
            }
        }
        .onAppear(perform: connection.reload)
    }
}
