//
//  AppsSectionIndexLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Names a section in the index along the trailing edge of Settings > Apps,
/// on iOS 26 and later, which draw that index for a list.
struct AppsSectionIndexLabel: ViewModifier {
    /// The section's letter.
    let label: String

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.sectionIndexLabel(label)
        } else {
            content
        }
    }
}
