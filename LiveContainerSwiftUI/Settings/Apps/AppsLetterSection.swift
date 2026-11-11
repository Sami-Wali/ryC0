//
//  AppsLetterSection.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The apps whose names start with one letter, as Settings > Apps lists them
/// under that letter, like the Settings app does. Names that don't start
/// with a letter from A to Z, after accents are set aside, go under "#",
/// last.
struct AppsLetterSection: Identifiable {
    /// The letter, or "#".
    let title: String
    /// The apps, by name.
    let apps: [LCAppModel]

    var id: String {
        title
    }

    /// The title of the section for names that don't start with a letter.
    static let otherTitle = "#"

    /// The apps in sections by first letter, A to Z then "#", each sorted by
    /// name the way Finder sorts. With a query, only the apps whose names
    /// contain it.
    static func sections(of apps: [LCAppModel], matching query: String) -> [AppsLetterSection] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = query.isEmpty ? apps : apps.filter { $0.displayName.localizedStandardContains(query) }
        let sorted = shown.sorted { first, second in
            first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
        }

        var grouped: [String: [LCAppModel]] = [:]
        for app in sorted {
            grouped[title(for: app.displayName), default: []].append(app)
        }
        return grouped.keys
            .sorted { first, second in
                if (first == otherTitle) != (second == otherTitle) {
                    return second == otherTitle
                }
                return first < second
            }
            .map { AppsLetterSection(title: $0, apps: grouped[$0] ?? []) }
    }

    /// The section a name goes in: its first letter without accents, in
    /// capitals, or "#".
    private static func title(for name: String) -> String {
        guard let first = name.first else {
            return otherTitle
        }
        // Capitals can be longer than the letter, as "ß" becomes "SS".
        let capitals = String(first)
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
            .uppercased()
        guard let scalar = capitals.unicodeScalars.first, ("A"..."Z").contains(scalar) else {
            return otherTitle
        }
        return String(scalar)
    }
}
