//
//  SettingsAppIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's icon beside its row in Settings > Apps, as big as the colored
/// icons of the other rows: the icon the Home Screen shows, in its dark
/// version when the icon style asks for it, with a hairline around it.
struct SettingsAppIcon: View {
    let app: LCAppModel

    @Environment(\.prefersDarkAppIcons) private var darkModeIcon
    @ScaledMetric(relativeTo: .body) private var size = SettingsDesign.iconSize

    var body: some View {
        // The Home Screen's icon, which shows at once once drawn, and is
        // otherwise drawn off the main thread, so a long list doesn't wait.
        HomeAppIconImage(app: app, isDark: darkModeIcon)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * SettingsDesign.iconCornerRatio))
            .overlay {
                RoundedRectangle(cornerRadius: size * SettingsDesign.iconCornerRatio)
                    .strokeBorder(.separator, lineWidth: SettingsDesign.iconOutlineWidth)
            }
            .accessibilityHidden(true)
    }
}
