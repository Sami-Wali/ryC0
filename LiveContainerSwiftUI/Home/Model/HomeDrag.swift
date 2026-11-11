//
//  HomeDrag.swift
//  LiveContainerSwiftUI
//

import Foundation

/// An icon being moved in edit mode: where it came from, where it would land
/// if dropped now, the layout the other icons show to make room for it, and
/// the icon it would make a folder with or go into instead.
struct HomeDrag: Equatable {
    /// The icon being moved.
    let item: HomeItem
    /// Where the icon was when it was picked up.
    let origin: HomeSlot
    /// The distance from the finger to the icon's center, so the icon doesn't
    /// jump under the finger when it is picked up.
    let grabOffset: CGSize
    /// Where the icon goes if it is dropped now.
    var target: HomeSlot
    /// The layout with the icon at `target`.
    var preview: HomeLayout
    /// The icon the dragged one has hovered over long enough to go into if
    /// dropped now: a folder, or an app or Settings that a new folder would
    /// hold along with it.
    var mergeTarget: HomeItem?
    /// Whether the finger has moved further than a tap would since it picked
    /// the icon up. A folder held and let go without moving opens instead.
    var hasMoved = false
}
