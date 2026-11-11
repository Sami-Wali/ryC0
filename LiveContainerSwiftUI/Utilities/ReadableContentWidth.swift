//
//  ReadableContentWidth.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// On iPad, keeps the grouped rows of a form or list in one readable column,
/// at most `maxWidth` wide and centered, instead of running across a wide
/// window with their switches far from their labels. It pads the list's safe
/// area at the sides, which the list's own margins then sit inside, so the
/// padding stays with this view: sheets it presents and pages pushed from it
/// lay out from their own width. In a window narrower than the column and its
/// least margins, and on iPhone, the list keeps its usual margins.
struct ReadableContentWidth: ViewModifier {
    /// The widest the rows get.
    let maxWidth: Double

    /// The width the list is given.
    @State private var width = 0.0

    func body(content: Content) -> some View {
        // SharedModel.isPhone never changes while ryC0 runs, so the
        // content never switches between the two and keeps its identity.
        if SharedModel.isPhone {
            content
        } else {
            content
                .safeAreaPadding(.horizontal, padding)
                .onGeometryChange(for: Double.self, of: { $0.size.width }, action: widthChanged)
        }
    }

    /// The padding either side that, with the list's own margin inside it,
    /// centers a `maxWidth` column, or 0, for the list's own margins alone,
    /// when there isn't room for one.
    private var padding: CGFloat {
        guard width > maxWidth + 2 * Self.minimumMargin else {
            return 0
        }
        return CGFloat((width - maxWidth) / 2 - Self.minimumMargin)
    }

    private func widthChanged(_ newWidth: Double) {
        width = newWidth
    }

    /// The least space either side of the column, about what an inset grouped
    /// list leaves by itself, so the margins don't jump where they take over.
    private static let minimumMargin = 20.0
}

extension View {
    /// On iPad, keeps this form's or list's rows in a centered column at most
    /// `maxWidth` wide. On iPhone it leaves them as they are.
    func readableContentWidth(_ maxWidth: Double) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth))
    }
}
