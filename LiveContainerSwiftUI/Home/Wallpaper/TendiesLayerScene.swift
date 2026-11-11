import ImageIO
import UIKit

/// Reads the declarative Core Animation subset used by many custom .ca
/// wallpapers. Unknown properties, scripts and system providers are ignored.
enum TendiesLayerScene {
    struct Scene {
        let layer: CALayer
        let size: CGSize
        fileprivate let animations: [LayerAnimation]
        fileprivate let parallax: [Parallax]

        var usesDeviceMotion: Bool { !parallax.isEmpty }

        func restoreAnimations() {
            for item in animations {
                item.layer.add(item.animation, forKey: item.key)
            }
        }

        func updateTilt(x: Double, y: Double) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for effect in parallax {
                effect.update(tilt: effect.axis == "x" ? x : y)
            }
            CATransaction.commit()
        }

        func poster() -> Data? {
            let scale = min(1, 1024 / max(size.width, size.height))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let dimensions = CGSize(width: size.width * scale, height: size.height * scale)
            return UIGraphicsImageRenderer(size: dimensions, format: format).jpegData(withCompressionQuality: 0.88) { context in
                context.cgContext.scaleBy(x: scale, y: scale)
                layer.render(in: context.cgContext)
            }
        }
    }

    fileprivate struct LayerAnimation {
        let layer: CALayer
        let key: String
        let animation: CAPropertyAnimation
    }

    fileprivate struct Parallax {
        enum Property: String {
            case positionX = "position.x", positionY = "position.y"
            case translationX = "transform.translation.x", translationY = "transform.translation.y"
            case rotationX = "transform.rotation.x", rotationY = "transform.rotation.y", rotationZ = "transform.rotation.z"
        }

        let layer: CALayer
        let axis: String
        let property: Property
        let minimum: Double
        let maximum: Double

        func update(tilt: Double) {
            let fraction = (min(max(tilt, -1), 1) + 1) / 2
            let value = minimum + fraction * (maximum - minimum)
            switch property {
            case .positionX: layer.position.x = value
            case .positionY: layer.position.y = value
            default: layer.setValue(value, forKeyPath: property.rawValue)
            }
        }
    }

    private static let supportedLayers: Set<String> = [
        "CALayer", "CATransformLayer", "CAEmitterLayer", "CAGradientLayer", "CAShapeLayer", "CAReplicatorLayer", "CATextLayer"
    ]
    private static let animatedProperties: Set<String> = [
        "opacity", "position", "position.x", "position.y",
        "transform.rotation", "transform.rotation.z", "transform.scale", "transform.scale.x",
        "transform.scale.y", "transform.translation.x", "transform.translation.y", "transform.translation.z",
        "transform.rotation.x", "transform.rotation.y", "transform.scale.z", "cornerRadius", "borderWidth", "zPosition",
        "bounds.size.width", "bounds.size.height", "strokeStart", "strokeEnd", "lineWidth",
        "backgroundColor", "borderColor", "fillColor", "strokeColor", "transform"
    ]

    static func make(in directory: URL) -> Scene? {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var layers: [(CALayer, Bool)] = []
        var hasContent = false
        var animations: [LayerAnimation] = []
        var parallax: [Parallax] = []
        var homeStates: [(Node, [String: CALayer])] = []
        var hasParticles = false
        for folder in folders.sorted(by: { (layerOrder($0), $0.lastPathComponent) < (layerOrder($1), $1.lastPathComponent) }) {
            var namedLayers: [String: CALayer] = [:]
            var layerAnimations: [LayerAnimation] = []
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            guard let entry = files.first(where: { $0.lastPathComponent.lowercased() == "main.caml" }),
                  let document = Reader.read(entry),
                  let root = document.children.first(where: { supportedLayers.contains($0.name) }),
                  let layer = buildLayer(root, folder: folder, depth: 0, copies: 64,
                                         namedLayers: &namedLayers, animations: &layerAnimations),
                  layer.bounds.width > 0, layer.bounds.height > 0 else { continue }
            layers.append((layer, folder.lastPathComponent.localizedCaseInsensitiveContains("background")))
            hasContent = hasContent || drawsContent(layer)
            hasParticles = hasParticles || emitsParticles(layer)
            animations.append(contentsOf: layerAnimations)
            parallax.append(contentsOf: readParallax(root, layers: namedLayers))
            homeStates.append((root, namedLayers))
        }
        // A continuous wallpaper already has authored playback geometry.
        // PosterBoard's unlock pose can zoom that entire scene as it switches
        // from the lock screen to the iOS Home Screen.
        if animations.isEmpty && parallax.isEmpty && !hasParticles {
            for (root, namedLayers) in homeStates { applyHomeState(root, layers: namedLayers) }
        }
        guard hasContent,
              let primary = layers.first(where: { $0.1 }) ?? layers.first else { return nil }
        let canvas = CALayer()
        canvas.bounds = CGRect(origin: .zero, size: primary.0.bounds.size)
        canvas.backgroundColor = UIColor.black.cgColor
        canvas.masksToBounds = true
        canvas.speed = 0
        canvas.timeOffset = 1
        for (layer, _) in layers {
            layer.position = CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY)
            canvas.addSublayer(layer)
        }
        let scene = Scene(layer: canvas, size: canvas.bounds.size, animations: animations, parallax: parallax)
        scene.restoreAnimations()
        return scene
    }

    private static func layerOrder(_ folder: URL) -> Int {
        let name = folder.lastPathComponent.lowercased()
        if name.contains("background") { return 0 }
        if name.contains("foreground") { return 2 }
        return 1
    }

    private static func drawsContent(_ layer: CALayer) -> Bool {
        if layer.contents != nil || (layer.backgroundColor?.alpha ?? 0) > 0
            || (layer.borderWidth > 0 && (layer.borderColor?.alpha ?? 0) > 0)
            || (layer as? CAShapeLayer)?.path != nil || (layer as? CAGradientLayer)?.colors != nil
            || (layer as? CATextLayer)?.string != nil || (layer as? CAEmitterLayer)?.emitterCells?.isEmpty == false {
            return true
        }
        return layer.sublayers?.contains(where: drawsContent) ?? false
    }

    private static func emitsParticles(_ layer: CALayer) -> Bool {
        if let emitter = layer as? CAEmitterLayer, emitter.birthRate > 0, emitter.emitterCells?.isEmpty == false {
            return true
        }
        return layer.sublayers?.contains(where: emitsParticles) ?? false
    }

    private static func readParallax(_ root: Node, layers: [String: CALayer]) -> [Parallax] {
        (root.child("style")?.child("wallpaperParallaxGroups")?.children ?? []).prefix(64).compactMap { group in
            guard group.name == "NSDictionary", let name = group.value("layerName"), let layer = layers[name],
                  let axis = group.value("axis"), axis == "x" || axis == "y",
                  let path = group.value("keyPath"), let property = Parallax.Property(rawValue: path),
                  let minimum = group.value("mapMinTo").flatMap(Double.init),
                  let maximum = group.value("mapMaxTo").flatMap(Double.init),
                  minimum.isFinite, maximum.isFinite, abs(minimum) <= 32768, abs(maximum) <= 32768 else { return nil }
            return Parallax(layer: layer, axis: axis, property: property, minimum: minimum, maximum: maximum)
        }
    }

    private static func applyHomeState(_ root: Node, layers: [String: CALayer]) {
        // CAML authors can override the base geometry for the unlocked view.
        let states = root.child("states")?.children ?? []
        let state = states.first { ["Home", "Home PortraitUp Light"].contains($0.attributes["name"] ?? "") }
            ?? states.first { ["Unlock", "Unlocked"].contains($0.attributes["name"] ?? "") }
        for setting in state?.child("elements")?.children ?? [] where setting.name == "LKStateSetValue" {
            guard let id = setting.attributes["targetId"], let layer = layers[id],
                  let path = setting.attributes["keyPath"], let raw = setting.value("value") else { continue }
            if path == "backgroundColor" { layer.backgroundColor = color(raw); continue }
            if path == "position", let position = point(raw) { layer.position = position; continue }
            guard let value = Double(raw), value.isFinite, abs(value) <= 32768 else { continue }
            switch path {
            case "position.x": layer.position.x = value
            case "position.y": layer.position.y = value
            case "bounds.size.width": layer.bounds.size.width = min(max(0, value), 16384)
            case "bounds.size.height": layer.bounds.size.height = min(max(0, value), 16384)
            case "opacity": layer.opacity = Float(min(max(0, value), 1))
            case "cornerRadius": layer.cornerRadius = min(max(0, value), 1024)
            case "hidden": layer.isHidden = value != 0
            case "transform.scale.xy":
                layer.setValue(value, forKeyPath: "transform.scale.x")
                layer.setValue(value, forKeyPath: "transform.scale.y")
            case "transform.scale", "transform.scale.x", "transform.scale.y", "transform.scale.z",
                 "transform.rotation", "transform.rotation.x", "transform.rotation.y", "transform.rotation.z",
                 "transform.translation.x", "transform.translation.y", "transform.translation.z":
                layer.setValue(value, forKeyPath: path)
            default: break
            }
        }
    }

    private static func buildLayer(_ node: Node, folder: URL, depth: Int, copies: Int,
                                   namedLayers: inout [String: CALayer], animations: inout [LayerAnimation]) -> CALayer? {
        guard depth < 24, supportedLayers.contains(node.name) else { return nil }
        let a = node.attributes
        let layer: CALayer
        var childCopies = copies
        switch node.name {
        case "CATransformLayer": layer = CATransformLayer()
        case "CAGradientLayer": layer = gradient(node)
        case "CAShapeLayer": layer = shape(node)
        case "CATextLayer": layer = text(node)
        case "CAReplicatorLayer":
            let replicator = CAReplicatorLayer()
            replicator.instanceCount = Int(bounded(a["instanceCount"], default: 1, range: 1...CGFloat(copies)))
            childCopies /= replicator.instanceCount
            replicator.instanceDelay = bounded(a["instanceDelay"], default: 0, range: 0...10)
            replicator.instanceTransform = transform(a["instanceTransform"])
            if let color = color(a["instanceColor"]) { replicator.instanceColor = color }
            replicator.instanceAlphaOffset = Float(bounded(a["instanceAlphaOffset"], default: 0, range: -1...1))
            replicator.instanceRedOffset = Float(bounded(a["instanceRedOffset"], default: 0, range: -1...1))
            replicator.instanceGreenOffset = Float(bounded(a["instanceGreenOffset"], default: 0, range: -1...1))
            replicator.instanceBlueOffset = Float(bounded(a["instanceBlueOffset"], default: 0, range: -1...1))
            replicator.preservesDepth = a["preservesDepth"] == "1"
            layer = replicator
        case "CAEmitterLayer":
            let emitter = CAEmitterLayer()
            emitter.emitterPosition = point(a["emitterPosition"]) ?? .zero
            if let size = point(a["emitterSize"]) { emitter.emitterSize = CGSize(width: size.x, height: size.y) }
            if let shape = a["emitterShape"], ["point", "line", "rectangle", "cuboid", "circle", "sphere"].contains(shape) {
                emitter.emitterShape = CAEmitterLayerEmitterShape(rawValue: shape)
            }
            if let mode = a["emitterMode"], ["points", "outline", "surface", "volume"].contains(mode) {
                emitter.emitterMode = CAEmitterLayerEmitterMode(rawValue: mode)
            }
            emitter.seed = UInt32(bounded(a["seed"], default: 0, range: 0...CGFloat(UInt32.max)))
            emitter.birthRate = Float(bounded(a["birthRate"], default: 1, range: 0...4))
            let lifetimeMultiplier = bounded(a["lifetime"], default: 1, range: 0...2)
            emitter.lifetime = Float(lifetimeMultiplier)
            emitter.velocity = Float(bounded(a["velocity"], default: 1, range: 0...5))
            emitter.speed = Float(bounded(a["speed"], default: 1, range: 0...8))
            emitter.preservesDepth = a["preservesDepth"] == "1"
            let cells = node.child("emitterCells")?.children.prefix(16).compactMap { cell in
                emitterCell(cell, folder: folder, lifetimeMultiplier: lifetimeMultiplier)
            } ?? []
            emitter.emitterCells = cells
            layer = emitter
        default: layer = CALayer()
        }
        if let name = a["name"] {
            layer.name = name
            if namedLayers[name] == nil { namedLayers[name] = layer }
        }
        if let id = a["id"], namedLayers[id] == nil { namedLayers[id] = layer }
        let rect = numbers(a["bounds"])
        if rect.count == 4, rect[2] >= 0, rect[3] >= 0, rect[2] <= 16384, rect[3] <= 16384 {
            layer.bounds = CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3])
        }
        if let position = point(a["position"]) { layer.position = position }
        if let anchor = point(a["anchorPoint"]) { layer.anchorPoint = anchor }
        layer.zPosition = bounded(a["zPosition"], default: 0, range: -16384...16384)
        layer.backgroundColor = color(node, "backgroundColor")
        if let border = color(node, "borderColor") { layer.borderColor = border }
        layer.borderWidth = bounded(a["borderWidth"], default: 0, range: 0...1024)
        layer.opacity = Float(bounded(a["opacity"], default: 1, range: 0...1))
        layer.isHidden = a["hidden"] == "1"
        layer.masksToBounds = a["masksToBounds"] == "1"
        layer.cornerRadius = bounded(a["cornerRadius"], default: 0, range: 0...1024)
        layer.transform = transform(a["transform"])
        layer.sublayerTransform = transform(a["sublayerTransform"])
        if a["contentsGravity"] == "resizeAspectFill" { layer.contentsGravity = .resizeAspectFill }
        if a["contentsGravity"] == "resizeAspect" { layer.contentsGravity = .resizeAspect }
        if let mask = node.child("mask")?.children.first {
            layer.mask = buildLayer(mask, folder: folder, depth: depth + 1, copies: childCopies,
                                    namedLayers: &namedLayers, animations: &animations)
        }
        if let image = image(node.child("contents"), folder: folder) { layer.contents = image }
        for child in node.child("sublayers")?.children ?? [] {
            if let sublayer = buildLayer(child, folder: folder, depth: depth + 1, copies: childCopies,
                                         namedLayers: &namedLayers, animations: &animations) {
                layer.addSublayer(sublayer)
            }
        }
        for (index, item) in (node.child("animations")?.children ?? []).enumerated() {
            if let animation = animation(item) {
                animations.append(LayerAnimation(layer: layer, key: "tendies-\(index)", animation: animation))
            }
        }
        return layer
    }

    private static func gradient(_ node: Node) -> CAGradientLayer {
        let layer = CAGradientLayer()
        let colors = (node.child("colors")?.children ?? []).prefix(64).compactMap(color)
        if colors.count >= 2 { layer.colors = colors }
        let locations = (node.child("locations")?.children ?? []).prefix(64).compactMap {
            $0.attributes["value"].flatMap(Double.init)
        }
        if locations.count == colors.count, locations.allSatisfy({ (0...1).contains($0) }), locations == locations.sorted() {
            layer.locations = locations.map { NSNumber(value: $0) }
        }
        if let start = point(node.attributes["startPoint"]) { layer.startPoint = start }
        if let end = point(node.attributes["endPoint"]) { layer.endPoint = end }
        switch node.value("type") ?? node.attributes["type"] {
        case "radial": layer.type = .radial
        case "conic": layer.type = .conic
        default: break
        }
        return layer
    }

    private static func shape(_ node: Node) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let a = node.attributes
        layer.path = shapePath(a["path"] ?? node.value("path"))
        if let fill = color(node, "fillColor") { layer.fillColor = fill }
        layer.strokeColor = color(node, "strokeColor")
        layer.lineWidth = bounded(a["lineWidth"], default: 1, range: 0...1024)
        if let cap = a["lineCap"], ["butt", "round", "square"].contains(cap) { layer.lineCap = CAShapeLayerLineCap(rawValue: cap) }
        if let join = a["lineJoin"], ["miter", "round", "bevel"].contains(join) { layer.lineJoin = CAShapeLayerLineJoin(rawValue: join) }
        if a["fillRule"] == "even-odd" { layer.fillRule = .evenOdd }
        layer.strokeStart = bounded(a["strokeStart"], default: 0, range: 0...1)
        layer.strokeEnd = bounded(a["strokeEnd"], default: 1, range: 0...1)
        return layer
    }

    private static func shapePath(_ raw: String?) -> CGPath? {
        guard let raw else { return nil }
        let path = CGMutablePath()
        var coordinates: [CGFloat] = []
        for token in raw.split(whereSeparator: { $0.isWhitespace || $0 == "," }) {
            if let number = Double(token), number.isFinite, abs(number) <= 131072, coordinates.count < 6 {
                coordinates.append(number)
                continue
            }
            switch (token, coordinates.count) {
            case ("m", 2): path.move(to: CGPoint(x: coordinates[0], y: coordinates[1]))
            case ("l", 2): path.addLine(to: CGPoint(x: coordinates[0], y: coordinates[1]))
            case ("q", 4):
                path.addQuadCurve(to: CGPoint(x: coordinates[2], y: coordinates[3]),
                                  control: CGPoint(x: coordinates[0], y: coordinates[1]))
            case ("c", 6):
                path.addCurve(to: CGPoint(x: coordinates[4], y: coordinates[5]),
                              control1: CGPoint(x: coordinates[0], y: coordinates[1]),
                              control2: CGPoint(x: coordinates[2], y: coordinates[3]))
            case ("h", 0): path.closeSubpath()
            default: return nil
            }
            coordinates.removeAll(keepingCapacity: true)
        }
        return path.isEmpty || !coordinates.isEmpty ? nil : path
    }

    private static func text(_ node: Node) -> CATextLayer {
        let layer = CATextLayer()
        let a = node.attributes
        if let string = a["string"] ?? node.value("string"), !string.isEmpty { layer.string = String(string.prefix(2048)) }
        layer.fontSize = bounded(a["fontSize"], default: 16, range: 1...512)
        if let name = a["font"] ?? node.value("font"), let font = UIFont(name: name, size: layer.fontSize) { layer.font = font.fontName as CFString }
        if let foreground = color(node, "foregroundColor") { layer.foregroundColor = foreground }
        if let alignment = a["alignmentMode"], ["natural", "left", "right", "center", "justified"].contains(alignment) {
            layer.alignmentMode = CATextLayerAlignmentMode(rawValue: alignment)
        }
        layer.isWrapped = a["wrapped"] == "1"
        layer.contentsScale = 2
        return layer
    }

    private static func transform(_ raw: String?) -> CATransform3D {
        var result = CATransform3DIdentity
        for operation in (raw ?? "").split(separator: ")").prefix(16) {
            let parts = operation.split(separator: "(", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let args = numbers(String(parts[1]).replacingOccurrences(of: "deg", with: ""))
            switch (name, args.count) {
            case ("scale", 3): result = CATransform3DScale(result, args[0], args[1], args[2])
            case ("translate", 3): result = CATransform3DTranslate(result, args[0], args[1], args[2])
            case ("rotate", 1): result = CATransform3DRotate(result, args[0] * .pi / 180, 0, 0, 1)
            case ("rotate", 4) where args[1...3].contains(where: { $0 != 0 }):
                result = CATransform3DRotate(result, args[0] * .pi / 180, args[1], args[2], args[3])
            case ("shearXY", 2):
                var shear = CATransform3DIdentity
                shear.m12 = args[0]
                shear.m21 = args[1]
                result = CATransform3DConcat(result, shear)
            default: break
            }
        }
        return result
    }

    private static func emitterCell(_ node: Node, folder: URL, lifetimeMultiplier: CGFloat) -> CAEmitterCell? {
        let a = node.attributes
        guard node.name == "CAEmitterCell", let image = image(node.child("contents"), folder: folder) else { return nil }
        let cell = CAEmitterCell()
        cell.contents = image
        cell.contentsScale = bounded(a["contentsScale"], default: 1, range: 0.25...64)
        let rect = numbers(a["contentsRect"])
        if rect.count == 4, rect.allSatisfy({ (0...1).contains($0) }),
           rect[0] + rect[2] <= 1, rect[1] + rect[3] <= 1 {
            cell.contentsRect = CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3])
        }
        cell.birthRate = Float(bounded(a["birthRate"], default: 1, range: 0...25))
        // The emitter applies its multiplier to the cell's lifetime and range.
        // Bound the effective lifetimes, even when the source uses a long cell lifetime.
        let divisor = max(lifetimeMultiplier, 0.01)
        cell.lifetime = Float(bounded(a["lifetime"], default: 2, range: 0...min(120, 15 / divisor)))
        cell.lifetimeRange = Float(bounded(a["lifetimeRange"], default: 0, range: 0...min(30, 5 / divisor)))
        cell.velocity = bounded(a["velocity"], default: 50, range: -2000...2000)
        cell.velocityRange = bounded(a["velocityRange"], default: 0, range: 0...1000)
        cell.scale = bounded(a["scale"], default: 1, range: 0...4)
        cell.scaleRange = bounded(a["scaleRange"], default: 0, range: 0...2)
        cell.scaleSpeed = bounded(a["scaleSpeed"], default: 0, range: -4...4)
        cell.alphaRange = Float(bounded(a["alphaRange"], default: 0, range: 0...1))
        cell.alphaSpeed = Float(bounded(a["alphaSpeed"], default: 0, range: -4...4))
        cell.redRange = Float(bounded(a["redRange"], default: 0, range: -1...1))
        cell.greenRange = Float(bounded(a["greenRange"], default: 0, range: -1...1))
        cell.blueRange = Float(bounded(a["blueRange"], default: 0, range: -1...1))
        cell.redSpeed = Float(bounded(a["redSpeed"], default: 0, range: -4...4))
        cell.greenSpeed = Float(bounded(a["greenSpeed"], default: 0, range: -4...4))
        cell.blueSpeed = Float(bounded(a["blueSpeed"], default: 0, range: -4...4))
        cell.emissionRange = bounded(a["emissionRange"], default: .pi, range: 0...(2 * .pi))
        cell.emissionLongitude = bounded(a["emissionLongitude"], default: 0, range: (-2 * .pi)...(2 * .pi))
        cell.emissionLatitude = bounded(a["emissionLatitude"], default: 0, range: (-2 * .pi)...(2 * .pi))
        cell.xAcceleration = bounded(a["xAcceleration"], default: 0, range: -1000...1000)
        cell.yAcceleration = bounded(a["yAcceleration"], default: 0, range: -1000...1000)
        cell.zAcceleration = bounded(a["zAcceleration"], default: 0, range: -1000...1000)
        cell.spin = bounded(a["spin"], default: 0, range: -15...15)
        cell.spinRange = bounded(a["spinRange"], default: 0, range: 0...15)
        if let color = color(a["color"]) { cell.color = color }
        return cell
    }

    private static func animation(_ node: Node) -> CAPropertyAnimation? {
        let a = node.attributes
        guard let keyPath = a["keyPath"],
              let seconds = a["duration"].flatMap(Double.init), seconds.isFinite, seconds > 0, seconds <= 120 else { return nil }
        let property = keyPath == "transform.scale.xy" ? "transform.scale" : keyPath
        guard animatedProperties.contains(property) else { return nil }
        let result: CAPropertyAnimation
        switch a["type"] {
        case "CAKeyframeAnimation":
            let keyframe = CAKeyframeAnimation(keyPath: property)
            if property == "position", let path = shapePath(a["path"] ?? node.value("path")) {
                keyframe.path = path
            } else {
                let values = node.child("values")?.children.prefix(1000).compactMap { value($0, property: property) } ?? []
                guard values.count >= 2 else { return nil }
                keyframe.values = values
                let times = node.child("keyTimes")?.children.compactMap { $0.attributes["value"].flatMap(Double.init) } ?? []
                if times.count == values.count && times.allSatisfy({ (0...1).contains($0) }) && times == times.sorted() {
                    keyframe.keyTimes = times.map { NSNumber(value: $0) }
                }
            }
            if let mode = a["calculationMode"], ["linear", "discrete", "paced", "cubic", "cubicPaced"].contains(mode) {
                keyframe.calculationMode = CAAnimationCalculationMode(rawValue: mode)
            }
            result = keyframe
        case "CABasicAnimation", "CASpringAnimation":
            let basic: CABasicAnimation
            if a["type"] == "CASpringAnimation" {
                let spring = CASpringAnimation(keyPath: property)
                spring.mass = bounded(a["mass"], default: 1, range: 0.01...100)
                spring.stiffness = bounded(a["stiffness"], default: 100, range: 0.01...10000)
                spring.damping = bounded(a["damping"], default: 10, range: 0...10000)
                spring.initialVelocity = bounded(a["initialVelocity"], default: 0, range: -100...100)
                basic = spring
            } else {
                basic = CABasicAnimation(keyPath: property)
            }
            basic.fromValue = node.child("fromValue").flatMap { value($0, property: property) }
            basic.toValue = node.child("toValue").flatMap { value($0, property: property) }
            basic.byValue = node.child("byValue").flatMap { value($0, property: property) }
            guard basic.fromValue != nil || basic.toValue != nil || basic.byValue != nil else { return nil }
            result = basic
        default: return nil
        }
        result.duration = seconds
        // The canvas starts at local time 1. A nonzero start time lets the same
        // animation be reattached after an interruption without resetting it.
        result.beginTime = 1 + bounded(a["beginTime"], default: 0, range: -0.999...120)
        result.isRemovedOnCompletion = false
        result.timeOffset = bounded(a["timeOffset"], default: 0, range: 0...120)
        result.speed = Float(bounded(a["speed"], default: 1, range: 0...8))
        if let mode = a["fillMode"], ["removed", "forwards", "backwards", "both"].contains(mode) {
            result.fillMode = CAMediaTimingFillMode(rawValue: mode)
        }
        result.isAdditive = a["additive"] == "1"
        result.isCumulative = a["cumulative"] == "1"
        result.autoreverses = a["autoreverses"] == "1"
        let repeats = a["repeatCount"]?.lowercased()
        result.repeatCount = repeats == "inf" || repeats == "infinity" ? .infinity : Float(bounded(repeats, default: 0, range: 0...100))
        if let timing = a["timingFunction"] ?? node.value("timingFunction") {
            let controlPoints = numbers(timing)
            if controlPoints.count == 4, (0...1).contains(controlPoints[0]), (0...1).contains(controlPoints[2]) {
                result.timingFunction = CAMediaTimingFunction(controlPoints: Float(controlPoints[0]), Float(controlPoints[1]),
                                                              Float(controlPoints[2]), Float(controlPoints[3]))
            } else if ["linear", "easeIn", "easeOut", "easeInEaseOut", "default"].contains(timing) {
                result.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName(rawValue: timing))
            }
        }
        return result
    }

    private static func value(_ node: Node, property: String) -> Any? {
        let raw = node.attributes["value"]
        if property == "position" { return point(raw).map { NSValue(cgPoint: $0) } }
        if property.hasSuffix("Color") { return color(node) }
        if property == "transform", let raw { return NSValue(caTransform3D: transform(raw)) }
        guard let n = raw.flatMap(Double.init), n.isFinite, abs(n) <= 32768 else { return nil }
        return NSNumber(value: n)
    }

    private static func image(_ contents: Node?, folder: URL) -> CGImage? {
        guard let reference = contents?.attributes["src"] ?? contents?.child("CGImage")?.attributes["src"] else { return nil }
        let source: CGImageSource?
        if reference.hasPrefix("data:") {
            guard let comma = reference.firstIndex(of: ","),
                  ["data:image/png;base64", "data:image/jpeg;base64", "data:image/webp;base64", "data:image/gif;base64"]
                    .contains(reference[..<comma].lowercased()),
                  reference.utf8.count <= 8 * 1024 * 1024,
                  let data = Data(base64Encoded: String(reference[reference.index(after: comma)...])) else { return nil }
            source = CGImageSourceCreateWithData(data as CFData, nil)
        } else {
            guard let path = reference.removingPercentEncoding,
                  !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
            else { return nil }
            source = CGImageSourceCreateWithURL(folder.appending(path: path) as CFURL, nil)
        }
        guard let source else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048
        ] as CFDictionary)
    }

    private static func bounded(_ raw: String?, default fallback: CGFloat, range: ClosedRange<CGFloat>) -> CGFloat {
        guard let n = raw.flatMap(Double.init), n.isFinite else { return fallback }
        return min(max(CGFloat(n), range.lowerBound), range.upperBound)
    }

    private static func numbers(_ raw: String?) -> [CGFloat] {
        (raw ?? "").split { $0.isWhitespace || $0 == "," }.compactMap {
            guard let n = Double($0), n.isFinite, abs(n) <= 131072 else { return nil }
            return CGFloat(n)
        }
    }

    private static func point(_ raw: String?) -> CGPoint? {
        let v = numbers(raw)
        return v.count == 2 ? CGPoint(x: v[0], y: v[1]) : nil
    }

    private static func color(_ raw: String?) -> CGColor? {
        if let raw, raw.hasPrefix("#"), raw.count == 7, let hex = UInt32(raw.dropFirst(), radix: 16) {
            return CGColor(red: CGFloat(hex >> 16) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
        let v = numbers(raw)
        guard (3...4).contains(v.count), v.allSatisfy({ (0...1).contains($0) }) else { return nil }
        return CGColor(red: v[0], green: v[1], blue: v[2], alpha: v.count == 4 ? v[3] : 1)
    }

    private static func color(_ node: Node) -> CGColor? {
        guard let color = color(node.attributes["value"]) else { return nil }
        return color.copy(alpha: bounded(node.attributes["opacity"], default: color.alpha, range: 0...1))
    }

    private static func color(_ node: Node, _ name: String) -> CGColor? {
        node.child(name).flatMap(color) ?? color(node.attributes[name])
    }

    private final class Node {
        let name: String
        let attributes: [String: String]
        var children: [Node] = []

        init(_ name: String, _ attributes: [String: String]) {
            self.name = name
            self.attributes = attributes
        }

        func child(_ name: String) -> Node? { children.first { $0.name == name } }
        func value(_ name: String) -> String? { child(name)?.attributes["value"] }
    }

    private final class Reader: NSObject, XMLParserDelegate {
        private let root = Node("", [:])
        private var stack: [Node] = []
        private var count = 0

        static func read(_ url: URL) -> Node? {
            guard let parser = XMLParser(contentsOf: url) else { return nil }
            let reader = Reader()
            reader.stack = [reader.root]
            parser.shouldResolveExternalEntities = false
            parser.delegate = reader
            return parser.parse() ? reader.root.child("caml") : nil
        }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            count += 1
            guard count <= 10000, stack.count < 64 else { parser.abortParsing(); return }
            let node = Node(name, attributes)
            stack.last?.children.append(node)
            stack.append(node)
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            _ = stack.popLast()
        }
    }
}
