//
//  LCAboutHeader.swift
//  LiveContainerSwiftUI
//
//  The top of the About page: the app's icon, name and version.
//

import SwiftUI

struct LCAboutHeader: View {
    /// The Home Screen icon, a loose PNG in the app bundle.
    private let icon = UIImage(named: "AppIcon60x60@2x")

    var body: some View {
        VStack {
            if let icon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(.rect(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    }
                    .accessibilityHidden(true)
            }
            Text("ryC0")
                .font(.title2)
                .bold()
            Text("lc.about.tagline".loc)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(LCUtils.getVersionInfo())
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
