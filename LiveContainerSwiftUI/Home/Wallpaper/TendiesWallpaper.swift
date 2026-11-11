import AVFoundation
import ImageIO
import UIKit

/// Reads embedded assets from Nugget's ZIP exports and recreates supported
/// declarative CAML scenes with public frameworks.
enum TendiesWallpaper {
    private static let movieExtensions: Set<String> = ["mov", "mp4", "m4v"]
    private static let frameExtensions: Set<String> = ["jpg", "jpeg", "jfif", "png", "heic", "heif", "webp", "tif", "tiff", "gif", "bmp"]
    private static let posterName = "Poster.jpg"
    private static let photoName = "Photo.jpg"
    private static let selectionKey = "RYC0MotionWallpaper"
    private static var storage: URL { .applicationSupportDirectory.appending(path: "MotionWallpaper", directoryHint: .isDirectory) }

    struct Asset: Sendable {
        let media: URL
        var folder: URL { media.deletingLastPathComponent() }
        var motion: URL? { media.lastPathComponent == photoName ? nil : media }
        var poster: UIImage? { UIImage(contentsOfFile: folder.appending(path: posterName).path)?.preparingForDisplay() }
    }

    @concurrent
    static func prepare(_ source: URL) async throws -> Asset {
        guard ["tendies", "zip"].contains(source.pathExtension.lowercased()) else {
            throw WallpaperError.unreadableTendies
        }
        let files = FileManager.default
        let isScoped = source.startAccessingSecurityScopedResource()
        defer { if isScoped { source.stopAccessingSecurityScopedResource() } }
        let work = files.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let expanded = work.appending(path: "Expanded", directoryHint: .isDirectory)
        let output = work.appending(path: "Ready", directoryHint: .isDirectory)
        try files.createDirectory(at: expanded, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: work) }
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        guard extractTendies(source.path, expanded.path) == 0 else { throw WallpaperError.unreadableTendies }

