//
//  HomeLiftedIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The copy of the dragged icon that follows the finger in edit mode, over
/// the pages and the dock alike, so moving between them never hides it. It
/// shows from the moment the icon is picked up until it has landed, taking
/// over from the icon and handing back to it in the same place and look,
/// with no fade between them.
struct HomeLiftedIcon: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        if let drag = model.drag {
            HomeLiftedIconCopy(drag: drag, app: app(for: drag.item), metrics: metrics, darkModeIcon: darkModeIcon)
                // The copy is laid out like an icon with its name, so its
                // center sits below the icon's, as a page's icons do.
                .position(x: model.liftedIconCenter.x, y: model.liftedIconCenter.y - metrics.iconSize / 2 + metrics.cellHeight / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.identity)
        }
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }
}
