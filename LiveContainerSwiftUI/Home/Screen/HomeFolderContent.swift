//
//  HomeFolderContent.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An open folder, as iOS has it: the Home Screen blurred and darkened
/// behind it, the folder's name in large type, and its icons on a frosted
/// panel in the middle of the screen. It zooms out of the folder's icon when
/// it appears and back into it when it closes: the glass grows from the
/// icon's frame and corners to the panel's, each icon from its small place
/// on the folder's icon to its place on the panel, and the rest fades. A tap
/// beside the panel closes it.
///
/// HomeFolderZoom draws the icons while the folder zooms; the panel's own
/// icons, with their buttons and gestures, show once it is out. While an
/// icon dragged out of the folder is still moving, the panel stays, hidden,
/// since that icon's drag lives in it.
struct HomeFolderContent: View {
    /// The folder's id.
    let id: String
    /// The folder, as it shows now.
    let folder: HomeFolder
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    /// Whether the folder has zoomed out of its icon since it appeared.
    @State private var isOut = false

    var body: some View {
        let folderMetrics = HomeFolderMetrics(metrics)
        let panel = folderMetrics.panel
        let isShown = isOut && model.isFolderShown
        let showsPanel = model.isFolderSettled && model.isFolderShown
        // Back in its icon for an icon dragged out of it, the folder draws
        // nothing while it holds that drag.
        let isLetOut = model.isFolderLetOut && !model.isFolderShown
        // The folder's icon on screen, where it zooms out of and back into.
        let icon = model.iconFrame(of: .folder(id)) ?? metrics.iconFrame(around: CGPoint(x: panel.midX, y: panel.midY))
        let page = model.folderPage ?? 0
        let pageItems = Array(folder.items.dropFirst(page * HomeFolder.iconsPerPage).prefix(HomeFolder.iconsPerPage))

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(HomeDesign.folderDim))
                .opacity(isShown ? 1 : 0)
                .contentShape(.rect)
                .onTapGesture(perform: model.closeFolder)
                .accessibilityLabel("ryc0.home.closeFolder".loc)
                .accessibilityAddTraits(.isButton)

            HomeFolderTitle(id: id, name: folder.name, folderMetrics: folderMetrics, screenWidth: metrics.size.width)
                .opacity(isShown ? 1 : 0)

            // The glass, from the icon's frame and corners to the panel's, the
            // same frosted glass as the folder's icon, so it grows out of it.
            let glass = isShown ? panel : icon
            Color.clear
                .frame(width: glass.width, height: glass.height)
                .homeFolderGlass(cornerRadius: isShown ? folderMetrics.cornerRadius : metrics.iconCornerRadius)
                .position(x: glass.midX, y: glass.midY)
                .opacity(isLetOut ? 0 : 1)
                .allowsHitTesting(false)

            HomeFolderPanel(id: id, folder: folder, metrics: metrics, folderMetrics: folderMetrics, zoomNamespace: zoomNamespace)
                .position(x: panel.midX, y: panel.midY)
                .opacity(showsPanel ? 1 : 0)
                .animation(nil, value: showsPanel)
                // Not while it zooms, but always while an icon from it is dragged.
                .allowsHitTesting(showsPanel || model.drag != nil)

            HomeFolderZoom(items: pageItems, iconFrame: icon, isOut: isShown, metrics: metrics, folderMetrics: folderMetrics)
                .opacity(showsPanel || isLetOut ? 0 : 1)
                .animation(nil, value: showsPanel)
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .topLeading)
        // While it shows, VoiceOver stays in the folder, as it stays in search.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isShown ? .isModal : [])
        .onAppear(perform: zoomOut)
    }

    private func zoomOut() {
        withAnimation(HomeDesign.folderZoom) {
            isOut = true
        } completion: {
            model.folderDidSettle()
        }
    }
}
