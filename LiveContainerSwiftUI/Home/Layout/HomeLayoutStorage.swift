//
//  HomeLayoutStorage.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Saves the Home Screen layout as JSON in the app group's defaults, along
/// with the page to come back to after an app. Without an app group they fall
/// back to the "Unknown" suite in ryC0's own preferences, and
/// LCSharedUtils copies the layout into the group once ryC0 has one.
enum HomeLayoutStorage {
    /// The defaults key the layout is saved under.
    private static var layoutKey: String {
        forThisCopy("RYC0HomeScreenLayout")
    }
    /// The page an app was opened from. ryC0 quits on the way into the
    /// app, so its state can't be restored any other way.
    private static var returnPageKey: String {
        forThisCopy("RYC0HomeScreenPage")
    }
    /// LiveContainer's custom app order, which the share extension still reads
    /// to list the apps.
    private static let customOrderKey = "LCCustomSortOrder"
    /// LiveContainer's sort setting, which tells the share extension to use
    /// the custom order.
    private static let sortTypeKey = "LCAppSortType"

    private static var defaults: UserDefaults {
        LCUtils.appGroupUserDefault
    }

    /// Whether this is a second ryC0, which shares the app group with
    /// the first but not the apps each keeps to itself, so it keeps its own
    /// layout, rather than one that leaves out the first one's apps.
    private static var isSecondCopy: Bool {
        DataManager.shared.model.multiLCStatus == 2
    }

    /// `key` for this copy of ryC0: as it is for the first, and with the
    /// copy's URL scheme after it for a second.
    private static func forThisCopy(_ key: String) -> String {
        isSecondCopy ? "\(key).\(LCUtils.appUrlScheme() ?? "second")" : key
    }

    /// The saved layout, or nil on the first launch or when it can't be read.
    static func load() -> HomeLayout? {
        // A second ryC0 saved under the shared key before it had its
        // own, so it starts from that, folders and all, until it saves.
        let saved = defaults.data(forKey: layoutKey)
            ?? (isSecondCopy ? defaults.data(forKey: "RYC0HomeScreenLayout") : nil)
        guard let data = saved else {
            return nil
        }
        return try? JSONDecoder().decode(HomeLayout.self, from: data)
    }

    /// Saves the layout. The apps' order is also written as LiveContainer's
    /// custom order, so the share extension lists them as the Home Screen does.
    static func save(_ layout: HomeLayout) {
        guard let data = try? JSONEncoder().encode(layout) else {
            return
        }
        defaults.set(data, forKey: layoutKey)
        // The share extension lists the first ryC0's apps.
        guard !isSecondCopy else {
            return
        }
        defaults.set(layout.appKeysInOrder, forKey: customOrderKey)
        defaults.set("custom", forKey: sortTypeKey)
    }

    /// Saves the page an app is opened from, for when ryC0 comes back.
    static func saveReturnPage(_ page: Int) {
        defaults.set(page, forKey: returnPageKey)
    }

    /// The page an app was opened from, once: it is forgotten after reading,
    /// so only the launch that comes back from an app opens on it. 0 when no
    /// app was opened.
    static func takeReturnPage() -> Int {
        let page = defaults.integer(forKey: returnPageKey)
        defaults.removeObject(forKey: returnPageKey)
        return max(page, 0)
    }

    static func loadDockPage() -> Int {
        max(0, defaults.integer(forKey: forThisCopy("RYC0DockPage")))
    }

    static func saveDockPage(_ page: Int) {
        defaults.set(page, forKey: forThisCopy("RYC0DockPage"))
    }

    /// The custom order LiveContainer's app list saved, which a first launch
    /// starts from. Empty when there is none.
    static func legacyCustomOrder() -> [String] {
        defaults.array(forKey: customOrderKey) as? [String] ?? []
    }
}
