//
//  RyC0MarkStage.swift
//  LiveContainerSwiftUI
//

/// How much of ryC0's icon has come in, as it arrives on the welcome
/// screen. Each stage shows what the ones before it showed, and more.
enum RyC0MarkStage: Int, Comparable {
    /// Nothing yet.
    case hidden
    /// The pink tile.
    case tile
    /// The apps on it: the whole icon.
    case apps

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
