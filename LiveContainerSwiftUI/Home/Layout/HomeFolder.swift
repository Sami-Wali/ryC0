//
//  HomeFolder.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A folder on the Home Screen: its name and the icons in it, in order. Like
/// iOS, folders hold apps and Settings, never other folders, and fill their
/// pages of nine from the top left with no gaps.
struct HomeFolder: Codable, Equatable, Sendable {
    /// How many icons fit on one of a folder's pages: three rows of three.
    static let iconsPerPage = 9

    /// The name under the folder's icon and above it when it opens.
    var name: String
    /// The icons in the folder.
    var items: [HomeItem]

    /// The name a new folder gets, and one whose name was cleared.
    static var defaultName: String {
        "ryc0.home.folderName".loc
    }

    /// How many pages the folder's icons take, at least one.
    var pageCount: Int {
        max((items.count + Self.iconsPerPage - 1) / Self.iconsPerPage, 1)
    }
}


extension HomeFolder {
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        items = try HomeItem.decodeIdentifiers(values.decode([String].self, forKey: .items))
    }
}