        let candidates = (files.enumerator(at: expanded, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles)?
            .allObjects as? [URL] ?? []).filter {
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }.sorted { $0.path < $1.path }
        let media: URL
        let poster: Data
        if let movie = try await prepareMovie(from: candidates, output: output) {
            media = movie
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: movie))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 2048, height: 2048)
            let frame = try await generator.image(at: .zero)
            guard let jpeg = UIImage(cgImage: frame.image).jpegData(compressionQuality: 0.9) else {
                throw WallpaperError.unreadableTendies
            }
            poster = jpeg
        } else if let layers = try prepareLayers(from: candidates, output: output) {
            (media, poster) = layers
        } else if let photo = preparePhoto(from: candidates) {
            media = output.appending(path: photoName)
            poster = photo
            try poster.write(to: media)
        } else {
            throw WallpaperError.unreadableTendies
        }
        try poster.write(to: output.appending(path: posterName), options: .atomic)

        try files.createDirectory(at: storage, withIntermediateDirectories: true)
        let folder = storage.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try files.moveItem(at: output, to: folder)
        return Asset(media: folder.appending(path: media.lastPathComponent))
    }

    private static func prepareLayers(from candidates: [URL], output: URL) throws -> (URL, Data)? {
        let files = FileManager.default
        let canvas = output.appending(path: "Layers", directoryHint: .isDirectory)
        let layers = candidates.filter { $0.lastPathComponent.lowercased() == "main.caml" }
        let groups = Dictionary(grouping: layers) { $0.deletingLastPathComponent().deletingLastPathComponent() }
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "~ipad" : "~iphone"
        let ordered = groups.keys.sorted {
            let first = $0.path.localizedCaseInsensitiveContains(device)
            let second = $1.path.localizedCaseInsensitiveContains(device)
            return first != second ? first : $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
        for group in ordered {
            try files.createDirectory(at: canvas, withIntermediateDirectories: true)
            for (index, document) in (groups[group] ?? []).prefix(6).enumerated() {
                let folder = document.deletingLastPathComponent()
                try files.copyItem(at: folder, to: canvas.appending(path: "\(index)-\(folder.lastPathComponent)"))
            }
            if let poster = TendiesLayerScene.make(in: canvas)?.poster() { return (canvas, poster) }
            try files.removeItem(at: canvas)
        }
        return nil
    }

    private static func preparePhoto(from candidates: [URL]) -> Data? {
        let photos = candidates.compactMap { url -> (URL, Double)? in
            let folders = url.deletingLastPathComponent().pathComponents.map { $0.lowercased() }
            let name = url.deletingPathExtension().lastPathComponent.lowercased()
            guard frameExtensions.contains(url.pathExtension.lowercased()),
                  folders.contains(where: { $0.hasPrefix("photos-descriptor") || $0.hasPrefix("video-descriptor")
                      || $0 == "com.apple.photosuiprivate.photosposterprovider" }),
                  !name.contains("thumbnail"), !name.contains("preview"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Double,
                  let height = properties[kCGImagePropertyPixelHeight] as? Double else { return nil }
            return (url, width * height)
        }
        for (url, _) in photos.sorted(by: { $0.1 > $1.1 }) {
            if let image = frame(at: url, maxSize: 2048), let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.9) {
                return jpeg
            }
        }
        return nil
    }

    private static func prepareMovie(from candidates: [URL], output: URL) async throws -> URL? {
        for candidate in candidates where movieExtensions.contains(candidate.pathExtension.lowercased()) {
            let asset = AVURLAsset(url: candidate)
            if (try? await asset.load(.isPlayable)) == true,
               let duration = try? await asset.load(.duration), duration.seconds.isFinite, duration.seconds > 0,
               let tracks = try? await asset.loadTracks(withMediaType: .video), !tracks.isEmpty {
                let movie = output.appending(path: "Animation.\(candidate.pathExtension.lowercased())")
                try FileManager.default.moveItem(at: candidate, to: movie)
                return movie
            }
        }

        let sequences = candidates
            .filter { $0.lastPathComponent.lowercased() == "main.caml" }
            .flatMap(SequenceReader.read)
        guard let sequence = sequences.max(by: { $0.frames.count < $1.frames.count }) else { return nil }
        let movie = output.appending(path: "Animation.mp4")
        try await encode(sequence, to: movie)
        return movie
    }

    static func load() -> Asset? {
        guard let selected = UserDefaults.standard.string(forKey: selectionKey), UUID(uuidString: selected) != nil,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: storage.appending(path: selected), includingPropertiesForKeys: nil),
              let media = items.first(where: {
                  $0.lastPathComponent == "Layers" || $0.lastPathComponent == photoName || movieExtensions.contains($0.pathExtension)
              }) else { return nil }
        return Asset(media: media)
    }

    static func select(_ asset: Asset?) {
        let previous = load()
        UserDefaults.standard.set(asset?.folder.lastPathComponent, forKey: selectionKey)
        if let previous, previous.media != asset?.media { discard(previous) }
    }

    static func discard(_ asset: Asset) {
        try? FileManager.default.removeItem(at: asset.folder)
    }

    private struct Sequence {
        let frames: [URL]
        let duration: Double
        let reverses: Bool
    }

    private final class SequenceReader: NSObject, XMLParserDelegate {
        private let folder: URL
        private var duration: Double?
        private var reverses = false
        private var frames: [URL] = []
        private var sequences: [Sequence] = []

        private init(folder: URL) { self.folder = folder }

        static func read(_ url: URL) -> [Sequence] {
            guard let parser = XMLParser(contentsOf: url) else { return [] }
            let reader = Self(folder: url.deletingLastPathComponent())
            parser.shouldResolveExternalEntities = false
            parser.delegate = reader
            return parser.parse() ? reader.sequences : []
        }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            if name == "animation", attributes["keyPath"] == "contents",
               let seconds = attributes["duration"].flatMap(Double.init), seconds.isFinite, seconds > 0, seconds <= 120 {
                duration = seconds
                reverses = attributes["autoreverses"] == "1"
                frames.removeAll()
            } else if name == "CGImage", duration != nil, let source = attributes["src"]?.removingPercentEncoding {
                let parts = source.split(separator: "/", omittingEmptySubsequences: false)
                guard !parts.contains(where: { $0.isEmpty || $0 == ".." || $0 == "." }),
                      frameExtensions.contains(URL(filePath: source).pathExtension.lowercased()) else { return }
                frames.append(folder.appending(path: source))
                if frames.count > 1000 { parser.abortParsing() }
            }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            guard name == "animation", let duration else { return }
            if frames.count > 1 {
                sequences.append(Sequence(frames: frames, duration: duration, reverses: reverses))
            }
            self.duration = nil
        }
    }

    private static func frame(at url: URL, maxSize: Int = 1440) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize
        ] as CFDictionary)
    }

    private static func encode(_ sequence: Sequence, to movie: URL) async throws {
        guard let first = frame(at: sequence.frames[0]) else { throw WallpaperError.unreadableTendies }
        let width = max(2, first.width / 2 * 2)
        let height = max(2, first.height / 2 * 2)
        let writer = try AVAssetWriter(outputURL: movie, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else { throw WallpaperError.unreadableTendies }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? WallpaperError.unreadableTendies }
        defer { if writer.status == .writing { writer.cancelWriting() } }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw WallpaperError.unreadableTendies }

        let frameDuration = max(1.0 / 60, sequence.duration / Double(sequence.frames.count))
        let urls = sequence.reverses ? sequence.frames + Array(sequence.frames.dropFirst().dropLast().reversed()) : sequence.frames
        for (index, url) in urls.enumerated() {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw writer.error ?? WallpaperError.unreadableTendies }
                try await Task.sleep(for: .milliseconds(5))
            }
            try autoreleasepool {
                var buffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
                      let buffer, let image = index == 0 ? first : frame(at: url) else {
                    throw WallpaperError.unreadableTendies
                }
                CVPixelBufferLockBaseAddress(buffer, [])
                let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
                context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                CVPixelBufferUnlockBaseAddress(buffer, [])
                let time = CMTime(seconds: Double(index) * frameDuration, preferredTimescale: 60_000)
                guard context != nil, adaptor.append(buffer, withPresentationTime: time) else {
                    throw writer.error ?? WallpaperError.unreadableTendies
                }
            }
        }
        writer.endSession(atSourceTime: CMTime(seconds: Double(urls.count) * frameDuration, preferredTimescale: 60_000))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? WallpaperError.unreadableTendies }
    }
}
