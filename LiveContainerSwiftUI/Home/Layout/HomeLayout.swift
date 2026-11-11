//
//  HomeLayout.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where every icon sits: the pages, each holding up to 24 icons in order, the
/// paged dock, and the folders, whose
/// icons sit on the pages or in the dock as an app's do. Like iOS, a page has
/// no gaps; icons fill it from the top left. HomeLayoutStorage saves it as
/// JSON.
struct HomeLayout: Codable, Equatable, Sendable {
    /// How many icons fit on a page: 4 columns by 6 rows, or 6 by 4 in
    /// landscape and in wide iPad windows.
    static let iconsPerPage = 24
    /// How many icons fit in the dock: 4 on an iPhone, as on iOS, and 6 on an
    /// iPad, the most a 320 point Slide Over window still fits in a row. It is
    /// the device's, not the window's, so turning or resizing never pushes an
    /// icon out of the dock, and a layout saved before loads as it was.
    static let dockIconsPerPage = SharedModel.isPhone ? 4 : 6

    static func dockPage(for index: Int) -> Int {
        index / dockIconsPerPage
    }

    func dockRange(on page: Int) -> Range<Int> {
        let start = min(page * Self.dockIconsPerPage, dock.count)
        return start..<min(start + Self.dockIconsPerPage, dock.count)
    }

    /// The pages, left to right. There is always at least one, even if empty.
    var pages: [[HomeItem]]
    /// The dock's icons, left to right.
    var dock: [HomeItem]
    /// The folders, by the id their icon carries.
    var folders: [String: HomeFolder]

    /// A layout with one empty page and Settings in the dock, which is where a
    /// first launch starts before the apps are added.
    init(pages: [[HomeItem]] = [[]], dock: [HomeItem] = [.settings], folders: [String: HomeFolder] = [:]) {
        self.pages = pages.isEmpty ? [[]] : pages
        self.dock = dock
        self.folders = folders
    }

    private enum CodingKeys: String, CodingKey {
        case pages
        case dock
        case folders
    }

