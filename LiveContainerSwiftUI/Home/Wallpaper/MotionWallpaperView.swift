import AVFoundation
import CoreMotion
import SwiftUI

struct MotionWallpaperView: View {
    let movie: URL
    let plays: Bool

    var body: some View {
        if movie.lastPathComponent == "Layers" {
            LayerWallpaperView(directory: movie, plays: plays)
        } else {
            VideoWallpaperView(movie: movie, plays: plays)
        }
    }
}

private struct VideoWallpaperView: UIViewRepresentable {
    let movie: URL
    let plays: Bool

    func makeUIView(context: Context) -> Surface {
        Surface(movie: movie)
    }

    func updateUIView(_ view: Surface, context: Context) { view.plays = plays }

    static func dismantleUIView(_ view: Surface, coordinator: Void) {
        view.plays = false
    }

    final class Surface: UIView {
        private let player = AVQueuePlayer()
        private let looper: AVPlayerLooper
        var plays = false { didSet { updatePlayback() } }

        override class var layerClass: AnyClass { AVPlayerLayer.self }

        init(movie: URL) {
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: movie))
            super.init(frame: .zero)
            player.isMuted = true
            let playerLayer = layer as! AVPlayerLayer
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.player = player
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updatePlayback()
        }

        private func updatePlayback() {
            if plays && window != nil { player.play() }
            else { player.pause() }
        }
    }
}


private struct LayerWallpaperView: UIViewRepresentable {
    let directory: URL
    let plays: Bool

    func makeUIView(context: Context) -> Surface {
        Surface(scene: TendiesLayerScene.make(in: directory))
    }

    func updateUIView(_ view: Surface, context: Context) { view.plays = plays }

    static func dismantleUIView(_ view: Surface, coordinator: Void) {
        view.plays = false
    }

    final class Surface: UIView {
        private let scene: TendiesLayerScene.Scene?
        private var isPlaying = false
        private var motion: CMMotionManager?
        private var referenceAttitude: CMAttitude?
        var plays = false { didSet { updatePlayback() } }

        init(scene: TendiesLayerScene.Scene?) {
            self.scene = scene
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            clipsToBounds = true
            if let scene { layer.addSublayer(scene.layer) }
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updatePlayback()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let scene, bounds.width > 0, bounds.height > 0 else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let scale = max(bounds.width / scene.size.width, bounds.height / scene.size.height)
            scene.layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            scene.layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
            CATransaction.commit()
        }

        private func updatePlayback() {
            let shouldPlay = plays && window != nil
            guard let scene, shouldPlay != isPlaying else { return }
            isPlaying = shouldPlay
            let canvas = scene.layer
            let now = CACurrentMediaTime()
            if shouldPlay {
                // Restore the render server's animations with their original
                // start times before continuing the paused canvas clock.
                scene.restoreAnimations()
                canvas.beginTime = layer.convertTime(now, from: nil) - canvas.timeOffset
                canvas.timeOffset = 0
                canvas.speed = 1
                if scene.usesDeviceMotion { startMotion() }
            } else {
                motion?.stopDeviceMotionUpdates()
                let pausedAt = canvas.convertTime(now, from: nil)
                canvas.speed = 0
                canvas.timeOffset = pausedAt
            }
        }

        private func startMotion() {
            let manager = motion ?? CMMotionManager()
            motion = manager
            guard manager.isDeviceMotionAvailable else { return }
            manager.deviceMotionUpdateInterval = 1.0 / 30
            manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                MainActor.assumeIsolated {
                    guard let self, self.isPlaying, let attitude = data?.attitude else { return }
                    if let referenceAttitude = self.referenceAttitude {
                        attitude.multiply(byInverseOf: referenceAttitude)
                        let tiltRange = Double.pi / 6
                        self.scene?.updateTilt(x: attitude.roll / tiltRange, y: attitude.pitch / tiltRange)
                    } else {
                        self.referenceAttitude = attitude
                    }
                }
            }
        }
    }
}
