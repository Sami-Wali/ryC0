//
//  HomePresentations.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home Screen's dialogs, file picker and Add to Home Screen sheet.
struct HomePresentations: ViewModifier {
    @Environment(HomeScreenModel.self) private var model

    func body(content: Content) -> some View {
        @Bindable var model = model

        content
            .alert(
                model.removalTitle,
                isPresented: Binding<Bool>.isPresented(for: $model.pendingRemoval),
                presenting: model.pendingRemoval
            ) { app in
                HomeRemovalActions(app: app)
            } message: { app in
                if !app.uiContainers.isEmpty {
                    Text("ryc0.home.deleteKeepDataMessage".loc)
                }
            }
            .alert("lc.appList.installFromUrl".loc, isPresented: $model.isEnteringInstallURL) {
                TextField(text: $model.installURL, prompt: Text(verbatim: "https://")) {
                    Text("lc.appList.installFromUrl".loc)
                }
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Button("lc.common.install".loc, action: model.installFromEnteredURL)
                Button("lc.common.cancel".loc, role: .cancel) { }
            }
            .betterFileImporter(
                isPresented: $model.isChoosingIPA,
                types: [.ipa, .tipa],
                multiple: false,
                callback: model.installPickedFiles,
                onDismiss: model.filePickerDidClose
            )
            .appShortcutPresenter($model.shortcutRequest)
    }
}

extension View {
    func homePresentations() -> some View {
        modifier(HomePresentations())
    }
}
