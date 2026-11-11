import AVFoundation
import XCTest
@testable import LiveContainerSwiftUI

@MainActor final class StoreIntegrationTests: XCTestCase {
    func testSwitcherGeometry() throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 375, height: 667),
                     CGSize(width: 393, height: 852), CGSize(width: 440, height: 956),
                     CGSize(width: 852, height: 393)] {
            let bounds = CGRect(origin: .zero, size: size)
            let card = RYSwitcherLayout.cardFrame(in: bounds)
            XCTAssertEqual(card.width / card.height, size.width / size.height, accuracy: 0.0001)
            XCTAssertEqual(card.height / size.height, 0.685, accuracy: 0.0001)
            for position in stride(from: CGFloat(0), through: 4, by: 0.125) {
                let front = RYSwitcherLayout.cardFrame(at: Int(position), position: position, in: bounds)
                let behind = RYSwitcherLayout.cardFrame(at: Int(position) + 1, position: position, in: bounds)
                XCTAssertLessThan(behind.minX, front.minX)
                XCTAssertLessThan(abs((behind.width / behind.height) / (size.width / size.height) - 1), 0.012)
            }
        }
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
