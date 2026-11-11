//
//  HomeScreenModel+HomeButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home button, ryC0's stand-in for the iPhone's: what pressing it
/// does, and when the Home Screen shows it. Screens opened over the Home
/// Screen and search show it too, each in its own place.
extension HomeScreenModel {
    /// Does what pressing Home does on iOS, one step at a time. A screen open
    /// over the Home Screen closes, along with search behind it, as opening an
    /// app from search would have closed it. Otherwise an open folder closes,
    /// then search, then edit mode ends, and otherwise the first page comes
    /// back.
    func goHome() {
        if presentedScreen != nil {
            presentedScreen = nil
            if isSearching {
                closeSearch()
            }
        } else if openFolderID != nil && isFolderShown {
            closeFolder()
        } else if isSearching {
            closeSearch()
        } else if isEditing {
            endEditing()
        } else if (page ?? 0) != 0 {
            showPage(0)
        }
    }

    /// What the row above the dock shows. When there is more than one page,
    /// the page dots take it while the pages move and for the whole of edit
    /// mode, as on iOS, so it always shows which page is up while icons are
    /// moved. Otherwise the Home button does when pressing it would do
    /// something, in edit mode and away from the first page, and "Search"
    /// does on the first page, so the Home Screen there looks exactly like
    /// the iPhone's.
    var pillContent: HomePillContent {
        if pageCount > 1 && (isEditing || showsPageDots || drag != nil) {
            .pageDots
        } else if isEditing || (page ?? 0) != 0 {
            .homeButton
        } else {
            .search
        }
    }
}
