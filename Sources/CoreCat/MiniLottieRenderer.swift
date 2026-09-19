import CoreGraphics
import Foundation

// Purposefully tiny renderer for the exact shape-layer subset used by
// RuslanDemyanov/RunningCat's bundled `cat walking.json`. It is NOT a general Lottie engine.
enum MiniLottieRenderer {
    private typealias JSON = [String: Any]

    static func renderCatFrames(data: Data, pixelSize: CGSize) -> [CGImage] {
        guard let root = (try? JSONSerialization.jsonObject(with: data, options: [])) as? JSON,
              let assets = root["assets"] as? [JSON],
              let comp = assets.first(where: { ($0["id"] as? String) == "comp_0" }),
              let layers = comp["layers"] as? [JSON],
              !layers.isEmpty else {
            return []
        }

        let frameCount = max(1, Int(layers.compactMap { number($0["op"]) }.max() ?? 14))
        let byIndex: [Int: JSON] = Dictionary(uniqueKeysWithValues: layers.compactMap { layer in
            guard let index = int(layer["ind"]) else { return nil }
            return (index, layer)
        })

        var result = [CGImage]()
        result.reserveCapacity(frameCount)
        for frame in 0..<frameCount {
            if let image = renderFrame(
                layers: layers,
                byIndex: byIndex,
                time: Double(frame),
                canvasSize: CGSize(width: 1080, height: 1080),
                pixelSize: pixelSize
            ) {
                result.append(image)
            }
        }
        return result
    }

    private static func renderFrame(
        layers: [JSON],
        byIndex: [Int: JSON],
        time: Double,
        canvasSize: CGSize,
        pixelSize: CGSize
    ) -> CGImage? {
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        let bytesPerRow = width * 4
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let scale = min(pixelSize.width / canvasSize.width, pixelSize.height / canvasSize.height)
        let drawW = canvasSize.width * scale
        let drawH = canvasSize.height * scale
        context.translateBy(x: (pixelSize.width - drawW) * 0.5, y: (pixelSize.height + drawH) * 0.5)
        context.scaleBy(x: scale, y: -scale) // Lottie coordinates are y-down.

        // Lottie layer 0 is visually on top, so paint the array backwards.
        for layer in layers.reversed() {
            let ip = number(layer["ip"]) ?? 0
            let op = number(layer["op"]) ?? Double.greatestFiniteMagnitude
            if time < ip || time >= op { continue }
            drawLayer(layer, byIndex: byIndex, time: time, context: context)
        }

        return context.makeImage()
    }

    private static func drawLayer(_ layer: JSON, byIndex: [Int: JSON], time: Double, context: CGContext) {
        guard int(layer["ty"]) == 4,
              let groups = layer["shapes"] as? [JSON] else { return }

        let transforms = transformChain(for: layer, byIndex: byIndex, time: time)

        // Lottie shape stacks are front-to-back in JSON; paint them back-to-front.
        for group in groups.reversed() {
            guard (group["ty"] as? String) == "gr",
                  let items = group["it"] as? [JSON] else { continue }

            let groupTransformItem = items.first(where: { ($0["ty"] as? String) == "tr" })
            let groupTransform = transform(from: groupTransformItem, time: time)

            guard let shapeItem = items.first(where: { ($0["ty"] as? String) == "sh" }),
                  let path = makePath(shapeItem: shapeItem, time: time, groupTransform: groupTransform, layerTransforms: transforms) else {
                continue
            }

            // Within a shape group, later paint operators sit behind earlier ones.
            for item in items.reversed() {
                switch item["ty"] as? String {
                case "fl": drawFill(item: item, path: path, time: time, context: context)
                case "st": drawStroke(item: item, path: path, time: time, context: context)
                default: break
                }
            }
        }
    }

    private struct Transform {
        var position: CGPoint = .zero
        var anchor: CGPoint = .zero
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        var radians: CGFloat = 0

