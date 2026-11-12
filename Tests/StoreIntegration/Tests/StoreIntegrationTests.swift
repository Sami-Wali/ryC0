import AVFoundation
import UIKit
import XCTest
@testable import LiveContainerSwiftUI

@MainActor final class StoreIntegrationTests: XCTestCase {
    func testClockSingleTapAndDoubleTapAreExclusive() async throws {
        let clock = RYClockTapAction()
        var home = 0, switcher = 0
        let tap = { clock.tap(home: { home += 1 }, switcher: { switcher += 1 }) }
        tap()
        XCTAssertEqual(home, 0)
        try await Task.sleep(for: .milliseconds(360))
        XCTAssertEqual(home, 1)
        XCTAssertEqual(switcher, 0)

        tap()
        try await Task.sleep(for: .milliseconds(80))
        tap()
        XCTAssertEqual(switcher, 1)
        try await Task.sleep(for: .milliseconds(360))
        XCTAssertEqual(home, 1, "A double tap must never also return Home")

        tap()
        clock.cancel()
        try await Task.sleep(for: .milliseconds(360))
        XCTAssertEqual(home, 1, "Leaving the guest cancels a pending clock action")
        XCTAssertEqual(switcher, 1)
    }

    private func nativeSwitcher(count: Int, fromApp: Bool) -> (UIWindow, RYNativeAppSwitcher) {
        let controller = RYNativeAppSwitcher()
        controller.items = (0..<count).map { index in
            let item = RYNativeSwitcherItem()
            item.identifier = "native-fixture-\(index)"
            item.bundleIdentifier = "com.ry0.native-fixture.\(index)"
            item.name = "Native Fixture \(index + 1)"
            item.icon = UIImage(systemName: "app.fill")
            item.snapshot = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 522)).image { context in
                UIColor.darkGray.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 240, height: 522))
            }
            return item
        }
        controller.entryIdentifier = fromApp ? controller.items.first?.identifier : nil
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return (window, controller)
    }

    func testNativeSwitcherFromHomeFocusesFirstCard() async throws {
        let (window, controller) = nativeSwitcher(count: 5, fromApp: false)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(controller.usesNativeDeck)
        XCTAssertEqual(controller.focusedIdentifier, "native-fixture-0")
        let frame = try XCTUnwrap(controller.cardFrames["native-fixture-0"]?.cgRectValue)
        XCTAssertEqual(frame.width / controller.view.bounds.width, 0.685, accuracy: 0.015)
        XCTAssertEqual(frame.midX / controller.view.bounds.width, 0.5, accuracy: 0.02)
    }

    func testNativeSwitcherFromAppFocusesSecondCard() async throws {
        let (window, controller) = nativeSwitcher(count: 5, fromApp: true)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(controller.usesNativeDeck)
        XCTAssertEqual(controller.focusedIdentifier, "native-fixture-1")
        let current = try XCTUnwrap(controller.cardFrames["native-fixture-0"]?.cgRectValue)
        let previous = try XCTUnwrap(controller.cardFrames["native-fixture-1"]?.cgRectValue)
        XCTAssertGreaterThan(current.minX, previous.midX)
        XCTAssertLessThan(current.minX, controller.view.bounds.maxX)
    }

    func testNativeSwitcherSingleCardStaysInFocus() async throws {
        let (window, controller) = nativeSwitcher(count: 1, fromApp: true)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(controller.usesNativeDeck)
        XCTAssertEqual(controller.focusedIdentifier, "native-fixture-0")
        XCTAssertEqual(controller.cardFrames.count, 1)
    }

    func testDockPagesAndLegacyStoreRemoval() throws {
        let saved = """
        {"pages":[["app:a","store","folder:sample"]],"dock":["settings","app:b","app:c","app:d","app:e","app:f"],
         "folders":{"sample":{"name":"Sample","items":["store","app:g"]}}}
        """
        var layout = try JSONDecoder().decode(HomeLayout.self, from: Data(saved.utf8))
        layout.reconcile(withAppKeys: ["a", "b", "c", "d", "e", "f", "g"])
        XCTAssertEqual(layout.dock, [.settings, .app("b"), .app("c"), .app("d"), .app("e"), .app("f")])
        XCTAssertEqual(layout.folders["sample"]?.items, [.app("g")])
        XCTAssertEqual(layout.dockRange(on: 0).count, HomeLayout.dockIconsPerPage)
        XCTAssertEqual(layout.slot(of: .app("f")), .dock(5))
        XCTAssertEqual(try JSONDecoder().decode(HomeLayout.self, from: JSONEncoder().encode(layout)), layout)
    }

    func testNuggetFrameSequenceMakesPlayableMovie() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Motion", withExtension: "tendies"))
        let asset = try await TendiesWallpaper.prepare(fixture)
        defer { TendiesWallpaper.discard(asset) }
        XCTAssertNotNil(asset.poster)
        let movie = AVURLAsset(url: asset.media)
        let duration = try await movie.load(.duration)
        XCTAssertGreaterThan(duration.seconds, 0.2)
    }

    func testProceduralTendiesLoadsImageAndRotation() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LayerMotion", withExtension: "tendies"))
        let asset = try await TendiesWallpaper.prepare(fixture)
        defer { TendiesWallpaper.discard(asset) }
        XCTAssertEqual(asset.media.lastPathComponent, "Layers")
        XCTAssertNotNil(asset.poster)
        let scene = try XCTUnwrap(TendiesLayerScene.make(in: asset.media))
        let imageLayer = try XCTUnwrap(scene.layer.sublayers?.first?.sublayers?.first)
        XCTAssertNotNil(imageLayer.contents)
        let key = try XCTUnwrap(imageLayer.animationKeys()?.first)
        let animation = try XCTUnwrap(imageLayer.animation(forKey: key) as? CAKeyframeAnimation)
        XCTAssertEqual(animation.keyPath, "transform.rotation.z")
    }

    func testRejectsWallpaperPathTraversal() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Unsafe", withExtension: "tendies"))
        do {
            let asset = try await TendiesWallpaper.prepare(fixture)
            TendiesWallpaper.discard(asset)
            XCTFail("Accepted a path escaping the wallpaper archive")
        } catch WallpaperError.unreadableTendies {}
    }
}
