//
//  SigningAttentionRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningAttentionRow: View {
    /// What is wrong.
    let attention: SigningAttention
    /// Whether the row draws the chevron of a row that opens a page, for a
    /// button that opens one itself. A navigation link's row gets it from
    /// the list.
    var showsChevron = false

    var body: some View {
        LabeledContent {
            HStack {
                SettingsBadge(count: 1)
                    .accessibilityHidden(true)

                if showsChevron {
                    // The weight of the chevron the list draws on rows that open a page.
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        } label: {
            Text(attention.title)
                .foregroundStyle(.primary)
        }
        .contentShape(.rect)
    }
}
