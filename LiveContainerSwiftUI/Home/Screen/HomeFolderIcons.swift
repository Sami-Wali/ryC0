//
//  HomeFolderIcons.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The icons of an open folder's pages, side by side, each at its place on
/// its page, with its name under it. Only the folder's page showing jiggles
/// in edit mode.
struct HomeFolderIcons: View {
    /// The folder's id.
    let id: String
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// Where things go in the open folder.
    let folderMetrics: HomeFolderMetrics
    /// How many pages wide the layer is.
    let pageCount: Int
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        let currentPage = model.folderPage ?? 0

        ZStack(alignment: .topLeading) {
            ForEach(model.folderPlacements(id)) { placement in
                HomeIconCell(
                    item: placement.item,
                    app: app(for: placement.item),
                    metrics: metrics,
                    showsLabel: true,
                    isLifted: placement.isLifted,
                    isOnScreen: page(of: placement.slot) == currentPage,
                    darkModeIcon: darkModeIcon,
                    zoomNamespace: zoomNamespace
                )
                .position(position(of: placement.slot))
            }
        }
        .frame(width: folderMetrics.panel.width * Double(pageCount), height: folderMetrics.panel.height, alignment: .topLeading)
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }

    /// The folder page a slot is on.
    private func page(of slot: HomeSlot) -> Int {
        guard case .folder(_, let index) = slot else {
            return 0
        }
        return index / HomeFolder.iconsPerPage
    }

    /// The center of an icon with its name, at a slot in the folder, in this
    /// layer's coordinates.
    private func position(of slot: HomeSlot) -> CGPoint {
        guard case .folder(_, let index) = slot else {
            return .zero
        }
        let cell = folderMetrics.localCellCenter(at: index % HomeFolder.iconsPerPage)
        return CGPoint(x: Double(page(of: slot)) * folderMetrics.panel.width + cell.x, y: cell.y)
    }
}