    /// Reads a saved layout. One saved before folders came has none.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pages = try container.decode([[String]].self, forKey: .pages).map(HomeItem.decodeIdentifiers)
        dock = try HomeItem.decodeIdentifiers(container.decode([String].self, forKey: .dock))
        folders = try container.decodeIfPresent([String: HomeFolder].self, forKey: .folders) ?? [:]
    }

    /// The apps in Home Screen order: page by page, then the dock, each
    /// folder's apps where the folder is.
    var appKeysInOrder: [String] {
        (pages.flatMap { $0 } + dock).flatMap(contents).compactMap { item in
            if case .app(let key) = item {
                key
            } else {
                nil
            }
        }
    }

    /// An icon, or the icons in it when it is a folder.
    private func contents(of item: HomeItem) -> [HomeItem] {
        if case .folder(let id) = item {
            folders[id]?.items ?? []
        } else {
            [item]
        }
    }

    /// Where an item is, or nil when it isn't in the layout: on a page, in
    /// the dock, or in a folder.
    func slot(of item: HomeItem) -> HomeSlot? {
        if let index = dock.firstIndex(of: item) {
            return .dock(index)
        }
        for (page, items) in pages.enumerated() {
            if let index = items.firstIndex(of: item) {
                return .page(page, index: index)
            }
        }
        for (id, folder) in folders {
            if let index = folder.items.firstIndex(of: item) {
                return .folder(id, index: index)
            }
        }
        return nil
    }

    /// The slot a new app takes: the first free one on the last page, or the
    /// first on a new page when the last page is full.
    var nextFreeSlot: HomeSlot {
        let lastPage = max(pages.count - 1, 0)
        let count = pages.last?.count ?? 0
        if count < Self.iconsPerPage {
            return .page(lastPage, index: count)
        }
        return .page(lastPage + 1, index: 0)
    }

    /// Adds an item where iOS puts a new app: `nextFreeSlot`.
    mutating func append(_ item: HomeItem) {
        insert(item, at: nextFreeSlot)
    }

    /// Takes an item out, wherever it is, a folder included. The page or
    /// folder it leaves can end up empty; `removeEmptyPages()` and
    /// `removeEmptyFolders()` tidy that up.
    mutating func remove(_ item: HomeItem) {
        dock.removeAll { $0 == item }
        for page in pages.indices {
            pages[page].removeAll { $0 == item }
        }
        for id in Array(folders.keys) {
            folders[id]?.items.removeAll { $0 == item }
        }
    }

    /// Puts an item at a slot, moving the icons after it along. A page that
    /// overflows pushes its last icon onto the start of the next page, adding
    /// one when needed. A position past the end of a page, the dock or a
    /// folder means its end. Returns false, leaving the layout as it was, when
    /// a folder would go into a folder. An item for a
    /// folder that's gone takes the next free slot instead.
    @discardableResult
    mutating func insert(_ item: HomeItem, at slot: HomeSlot) -> Bool {
        switch slot {
        case .dock(let index):
            dock.insert(item, at: min(max(index, 0), dock.count))
        case .page(let page, let index):
            let page = max(page, 0)
            while pages.count <= page {
                pages.append([])
            }
            pages[page].insert(item, at: min(max(index, 0), pages[page].count))
            spill(from: page)
        case .folder(let id, let index):
            guard !item.isFolder else {
                return false
            }
            guard let count = folders[id]?.items.count else {
                append(item)
                return true
            }
            folders[id]?.items.insert(item, at: min(max(index, 0), count))
        }
        return true
    }

    /// Makes a folder where `target` is, on a page or in the dock, holding
    /// `target` and then `item`, which leaves wherever it was. Returns the
    /// folder's icon, or nil, leaving the layout as it was, when `target` isn't
    /// on a page or in the dock, or either is a folder.
    mutating func makeFolder(of target: HomeItem, adding item: HomeItem, named name: String) -> HomeItem? {
        guard target != item, !target.isFolder, !item.isFolder else {
            return nil
        }
        var updated = self
        updated.remove(item)
        let id = UUID().uuidString
        let folder = HomeItem.folder(id)
        switch updated.slot(of: target) {
        case .dock(let index)?:
            updated.dock[index] = folder
        case .page(let page, let index)?:
            updated.pages[page][index] = folder
        case .folder?, nil:
            return nil
        }
        updated.folders[id] = HomeFolder(name: name, items: [target, item])
        self = updated
        return folder
    }

    /// Removes the folders with no icons left, and their icons.
    mutating func removeEmptyFolders() {
        let empty = Set(folders.filter { $0.value.items.isEmpty }.keys)
        guard !empty.isEmpty else {
            return
        }
        folders = folders.filter { !empty.contains($0.key) }
        let isEmptyFolder = { (item: HomeItem) -> Bool in
            if case .folder(let id) = item {
                empty.contains(id)
            } else {
                false
            }
        }
        dock.removeAll(where: isEmptyFolder)
        for page in pages.indices {
            pages[page].removeAll(where: isEmptyFolder)
        }
    }

    /// The layout with an item moved to a slot, as it would look if dropped
    /// there. Empty pages stay, so the pages don't shift under the finger while
    /// the item is being dragged.
    func moving(_ item: HomeItem, to slot: HomeSlot) -> HomeLayout {
        var moved = self
        moved.remove(item)
        if !moved.insert(item, at: slot), let origin = self.slot(of: item) {
            // The dock was full: leave the item where it was.
            moved.insert(item, at: origin)
        }
        return moved
    }

    /// Removes the pages that have no icons left, keeping at least one page.
    mutating func removeEmptyPages() {
        pages.removeAll { $0.isEmpty }
        if pages.isEmpty {
            pages = [[]]
        }
    }

    /// Brings the layout in line with the apps the Home Screen shows. Apps that
    /// were removed or hidden leave their slot or their folder, apps not yet
    /// placed take the next free slot in the order given, and Settings comes
    /// back if it went missing. Icons listed twice keep their first place.
    /// Folders left with nothing in them go, as do any no icon stands for.
    mutating func reconcile(withAppKeys keys: [String]) {
        let shown = Set(keys)
        var placed = Set<HomeItem>()
        let savedFolders = folders
        var keptFolders: [String: HomeFolder] = [:]
        func keepsInFolder(_ item: HomeItem) -> Bool {
            switch item {
            case .app(let key):
                shown.contains(key) && placed.insert(item).inserted
            case .settings:
                placed.insert(item).inserted
            case .folder:
                false
            }
        }
        func keeps(_ item: HomeItem) -> Bool {
            switch item {
            case .app(let key):
                return shown.contains(key) && placed.insert(item).inserted
            case .settings:
                return placed.insert(item).inserted
            case .folder(let id):
                guard keptFolders[id] == nil, var folder = savedFolders[id] else {
                    return false
                }
                folder.items = folder.items.filter(keepsInFolder)
                guard !folder.items.isEmpty else {
                    return false
                }
                keptFolders[id] = folder
                return true
            }
        }
        dock = dock.filter(keeps)
        for page in pages.indices {
            pages[page] = pages[page].filter(keeps)
        }
        folders = keptFolders

        var page = 0
        while page < pages.count {
            spill(from: page)
            page += 1
        }

        removeEmptyPages()
        if !placed.contains(.settings) {
            if dock.count < Self.dockIconsPerPage {
                dock.append(.settings)
            } else {
                append(.settings)
            }
        }
        for key in keys where placed.insert(.app(key)).inserted {
            append(.app(key))
        }
    }

    /// Moves a page's overflow onto the following pages, one icon at a time.
    private mutating func spill(from page: Int) {
        var page = page
        while page < pages.count, pages[page].count > Self.iconsPerPage {
            let overflow = pages[page].removeLast()
            if page + 1 == pages.count {
                pages.append([])
            }
            pages[page + 1].insert(overflow, at: 0)
            page += 1
        }
    }
}
