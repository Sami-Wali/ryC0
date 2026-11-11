//
//  HomeAddition.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A way to add an app, asked for somewhere other than the Home Screen, such
/// as Settings. Files or the link question open over the Home Screen once
/// that screen has closed, so the new app shows there as it installs.
enum HomeAddition {
    /// An IPA picked in Files.
    case ipaFile
    /// An IPA downloaded from a link typed in.
    case link
}
