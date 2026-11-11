//
//  WallpaperStore.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What the Home Screen shows behind its icons: the halo ryC0 comes
/// with, or a photo chosen in Settings > Wallpaper or from edit mode's add
/// button. It keeps a blurred copy for behind search, and whether Dark Mode
/// dims a photo. A photo is kept as a file the size of the largest screens;
/// either is loaded off the main thread at launch.
@MainActor
@Observable
final class WallpaperStore {
    /// The wallpaper, ready to draw. Nil only until it has loaded.
    private(set) var image: UIImage?

    /// The wallpaper blurred, shown behind search. Blurring it once here
    /// spares search a live blur of a full screen picture. Nil until it's
    /// made, a moment after the wallpaper shows.
    private(set) var blurredImage: UIImage?

    /// Whether the wallpaper is a photo the person chose, rather than the
    /// halo ryC0 comes with.
    private(set) var isCustom = false

    /// Whether a new wallpaper is being made from a photo.
    private(set) var isPreparing = false
    private(set) var motion: URL?

    /// Whether a photo is dimmed a little while Dark Mode is on, so the white
    /// names under the icons read over its bright parts, as on iOS. The halo
    /// is made dark already, so it's never dimmed.
    var dimsInDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(dimsInDarkMode, forKey: Self.dimmedKey)
        }
    }

    /// The defaults key `dimsInDarkMode` is saved under.
    private static let dimmedKey = "RYC0WallpaperDimmed"

    /// Counts the wallpapers set, and the times the halo is chosen again,
    /// so one that finishes loading or being made late can't replace a
    /// newer one.
    @ObservationIgnored private var generation = 0

    init() {
        dimsInDarkMode = UserDefaults.standard.object(forKey: Self.dimmedKey) as? Bool ?? true
        load()
    }

    /// Makes a photo's data the wallpaper. Throws when it isn't a picture
    /// iOS can read, leaving the wallpaper as it was. A photo or the halo
    /// chosen while it's being made wins, and this one is dropped.
    func set(_ data: Data) async throws {
        generation += 1
        let setting = generation
        isPreparing = true
        defer {
            // A photo chosen after this one is still being made.
            if setting == generation {
                isPreparing = false
            }
        }
        let (image, jpeg, blurred) = try await Task.detached(priority: .userInitiated) {
            let made = try WallpaperFile.make(data)
            return (made.image, made.jpeg, WallpaperFile.blurred(made.image))
        }.value
        // Use Default, or a photo chosen after this one, came later and wins.
        // Saving here on the main actor, with no wait after the check, keeps
        // the file in the order useDefault removes it in.
        guard setting == generation else {
            return
        }
        try WallpaperFile.save(jpeg)
        TendiesWallpaper.select(nil)
        motion = nil
        self.image = image
        blurredImage = blurred
        isCustom = true
    }

    func importTendies(_ url: URL) async throws {
        generation += 1
        let setting = generation
        isPreparing = true
        defer { if setting == generation { isPreparing = false } }
        let asset = try await TendiesWallpaper.prepare(url)
        let poster = await Task.detached(priority: .userInitiated) {
            asset.poster.map { ($0, WallpaperFile.blurred($0)) }
        }.value
        guard setting == generation, let poster else {
            TendiesWallpaper.discard(asset)
            if setting == generation { throw WallpaperError.unreadableTendies }
            return
        }
        TendiesWallpaper.select(asset)
        WallpaperFile.remove()
        image = poster.0
        blurredImage = poster.1
        motion = asset.motion
        isCustom = true
    }

    /// Goes back to the halo ryC0 comes with. The photo stays, dimmed as
    /// it was, until the halo has loaded and takes its place.
    func useDefault() {
        generation += 1
        isPreparing = false
        TendiesWallpaper.select(nil)
        WallpaperFile.remove()
        motion = nil
        load()
    }

    /// Loads the saved photo, or the halo when there's none: the iPad's
    /// square one on an iPad, which fills the screen either way up. The
    /// wallpaper shows as soon as it's decoded, and the blurred copy for
    /// search follows once it's made.
    private func load() {
        let loading = generation
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                let animation = TendiesWallpaper.load()
                let poster = animation?.poster
                let photo = poster ?? WallpaperFile.load()
                return (photo ?? WallpaperFile.loadDefault(isPad: isPad)).map { image in
                    (image, photo != nil, poster == nil ? nil : animation?.motion)
                }
            }.value
            // A wallpaper set meanwhile is newer than this one.
            guard loading == generation, let loaded else {
                return
            }
            image = loaded.0
            blurredImage = nil
            isCustom = loaded.1
            motion = loaded.2

            let blurred = await Task.detached(priority: .userInitiated) {
                WallpaperFile.blurred(loaded.0)
            }.value
            guard loading == generation else {
                return
            }
            blurredImage = blurred
        }
    }
}
