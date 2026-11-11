//
//  WallpaperPicker.swift
//  LiveContainerSwiftUI
//

import PhotosUI
import SwiftUI

/// Lets a photo from the library become the Home Screen's wallpaper, and
/// says so when it can't. The wallpaper is made after the picker closes, in a
/// task of its own, so it's set even if the view that asked goes away.
struct WallpaperPicker: ViewModifier {
    /// Whether the photo picker shows.
    @Binding var isPresented: Bool

    @Environment(WallpaperStore.self) private var wallpaper
    @State private var selection: PhotosPickerItem?
    /// Why the last photo couldn't become the wallpaper.
    @State private var failure: String?
    @State private var isShowingFailure = false

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $selection, matching: .images, preferredItemEncoding: .current)
            .onChange(of: selection, selectionChanged)
            .alert("ryc0.wallpaper.failedTitle".loc, isPresented: $isShowingFailure, presenting: failure) { _ in
                Button("lc.common.ok".loc) { }
            } message: { failure in
                Text(failure)
            }
    }

    private func selectionChanged() {
        guard let item = selection else {
            return
        }
        selection = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw WallpaperError.unreadable
                }
                try await wallpaper.set(data)
            } catch {
                failure = error.localizedDescription
                isShowingFailure = true
            }
        }
    }
}

extension View {
    /// Shows the photo picker while `isPresented` is true, and makes the
    /// photo picked the Home Screen's wallpaper.
    func wallpaperPicker(isPresented: Binding<Bool>) -> some View {
        modifier(WallpaperPicker(isPresented: isPresented))
    }
}
