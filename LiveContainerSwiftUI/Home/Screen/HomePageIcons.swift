//
//  HomePageIcons.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The icons of the pages, side by side, each at its slot's place on its
/// page, plus the icon holding a new app's place while it installs. Only the
/// pages near the one showing are built (HomeScreenModel's `builtPages`), so
/// icons far away don't load, and only the page showing jiggles in edit mode.
struct HomePageIcons: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// How many pages wide the layer is.
    let pageCount: Int
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        let currentPage = model.page ?? 0

        ZStack(alignment: .topLeading) {
            ForEach(model.visibleGridPlacements) { placement in
                HomeIconCell(
                    item: placement.item,
                    app: app(for: placement.item),
                    metrics: metrics,
                    showsLabel: true,
                    isLifted: placement.isLifted,
                    isOnScreen: placement.slot.page == currentPage,
                    darkModeIcon: darkModeIcon,
                    zoomNamespace: zoomNamespace
                )
                .position(position(of: placement.slot))
            }

            if coordinator.isInstalling {
                HomeInstallingIcon(
                    metrics: metrics,
                    download: coordinator.downloadHelper
                )
                .position(position(of: model.displayedLayout.nextFreeSlot))
                .transition(.opacity)
            }
        }
        .frame(width: metrics.size.width * Double(pageCount), height: metrics.size.height, alignment: .topLeading)
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }

    /// The center of an icon with its name, at a slot on a page, in this
    /// layer's coordinates.
    private func position(of slot: HomeSlot) -> CGPoint {
        guard case .page(let page, let index) = slot else {
            return .zero
        }
        let cell = metrics.cellCenter(at: index)
        return CGPoint(x: Double(page) * metrics.size.width + cell.x, y: cell.y)
    }
}
