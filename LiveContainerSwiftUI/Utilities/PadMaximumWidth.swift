//
//  PadMaximumWidth.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// On iPad, holds a view to at most `maxWidth`, centered in the room it's
/// given, so a panel or a field made for a phone's width doesn't stretch
/// across a wide window. On iPhone it leaves the view exactly as it is.
struct PadMaximumWidth: ViewModifier {
    /// The widest the view gets on iPad.
    let maxWidth: Double

    func body(content: Content) -> some View {
        // SharedModel.isPhone never changes while ryC0 runs, so the
        // content never switches between the two and keeps its identity.
        if SharedModel.isPhone {
            content
        } else {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        }
    }
}

extension View {
    /// On iPad, holds this view to at most `maxWidth`, centered. On iPhone it
    /// leaves it as it is.
    func padMaximumWidth(_ maxWidth: Double) -> some View {
        modifier(PadMaximumWidth(maxWidth: maxWidth))
    }
}
