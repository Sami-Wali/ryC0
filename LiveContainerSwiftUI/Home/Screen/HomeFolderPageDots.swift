//
//  HomeFolderPageDots.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The dots at the bottom of an open folder with more than one page, the
/// page showing lit up.
struct HomeFolderPageDots: View {
    /// How many pages the folder has.
    let count: Int
    /// The page showing.
    let current: Int

    var body: some View {
        HStack(spacing: HomeDesign.folderPageDotSpacing) {
            ForEach(0..<count, id: \.self) { page in
                Circle()
                    .fill(.white.opacity(page == current ? 1 : HomeDesign.folderPageDotDimming))
                    .frame(width: HomeDesign.folderPageDotSize, height: HomeDesign.folderPageDotSize)
            }
        }
        .accessibilityHidden(true)
    }
}
