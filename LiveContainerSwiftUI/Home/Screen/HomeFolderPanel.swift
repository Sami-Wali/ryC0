//
//  HomeFolderPanel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What's on an open folder's glass: its icons in pages of nine, swiped
/// through one at a time, with page dots at the bottom when there is more
/// than one. Like the Home Screen's pages, the icons of every page sit in
/// one layer over the pages, so an icon dragged around in the folder stays
/// the same view and its drag goes on.
struct HomeFolderPanel: View {
    /// The folder's id.
    let id: String
    /// The folder, as it shows now.
    let folder: HomeFolder
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// Where things go in the open folder.
    let folderMetrics: HomeFolderMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let size = folderMetrics.panel.size
        let pageCount = folder.pageCount

        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(0..<pageCount, id: \.self) { _ in
                    Color.clear
                        .frame(width: size.width, height: size.height)
                }
            }
            .scrollTargetLayout()
            .overlay(alignment: .topLeading) {
                HomeFolderIcons(id: id, metrics: metrics, folderMetrics: folderMetrics, pageCount: pageCount, zoomNamespace: zoomNamespace)
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $model.folderPage)
        .scrollDisabled(model.drag != nil)
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .bottom) {
            if pageCount > 1 {
                HomeFolderPageDots(count: pageCount, current: model.folderPage ?? 0)
                    .padding(.bottom, HomeDesign.folderPageDotsInset)
            }
        }
        .clipShape(.rect(cornerRadius: folderMetrics.cornerRadius))
    }
}
