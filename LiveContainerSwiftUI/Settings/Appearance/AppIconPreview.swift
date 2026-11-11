//
//  AppIconPreview.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The picture of one of ryC0's icons, from the files iOS uses for it,
/// which are loose in the app rather than in an asset catalog, so they're read
/// through UIImage, which finds the 2x or 3x file for the screen. A build
/// without them shows a plain tile.
struct AppIconPreview: View {
    let name: String

    var body: some View {
        if let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .accessibilityHidden(true)
        } else {
            Rectangle()
                .fill(.quaternary)
        }
    }
}