        func apply(_ p: CGPoint) -> CGPoint {
            var x = (p.x - anchor.x) * scaleX
            var y = (p.y - anchor.y) * scaleY
            let c = cos(radians)
            let s = sin(radians)
            let rx = x * c - y * s
            let ry = x * s + y * c
            x = rx + position.x
            y = ry + position.y
            return CGPoint(x: x, y: y)
        }
    }

    private static func transform(from object: JSON?, time: Double) -> Transform {
        guard let object = object else { return Transform() }
        // Layer transforms live inside `ks`; shape-group transforms are the object itself.
        let values = (object["ks"] as? JSON) ?? object
        let p = vectorProperty(values["p"], time: time, fallback: [0, 0])
        let a = vectorProperty(values["a"], time: time, fallback: [0, 0])
        let s = vectorProperty(values["s"], time: time, fallback: [100, 100])
        let r = scalarProperty(values["r"], time: time, fallback: 0)
        return Transform(
            position: CGPoint(x: CGFloat(p[safe: 0] ?? 0), y: CGFloat(p[safe: 1] ?? 0)),
            anchor: CGPoint(x: CGFloat(a[safe: 0] ?? 0), y: CGFloat(a[safe: 1] ?? 0)),
            scaleX: CGFloat((s[safe: 0] ?? 100) / 100),
            scaleY: CGFloat((s[safe: 1] ?? 100) / 100),
            radians: CGFloat(r * Double.pi / 180)
        )
    }

    private static func transformChain(for layer: JSON, byIndex: [Int: JSON], time: Double) -> [Transform] {
        var result = [Transform]()
        var current: JSON? = layer
        var seen = Set<Int>()

        while let item = current {
            result.append(transform(from: item, time: time))
            guard let parent = int(item["parent"]), !seen.contains(parent), let next = byIndex[parent] else { break }
            seen.insert(parent)
            current = next
        }
        return result
    }

    private static func apply(_ point: CGPoint, group: Transform, layers: [Transform]) -> CGPoint {
        var p = group.apply(point)
        for transform in layers { p = transform.apply(p) }
        return p
    }

    private static func makePath(
        shapeItem: JSON,
        time: Double,
        groupTransform: Transform,
        layerTransforms: [Transform]
    ) -> CGPath? {
        guard let ks = shapeItem["ks"] as? JSON,
              let shape = shapeProperty(ks, time: time),
              let vertices = points(shape["v"]),
              let incoming = points(shape["i"]),
              let outgoing = points(shape["o"]),
              !vertices.isEmpty,
              incoming.count == vertices.count,
              outgoing.count == vertices.count else {
            return nil
        }

        let closed = bool(shape["c"]) ?? false
        let path = CGMutablePath()
        let first = apply(vertices[0], group: groupTransform, layers: layerTransforms)
        path.move(to: first)

        if vertices.count > 1 {
            for index in 1..<vertices.count {
                let previous = index - 1
                let cp1Local = CGPoint(
                    x: vertices[previous].x + outgoing[previous].x,
                    y: vertices[previous].y + outgoing[previous].y
                )
                let cp2Local = CGPoint(
                    x: vertices[index].x + incoming[index].x,
                    y: vertices[index].y + incoming[index].y
                )
                path.addCurve(
                    to: apply(vertices[index], group: groupTransform, layers: layerTransforms),
                    control1: apply(cp1Local, group: groupTransform, layers: layerTransforms),
                    control2: apply(cp2Local, group: groupTransform, layers: layerTransforms)
                )
            }
        }

        if closed {
            let last = vertices.count - 1
            let cp1Local = CGPoint(
                x: vertices[last].x + outgoing[last].x,
                y: vertices[last].y + outgoing[last].y
            )
            let cp2Local = CGPoint(
                x: vertices[0].x + incoming[0].x,
                y: vertices[0].y + incoming[0].y
            )
            path.addCurve(
                to: first,
                control1: apply(cp1Local, group: groupTransform, layers: layerTransforms),
                control2: apply(cp2Local, group: groupTransform, layers: layerTransforms)
            )
            path.closeSubpath()
        }
        return path
    }

