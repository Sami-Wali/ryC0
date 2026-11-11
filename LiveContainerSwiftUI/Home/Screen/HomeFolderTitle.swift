//
//  HomeFolderTitle.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An open folder's name, in large type above its panel, lined up with the
/// first column. In edit mode it's a field on glass the person can type a
/// new name into, with a button that clears it, as on iOS; a name left
/// empty goes back to the default.
struct HomeFolderTitle: View {
    /// The folder's id.
    let id: String
    /// The folder's name.
    let name: String
    /// Where things go in the open folder.
    let folderMetrics: HomeFolderMetrics
    /// The screen's width, which the title's line runs across.
    let screenWidth: Double

    @Environment(HomeScreenModel.self) private var model
    @FocusState private var isTyping: Bool

    var body: some View {
        // The name lines up with the first column. In edit mode its field runs
        // the panel's width, with the name inside it where it stood before.
        let isField = model.isEditing
        title
            .frame(width: isField ? folderMetrics.panel.width : folderMetrics.panel.width - folderMetrics.inset, alignment: .leading)
            // The title's baseline is what lines up with the panel below.
            .alignmentGuide(VerticalAlignment.bottom) { $0[.lastTextBaseline] }
            .frame(width: screenWidth, height: max(folderMetrics.titleBaseline, 0), alignment: .bottomLeading)
            .offset(x: isField ? folderMetrics.panel.minX : folderMetrics.titleLeading)
    }

    @ViewBuilder
    private var title: some View {
        if model.isEditing {
            TextField("ryc0.home.folderNameField".loc, text: nameBinding)
                .font(.system(size: HomeDesign.folderTitleSize, weight: .bold))
                .foregroundStyle(.white)
                .submitLabel(.done)
                .focused($isTyping)
                .onSubmit(finish)
                .padding(.leading, folderMetrics.titleLeading - folderMetrics.panel.minX)
                .padding(.trailing, HomeDesign.folderNameFieldPadding + HomeDesign.folderNameClearSize)
                .padding(.vertical, HomeDesign.folderNameFieldVerticalPadding)
                .homeFolderGlass(cornerRadius: HomeDesign.folderNameFieldCornerRadius)
                .overlay(alignment: .trailing) {
                    if !name.isEmpty {
                        Button("ryc0.home.clearFolderName".loc, systemImage: "xmark.circle.fill", action: clear)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: HomeDesign.minimumTouchSize, height: HomeDesign.minimumTouchSize)
                    }
                }
                .onAppear(perform: focusIfAsked)
                .onChange(of: model.isEditingFolderName) {
                    focusIfAsked()
                }
                .onChange(of: isTyping) { _, isTyping in
                    if !isTyping {
                        finish()
                    }
                }
        } else {
            Text(verbatim: name)
                .font(.system(size: HomeDesign.folderTitleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var nameBinding: Binding<String> {
        Binding {
            model.layout.folders[id]?.name ?? name
        } set: { newName in
            model.renameFolder(id, to: newName)
        }
    }

    /// Puts the cursor in the field when Rename asked for it.
    private func focusIfAsked() {
        if model.isEditingFolderName {
            isTyping = true
        }
    }

    private func clear() {
        model.renameFolder(id, to: "")
        isTyping = true
    }

    private func finish() {
        model.finishRenaming(id)
    }
}
