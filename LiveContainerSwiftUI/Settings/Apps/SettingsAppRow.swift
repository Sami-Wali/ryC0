//
//  SettingsAppRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's row in Settings > Apps: its icon and its name.
struct SettingsAppRow: View {
    @ObservedObject var app: LCAppModel

    var body: some View {
        Label {
            Text(app.displayName)
        } icon: {
            SettingsAppIcon(app: app)
        }
    }
}