    private static func drawFill(item: JSON, path: CGPath, time: Double, context: CGContext) {
        let color = vectorProperty(item["c"], time: time, fallback: [0, 0, 0, 1])
        let opacity = scalarProperty(item["o"], time: time, fallback: 100) / 100
        let luminance = 0.2126 * (color[safe: 0] ?? 0) + 0.7152 * (color[safe: 1] ?? 0) + 0.0722 * (color[safe: 2] ?? 0)

        context.saveGState()
        context.addPath(path)
        if luminance > 0.65 {
            // In the source animation, white is the cat's interior against a transparent menu bar.
            // Clearing it produces a proper monochrome template mask for light/dark tinting.
            context.setBlendMode(.clear)
            context.fillPath()
        } else {
            context.setBlendMode(.normal)
            context.setFillColor(red: 0, green: 0, blue: 0, alpha: CGFloat(opacity))
            context.fillPath()
        }
        context.restoreGState()
    }

    private static func drawStroke(item: JSON, path: CGPath, time: Double, context: CGContext) {
        let color = vectorProperty(item["c"], time: time, fallback: [0, 0, 0, 1])
        let opacity = scalarProperty(item["o"], time: time, fallback: 100) / 100
        let width = scalarProperty(item["w"], time: time, fallback: 1)
        let luminance = 0.2126 * (color[safe: 0] ?? 0) + 0.7152 * (color[safe: 1] ?? 0) + 0.0722 * (color[safe: 2] ?? 0)

        context.saveGState()
        context.addPath(path)
        context.setLineWidth(CGFloat(width))
        context.setLineCap(lineCap(int(item["lc"]) ?? 1))
        context.setLineJoin(lineJoin(int(item["lj"]) ?? 1))
        if luminance > 0.65 {
            context.setBlendMode(.clear)
            context.strokePath()
        } else {
            context.setBlendMode(.normal)
            context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: CGFloat(opacity))
            context.strokePath()
        }
        context.restoreGState()
    }

    private static func lineCap(_ value: Int) -> CGLineCap {
        switch value {
        case 2: return .round
        case 3: return .square
        default: return .butt
        }
    }

    private static func lineJoin(_ value: Int) -> CGLineJoin {
        switch value {
        case 2: return .round
        case 3: return .bevel
        default: return .miter
        }
    }

    // MARK: - Lottie property decoding

    private static func scalarProperty(_ object: Any?, time: Double, fallback: Double) -> Double {
        guard let property = object as? JSON else { return number(object) ?? fallback }
        let animated = int(property["a"]) == 1
        guard animated else { return number(property["k"]) ?? firstNumber(property["k"]) ?? fallback }
        return interpolatedVector(property["k"], time: time)?.first ?? fallback
    }

    private static func vectorProperty(_ object: Any?, time: Double, fallback: [Double]) -> [Double] {
        guard let property = object as? JSON else { return doubles(object) ?? fallback }
        let animated = int(property["a"]) == 1
        guard animated else { return doubles(property["k"]) ?? [number(property["k"]) ?? fallback.first ?? 0] }
        return interpolatedVector(property["k"], time: time) ?? fallback
    }

    private static func interpolatedVector(_ object: Any?, time: Double) -> [Double]? {
        guard let keys = object as? [JSON], !keys.isEmpty else { return doubles(object) }
        if keys.count == 1 { return doubles(keys[0]["s"]) ?? doubles(keys[0]["e"]) }

        var index = 0
        for i in 0..<(keys.count - 1) {
            let t0 = number(keys[i]["t"]) ?? 0
            let t1 = number(keys[i + 1]["t"]) ?? t0
            if time >= t0 && time < t1 { index = i; break }
            if time >= t1 { index = i + 1 }
        }

        let startKey = keys[min(index, keys.count - 1)]
        if index >= keys.count - 1 {
            return doubles(startKey["s"]) ?? doubles(startKey["e"]) ?? doubles(keys[keys.count - 2]["e"])
        }

        let endKey = keys[index + 1]
        guard let start = doubles(startKey["s"]) ?? doubles(startKey["e"]),
              let end = doubles(startKey["e"]) ?? doubles(endKey["s"]) else {
            return doubles(startKey["s"]) ?? doubles(endKey["s"])
        }
        let t0 = number(startKey["t"]) ?? 0
        let t1 = number(endKey["t"]) ?? t0
        let f = t1 > t0 ? min(1, max(0, (time - t0) / (t1 - t0))) : 0
        return zipVectors(start, end, fraction: f)
    }

    private static func shapeProperty(_ property: JSON, time: Double) -> JSON? {
        let animated = int(property["a"]) == 1
        if !animated { return property["k"] as? JSON }
        guard let keys = property["k"] as? [JSON], !keys.isEmpty else { return nil }

        var index = 0
        for i in 0..<(max(0, keys.count - 1)) {
            let t0 = number(keys[i]["t"]) ?? 0
            let t1 = number(keys[i + 1]["t"]) ?? t0
            if time >= t0 && time < t1 { index = i; break }
            if time >= t1 { index = i + 1 }
        }
        if index >= keys.count - 1 {
            return firstShape(keys[index]["s"]) ?? firstShape(keys[max(0, index - 1)]["e"])
        }

        let aKey = keys[index]
        let bKey = keys[index + 1]
        guard let a = firstShape(aKey["s"]),
              let b = firstShape(aKey["e"]) ?? firstShape(bKey["s"]) else {
            return firstShape(aKey["s"]) ?? firstShape(bKey["s"])
        }
        let t0 = number(aKey["t"]) ?? 0
        let t1 = number(bKey["t"]) ?? t0
        let f = t1 > t0 ? min(1, max(0, (time - t0) / (t1 - t0))) : 0
        return interpolateShape(a, b, fraction: f)
    }

    private static func interpolateShape(_ a: JSON, _ b: JSON, fraction: Double) -> JSON {
        var out = a
        for key in ["v", "i", "o"] {
            guard let ap = points(a[key]), let bp = points(b[key]), ap.count == bp.count else { continue }
            out[key] = zip(ap, bp).map { pair in
                [
                    Double(pair.0.x) + (Double(pair.1.x) - Double(pair.0.x)) * fraction,
                    Double(pair.0.y) + (Double(pair.1.y) - Double(pair.0.y)) * fraction
                ]
            }
        }
        return out
    }

    private static func firstShape(_ object: Any?) -> JSON? {
        if let shape = object as? JSON { return shape }
        if let array = object as? [JSON] { return array.first }
        return nil
    }

    private static func zipVectors(_ a: [Double], _ b: [Double], fraction: Double) -> [Double] {
        let count = min(a.count, b.count)
        guard count > 0 else { return a }
        return (0..<count).map { i in a[i] + (b[i] - a[i]) * fraction }
    }

    private static func points(_ object: Any?) -> [CGPoint]? {
        guard let values = object as? [Any] else { return nil }
        var result = [CGPoint]()
        result.reserveCapacity(values.count)
        for item in values {
            guard let xy = doubles(item), xy.count >= 2 else { return nil }
            result.append(CGPoint(x: CGFloat(xy[0]), y: CGFloat(xy[1])))
        }
        return result
    }

    private static func doubles(_ object: Any?) -> [Double]? {
        guard let values = object as? [Any] else { return nil }
        var result = [Double]()
        result.reserveCapacity(values.count)
        for item in values {
            guard let n = number(item) else { return nil }
            result.append(n)
        }
        return result
    }

    private static func firstNumber(_ object: Any?) -> Double? {
        doubles(object)?.first
    }

    private static func number(_ object: Any?) -> Double? {
        if let value = object as? NSNumber { return value.doubleValue }
        if let value = object as? Double { return value }
        if let value = object as? Int { return Double(value) }
        return nil
    }

    private static func int(_ object: Any?) -> Int? {
        if let value = object as? NSNumber { return value.intValue }
        if let value = object as? Int { return value }
        return nil
    }

    private static func bool(_ object: Any?) -> Bool? {
        if let value = object as? NSNumber { return value.boolValue }
        if let value = object as? Bool { return value }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
