//
//  SettingsDesign.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The look of ryC0's Settings in one place, matched to the Settings
/// app. Sizes are in points at the default text size; the views scale them
/// with Dynamic Type.
enum SettingsDesign {
    // MARK: Row icons

    /// The colored tile beside a row, and an app's icon in the Apps list.
    static let iconSize = 30.0
    /// How much of a tile its symbol takes up, across and down.
    static let glyphRatio = 0.62
    /// A tile's or an icon's corner radius, as a fraction of its size: the
    /// shape of an app icon.
    static let iconCornerRatio = 0.225
    /// The hairline around an app's icon, which keeps white icons apart from
    /// the white rows.
    static let iconOutlineWidth = 0.5
    /// The largest a row's logo grows with the text size, so a 180 pixel
    /// logo stays sharp on a 3x screen.
    static let largestLogoSize = 60.0


    static let cardMarkSize = 60.0
    static let headerMarkSize = 64.0
    static let signingGlyphRatio = 0.625
    static let signingTile = LinearGradient(
        colors: [OnboardingDesign.markGradientStart, OnboardingDesign.markGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Space between the mark and the text beside it.
    static let cardSpacing = 14.0
    /// Space between a title and the line under it.
    static let subtitleSpacing = 2.0
    /// Extra space above and below the card's content, which makes the card
    /// taller than the rows under it, as the Apple Account card is.
    static let cardPadding = 4.0
    static let headerSpacing = 8.0

    // MARK: Add to Home Screen

    /// The icon at the top of Add to Home Screen's sheet, as big as Safari's
    /// Add to Home Screen shows a web page's.
    static let shortcutIconSize = 60.0
    /// Space between that icon and its name.
    static let shortcutSpacing = 14.0

    // MARK: Badges and checks

    /// The height of the red badge on a row that needs attention.
    static let badgeSize = 24.0
    /// The space at each end of a badge's number, as a fraction of its height.
    static let badgePaddingRatio = 0.3
}
