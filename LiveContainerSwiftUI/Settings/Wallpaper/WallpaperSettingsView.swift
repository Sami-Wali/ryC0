//
//  WallpaperSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings > Wallpaper: the Home Screen's wallpaper, with a way to choose a
/// photo for it, dim it, or go back to the halo ryC0 comes with.
struct WallpaperSettingsView: View {
    @Environment(WallpaperStore.self) private var wallpaper
    @State private var isChoosing = false
    @State private var isChoosingTendies = false
    @State private var showFailure = false
    @State private var failure = ""

    var body: some View {
        @Bindable var wallpaper = wallpaper
        let hasPhoto = wallpaper.isCustom

        List {
            Section {
                WallpaperPreview()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            Section {
                Button("ryc0.settings.wallpaper.choose".loc, action: choose)
                    .disabled(wallpaper.isPreparing)
                Button("ryc0.wallpaper.importTendies".loc) { isChoosingTendies = true }
                    .disabled(wallpaper.isPreparing)
                if hasPhoto {
                    Toggle("ryc0.settings.wallpaper.dim".loc, isOn: $wallpaper.dimsInDarkMode)
                }
            } footer: {
                if hasPhoto {
                    Text("ryc0.settings.wallpaper.dimFooter".loc)
                }
            }

            if hasPhoto {
                Section {
                    Button("ryc0.settings.wallpaper.useDefault".loc, action: wallpaper.useDefault)
                }
            }
        }
        .navigationTitle("ryc0.settings.wallpaper".loc)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: hasPhoto)
        .wallpaperPicker(isPresented: $isChoosing)
        // Files providers can report Tendies as generic data instead of its custom type.
        .betterFileImporter(isPresented: $isChoosingTendies, types: [.data], callback: { urls in
            guard let url = urls.first else { return }
            Task {
                do {
                    try await wallpaper.importTendies(url)
                } catch {
                    failure = error.localizedDescription
                    showFailure = true
                }
            }
        }, onDismiss: { isChoosingTendies = false })
        .alert("ryc0.wallpaper.failedTitle".loc, isPresented: $showFailure) {
            Button("lc.common.ok".loc) {}
        } message: {
            Text(failure)
        }
    }

    private func choose() {
        isChoosing = true
    }
}
