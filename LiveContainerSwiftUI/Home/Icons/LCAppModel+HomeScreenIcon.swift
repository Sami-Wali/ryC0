//
//  LCAppModel+HomeScreenIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

extension LCAppModel {
    /// The app's Home Screen icon, in its dark version when asked, as LCAppInfo
    /// has it in memory or saved: until that version has been drawn, the
    /// other one, or nil when neither has. It never draws, so views can read
    /// it as they draw.
    @MainActor
    func homeScreenIcon(isDark: Bool) -> UIImage? {
        appInfo.cachedHomeScreenIconIsDarkIcon(isDark) ?? appInfo.cachedHomeScreenIconIsDarkIcon(!isDark)
    }

    /// Draws the app's Home Screen icon off the main thread when it hasn't
    /// been drawn yet, such as the first time dark icons show, then has the
    /// views showing the app draw it.
    @MainActor
    func drawHomeScreenIcon(isDark: Bool) async {
        guard appInfo.cachedHomeScreenIconIsDarkIcon(isDark) == nil else {
            return
        }
        await withCheckedContinuation { continuation in
            appInfo.drawHomeScreenIconIsDarkIcon(isDark) {
                continuation.resume()
            }
        }
        objectWillChange.send()
    }
}
