//
//  LCAboutRowLabel.swift
//  LiveContainerSwiftUI
//
//  The text of an About page row: a title with an optional line under it.
//

import SwiftUI

struct LCAboutRowLabel: View {
    /// Already localized, or a name that isn't translated.
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundStyle(.primary)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
