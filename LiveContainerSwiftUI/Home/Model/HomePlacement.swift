//
//  HomePlacement.swift
//  LiveContainerSwiftUI
//

import Foundation

/// An icon and the slot it is shown at.
struct HomePlacement: Identifiable, Equatable {
    /// The icon.
    let item: HomeItem
    /// Where it is shown.
    let slot: HomeSlot
    /// Whether this is the icon being dragged. Its view stays where it was
    /// picked up, hidden, so the drag gesture on it keeps going; a copy follows
    /// the finger instead.
    let isLifted: Bool

    var id: String {
        item.id
    }
}
