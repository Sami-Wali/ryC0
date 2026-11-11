//
//  AddToHomeScreenForm.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What Add to Home Screen asks before it makes the web clip, laid out like
/// Safari's own Add to Home Screen: the icon and its name at the top, with
/// what happens after Add under them, then whether the icon opens the app
/// with JIT and, for an app with several containers, which one it opens in.
struct AddToHomeScreenForm: View {
    @ObservedObject var app: LCAppModel
    /// The icon's style, as ryC0's Home Screen shows it.
    let style: GeneratedIconStyle
    @Binding var options: AppShortcutOptions
    /// Makes the web clip, as Add does.
    let add: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AddToHomeScreenHeader(app: app, style: style, name: $options.name)
                } footer: {
                    Text("ryc0.shortcut.nextSteps".loc)
                }

                AddToHomeScreenJITSection(app: app, opensWithJIT: $options.opensWithJIT)

                if app.uiContainers.count > 1 {
                    Section {
                        Picker("ryc0.shortcut.container".loc, selection: $options.containerFolderName) {
                            ForEach(app.uiContainers, id: \.folderName) { container in
                                Text(container.name)
                                    .tag(Optional(container.folderName))
                            }
                        }
                    }
                }
            }
            .navigationTitle("lc.appBanner.addToHomeScreen".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("lc.common.cancel".loc, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ryc0.shortcut.add".loc, action: add)
                }
            }
        }
    }

    private func cancel() {
        dismiss()
    }
}
