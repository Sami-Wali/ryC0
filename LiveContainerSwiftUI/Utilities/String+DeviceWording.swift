//
//  String+DeviceWording.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Words and symbols that name the device ryC0 runs on, so an iPad
/// isn't called an iPhone. The string catalog says iPhone in a key and iPad
/// in the key's `.ipad` sibling.
extension String {
    /// Like `loc`, for a key whose text names the device: on iPad it reads
    /// the key's `.ipad` sibling instead, which says iPad where the key says
    /// iPhone. Call sites name the iPhone key, as in
    /// `"ryc0.onboarding.feature.homeScreenDetail".deviceLoc`.
    var deviceLoc: String {
        SharedModel.isPhone ? loc : "\(self).ipad".loc
    }

    /// The SF Symbol of a grid of apps on this device's Home Screen, for Edit
    /// Home Screen and the rows that stand for the Home Screen: an iPhone's,
    /// or an iPad's on iPad.
    static let homeScreenSymbol = SharedModel.isPhone ? "apps.iphone" : "apps.ipad"
}
