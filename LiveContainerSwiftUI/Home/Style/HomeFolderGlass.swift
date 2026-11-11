//
//  HomeFolderGlass.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The frosted glass of a folder's icon, and of the folder that forms behind
/// an icon about to take another in: the Home Screen blurred under a thin
/// dark material, with a light rim, as iOS draws folder icons. It is a blur
/// rather than Liquid Glass, which works out its refraction again on every
/// frame, so a page of folders jiggling in edit mode stays cheap to draw.
struct HomeFolderGlass: ViewModifier {
    /// The glass's corner radius: an app icon's.
    let cornerRadius: Double

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(HomeDesign.folderGlassRim, lineWidth: HomeDesign.folderGlassRimWidth)
            }
    }
}

extension View {
    /// Puts a folder icon's frosted glass behind this view.
    func homeFolderGlass(cornerRadius: Double) -> some View {
        modifier(HomeFolderGlass(cornerRadius: cornerRadius))
    }
}
