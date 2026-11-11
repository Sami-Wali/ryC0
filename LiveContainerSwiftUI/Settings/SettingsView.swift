//
//  SettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SettingsView: View {
    /// The certificate and setup state the pages share.
    @State private var connection = SigningStatus()

    var body: some View {
        Group {
            // SharedModel.isPhone never changes while ryC0 runs, so
            // Settings never switches between the two layouts.
            if SharedModel.isPhone {
                NavigationStack {
                    SettingsRootList()
                        .navigationTitle("lc.tabView.settings".loc)
                }
            } else {
                SettingsSplitView()
            }
        }
        .environment(connection)
    }
}
