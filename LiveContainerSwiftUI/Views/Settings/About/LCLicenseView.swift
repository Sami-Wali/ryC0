//
//  LCLicenseView.swift
//  LiveContainerSwiftUI
//
//  One license's full text, which can be copied, or a link to it online when
//  its file couldn't be read.
//

import SwiftUI

struct LCLicenseView: View {
    let license: LCLicense

    /// The license's text, once it's read from its file.
    @State private var text: String?

    /// Whether reading the file has finished, so the link shows only once it's
    /// known the text isn't there, not while it's read.
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let text {
                    Text(verbatim: text)
                        .font(.footnote)
                        .textSelection(.enabled)
                } else if hasLoaded {
                    Link(destination: license.url) {
                        Text("lc.about.licenseMissing".loc)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(license.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(load)
    }

    private func load() async {
        text = await license.text()
        hasLoaded = true
    }
}
