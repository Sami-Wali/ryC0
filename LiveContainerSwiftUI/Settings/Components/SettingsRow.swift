//
//  SettingsRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A row of the Settings page itself: a colored icon, the name of the page it
/// opens and, on the trailing side, a summary of what that page holds.
struct SettingsRow<Value: View>: View {
    /// The row's name, already localized.
    let title: String
    /// The SF Symbol on the row's icon.
    let systemImage: String
    /// The color of the row's icon.
    let color: Color
    /// What shows on the trailing side, such as the current choice.
    @ViewBuilder let value: Value

    var body: some View {
        LabeledContent {
            value
        } label: {
            Label {
                Text(title)
            } icon: {
                SettingsIcon(systemImage: systemImage, color: color)
            }
        }
    }
}

extension SettingsRow where Value == EmptyView {
    /// A row with nothing on its trailing side.
    init(title: String, systemImage: String, color: Color) {
        self.init(title: title, systemImage: systemImage, color: color) {
            EmptyView()
        }
    }
}
