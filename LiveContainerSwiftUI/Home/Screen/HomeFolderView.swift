//
//  HomeFolderView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The folder open over the Home Screen, if one is. It shows from the moment
/// the folder opens until it has gone back into its icon, and, while an icon
/// dragged out of it is still moving, hidden until the drop, since that
/// icon's drag lives in it.
struct HomeFolderView: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        if let id = model.openFolderID, let folder = model.displayedLayout.folders[id] {
            HomeFolderContent(id: id, folder: folder, metrics: metrics, zoomNamespace: zoomNamespace)
                .id(id)
        }
    }
}
