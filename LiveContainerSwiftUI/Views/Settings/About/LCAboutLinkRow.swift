//
//  LCAboutLinkRow.swift
//  LiveContainerSwiftUI
//
//  A row of the About page that opens a web page.
//

import SwiftUI

struct LCAboutLinkRow: View {
    /// Already localized, or a name that isn't translated.
    let title: String
    let detail: String?
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                LCAboutRowLabel(title: title, detail: detail)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}
