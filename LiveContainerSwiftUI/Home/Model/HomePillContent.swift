//
//  HomePillContent.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What the row above the dock shows.
enum HomePillContent: Equatable {
    /// The "Search" pill, on the first page when nothing else is going on.
    case search
    /// The page dots, when there is more than one page: while the pages move
    /// and in edit mode.
    case pageDots
    /// The Home button, when pressing it would do something: on every page
    /// but the first, and in edit mode when there is only one page.
    case homeButton
}
