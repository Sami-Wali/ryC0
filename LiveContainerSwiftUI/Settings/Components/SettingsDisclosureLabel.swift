//
//  SettingsDisclosureLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The label of a button that opens a page only after something else, such
/// as Face ID, has passed. It looks like a row that opens a page: the title
/// and, at the trailing edge, the chevron the list draws on those rows.
struct SettingsDisclosureLabel: View {
    /// The row's name, already localized.
    let title: String

    var body: some View {
        LabeledContent {
            // The weight of the chevron the list draws on rows that open a page.
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        } label: {
            Text(title)
                .foregroundStyle(.primary)
        }
        .contentShape(.rect)
    }
}
