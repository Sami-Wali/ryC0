//
//  HomeIconSpot.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The icon a dragged one is held nearest to, as the icons show while it
/// moves: the icon, its place on the page showing or in the dock, and its
/// center on screen.
struct HomeIconSpot {
    let item: HomeItem
    let index: Int
    let center: CGPoint
}
