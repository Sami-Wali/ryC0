//
//  HomeScreenModel+Folders.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Folders, as on iOS: one opens over the Home Screen out of its icon, shows
/// its icons in pages of nine and its name above them, which edit mode lets
/// the person change, and goes back into its icon when the person taps
/// beside it or presses Home. Dragging makes and fills folders; that lives
/// with the rest of dragging, in the Editing extension.
extension HomeScreenModel {
    /// Opens a folder from its icon, in edit mode too, on its first page. One
    /// opened again while it's still going back into its icon comes out again
    /// from there.
    func openFolder(_ id: String) {
        guard !isSearching, displayedLayout.folders[id] != nil else {
            return
        }
        isFolderLetOut = false
        if openFolderID == id && !isFolderShown {
            withAnimation(HomeDesign.folderZoom) {
                isFolderShown = true
            } completion: { [weak self] in
                self?.folderDidSettle()
            }
            return
        }
        folderPage = 0
        isFolderSettled = false
        openFolderID = id
        isFolderShown = true
    }

    /// Notes that the open folder has finished zooming out of its icon.
    func folderDidSettle() {
        if isFolderShown {
            isFolderSettled = true
        }
    }

    /// Sends the open folder back into its icon. Its name, if being typed,
    /// is kept, or the folder's default name when it was cleared.
    func closeFolder() {
        guard let id = openFolderID, isFolderShown else {
            return
        }
        finishRenaming(id)
        isFolderSettled = false
        withAnimation(HomeDesign.folderZoom) {
            isFolderShown = false
        } completion: { [weak self] in
            // A drag that left the folder keeps its view until the drop.
            guard let self, !isFolderShown, drag?.origin.folder != id else {
                return
            }
            openFolderID = nil
        }
    }

    /// Renames a folder as its name is typed.
    func renameFolder(_ id: String, to name: String) {
        guard layout.folders[id] != nil, layout.folders[id]?.name != name else {
            return
        }
        layout.folders[id]?.name = name
        HomeLayoutStorage.save(layout)
    }

    /// Ends typing a folder's name, giving it the default name if it was left
    /// empty, as iOS does.
    func finishRenaming(_ id: String) {
        isEditingFolderName = false
        let name = layout.folders[id]?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty, layout.folders[id] != nil {
            renameFolder(id, to: HomeFolder.defaultName)
        }
    }

    /// Opens a folder in edit mode with its name ready to type, as Rename in
    /// the folder icon's long-press menu does, once the menu has closed.
    func renameFolderFromMenu(_ id: String) {
        Task { [weak self] in
            try? await Task.sleep(for: HomeDesign.menuCloseDuration)
            guard let self else {
                return
            }
            beginEditing()
            openFolder(id)
            isEditingFolderName = true
        }
    }

    /// Where the open folder's panel and icons go on this screen.
    var folderMetrics: HomeFolderMetrics? {
        metrics.map(HomeFolderMetrics.init)
    }

    /// The center of the icon at a position in the open folder, on screen.
    /// Positions on the folder's other pages sit beside the page showing.
    func folderIconCenter(at index: Int, metrics: HomeMetrics) -> CGPoint {
        let folderMetrics = HomeFolderMetrics(metrics)
        let page = index / HomeFolder.iconsPerPage - (folderPage ?? 0)
        let center = folderMetrics.iconCenter(at: index % HomeFolder.iconsPerPage)
        return CGPoint(x: center.x + Double(page) * folderMetrics.panel.width, y: center.y)
    }
}
