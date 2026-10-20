//
//  EyeRedrawScene.swift
//  Cue Studio
//

import Foundation

/// One `EyeRedraw`'s working state and steps (all planes `width × height`, row by row).
nonisolated struct EyeRedrawScene {
    let crop: EyePatch
    let width: Int, height: Int
    let eye: EyeShape
    /// Eye width, iris centre and radius, and how far the iris rises, in pixels.
    let eyeWidth: Double
    let center: SIMD2<Double>
    let radius: Double
    let rise: Double

    var lifted: EyePatch
    var shift: [Float] = []
    var raised: [SIMD2<Double>] = []
    var sourceOpen: [Float] = [], newOpen: [Float] = []
    var seen: [Bool] = [], replace: [Bool] = [], scleraPixels: [Bool] = [], irisPixels: [Bool] = [], reflections: [Bool] = []
    var whiteLayer: EyePatch
    var irisLayer: EyePatch
    var distance: [Double] = []
    var value: [Float] = []
    /// Each column's upper and lower lid, as filmed (y).
    var upperLid: [Double] = [], lowerLid: [Double] = []
    /// Each column's first and last row of iris dark enough to be iris (nil: none in that column), a little inside them.
    var irisTop: [Double?] = [], irisBottom: [Double?] = []
    /// How many pixels the filmed iris's edge takes to go from iris to white (dim light and focus soften it).
    var edge = 1.2

    init(patch: EyePatch, eye: EyeShape, degrees: Double) {
        crop = patch
        width = patch.width
        height = patch.height
        self.eye = eye
        eyeWidth = eye.frame.width
        center = eye.iris
        radius = eye.irisRadius
        lifted = patch
        whiteLayer = patch
        irisLayer = patch
        let wanted = EyeContactCalibration.eyeballRadius * eyeWidth * sin(degrees * .pi / 180)
        // A narrow eye can't show an iris it never showed: at most 40% of the lids' gap over the iris.
        let gap = Self.lidY(eye, EyeShape.lowerLid, x: eye.iris.x) - Self.lidY(eye, EyeShape.upperLid, x: eye.iris.x)
        rise = min(wanted, 0.4 * max(gap, 0))
    }

    /// The lid's y at `x` (its points sorted by x, linear between).
    static func lidY(_ eye: EyeShape, _ indices: [Int], x: Double) -> Double {
        lidY(indices.map { eye.contour[$0] }, x: x)
    }

    static func lidY(_ points: [SIMD2<Double>], x: Double) -> Double {
        let sorted = points.sorted { $0.x < $1.x }
        guard let first = sorted.first, let last = sorted.last else { return 0 }
        if x <= first.x { return first.y }
        if x >= last.x { return last.y }
        for (a, b) in zip(sorted, sorted.dropFirst()) where x <= b.x {
            return b.x > a.x ? a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x) : a.y
        }
        return last.y
    }

    // MARK: - 1. The upper lid rises

    mutating func lift() {
        let inner = eye.innerCorner.x, outer = eye.outerCorner.x
        let low = min(inner, outer), high = max(inner, outer)
        let peak = min(max((center.x - low) / max(high - low, 1), 0.2), 0.8)
        let reach = EyeRedraw.liftReach * eyeWidth
        var lifts = [Double](repeating: 0, count: width), newLid = [Double](repeating: 0, count: width)
        for x in 0..<width {
            let u = min(max((Double(x) - low) / max(high - low, 1), 0), 1)
            let v = u < peak ? u / peak : (1 - u) / (1 - peak)
            lifts[x] = EyeRedraw.lidFollows * rise * v * v * (3 - 2 * v)
            newLid[x] = Self.lidY(eye, EyeShape.upperLid, x: Double(x)) - lifts[x]
        }
        shift = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width where lifts[x] > 0 {
                let above = newLid[x] - Double(y)
                let amount: Double
                if Double(y) <= newLid[x] + 1 {
                    let t = min(max(above / reach, 0), 1)
                    amount = lifts[x] * (1 - t * t * (3 - 2 * t))
                } else {
                    amount = lifts[x]
                }
                shift[y * width + x] = Float(amount)
            }
        }
        // Catmull-Rom down each column (the lift moves pixels only up and down: sharper than bilinear).
        let rows = height, columns = width
        for channel in 0..<3 {
            crop.channels[channel].withUnsafeBufferPointer { source in
                lifted.channels[channel].withUnsafeMutableBufferPointer { target in
                    shift.withUnsafeBufferPointer { shifts in
                        for index in 0..<rows * columns where shifts[index] > 0 {
                            let x = index % columns, at = Float(index / columns) + shifts[index]
                            let row = Int(at.rounded(.down)), t = at - Float(row)
                            func tap(_ offset: Int) -> Float { source[min(max(row + offset, 0), rows - 1) * columns + x] }
                            let p0 = tap(-1), p1 = tap(0), p2 = tap(1), p3 = tap(2)
                            let a = 2 * p1, b = (p2 - p0) * t, c = (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t, d = (3 * p1 - p0 - 3 * p2 + p3) * t * t * t
                            target[index] = min(max(0.5 * (a + b + c + d), 0), 255)
                        }
                    }
                }
            }
        }
        // The opening grows up to the raised lid: the upper lid's points (not the corners) move up by their lift.
        raised = eye.contour
        for index in EyeShape.upperLid.dropFirst().dropLast() {
            let x = min(max(Int(raised[index].x.rounded()), 0), width - 1)
            raised[index].y -= lifts[x]
        }
    }

    // MARK: - 2. Openings

    mutating func masks() {
        upperLid = (0..<width).map { Self.lidY(eye, EyeShape.upperLid, x: Double($0)) }
        lowerLid = (0..<width).map { Self.lidY(eye, EyeShape.lowerLid, x: Double($0)) }
        sourceOpen = EyePatchFilters.coverage(of: eye.contour, width: width, height: height)
        newOpen = EyePatchFilters.coverage(of: raised, width: width, height: height)
        let solid = sourceOpen.map { $0 > 0.95 ? Float(1) : 0 }
        seen = EyePatchFilters.erode(solid, width: width, height: height, radius: 1).map { $0 > 0.5 }
        distance = (0..<width * height).map { index in
            let dx = Double(index % width) - center.x, dy = Double(index / width) - center.y
            return (dx * dx + dy * dy).squareRoot()
        }
        value = (0..<width * height).map { max(crop.channels[0][$0], crop.channels[1][$0], crop.channels[2][$0]) }
        replace = (0..<width * height).map { newOpen[$0] > 0 && (distance[$0] < 1.12 * radius || sourceOpen[$0] < 0.95) }
    }

    // MARK: - 3. The white of the eye

    mutating func white() {
        // The white: the brightest, least saturated of what's seen outside the iris (all but the darkest fifth).
        let candidates = (0..<width * height).filter { seen[$0] && distance[$0] > 1.12 * radius }
        func score(_ index: Int) -> Float {
            let most = value[index], least = min(crop.channels[0][index], crop.channels[1][index], crop.channels[2][index])
            let saturation = most > 0 ? (most - least) / most * 255 : 0
            return most - 0.6 * saturation
        }
        scleraPixels = [Bool](repeating: false, count: width * height)
        if candidates.count > 20 {
            let scores = candidates.map(score).sorted()
            let threshold = scores[scores.count / 5]
            for index in candidates where score(index) >= threshold { scleraPixels[index] = true }
        }
        var filled = [Bool](repeating: false, count: height)
        for y in 0..<height {
            let row = (0..<width).filter { replace[y * width + $0] }
            guard let first = row.first, let last = row.last else { continue }
            let left = (0..<first).filter { scleraPixels[y * width + $0] }.suffix(4)
            let right = ((last + 1)..<width).filter { scleraPixels[y * width + $0] }.prefix(4)
            guard left.count >= 2 || right.count >= 2 else { continue }
            for channel in 0..<3 {
                func mean(_ xs: ArraySlice<Int>) -> Float? {
                    xs.count >= 2 ? xs.reduce(Float(0)) { $0 + crop.channels[channel][y * width + $1] } / Float(xs.count) : nil
                }
                let leftColor = mean(left) ?? mean(right) ?? 0, rightColor = mean(right) ?? leftColor
                for x in row {
                    let t = Float(x - first) / Float(max(1, last - first))
                    whiteLayer.channels[channel][y * width + x] = leftColor * (1 - t) + rightColor * t
                }
            }
            filled[y] = true
        }
        // Rows with no white beside them (the band the lid uncovers): the nearest filled row below.
        for y in stride(from: height - 1, through: 0, by: -1) where !filled[y] {
            guard let below = ((y + 1)..<height).first(where: { filled[$0] }) else { continue }
            for x in 0..<width where replace[y * width + x] {
                for channel in 0..<3 { whiteLayer.channels[channel][y * width + x] = whiteLayer.channels[channel][below * width + x] }
            }
            filled[y] = true
        }
        for channel in 0..<3 {
            let blurred = EyePatchFilters.blur(whiteLayer.channels[channel], width: width, height: height, sigma: 0.06 * eyeWidth)
            for index in 0..<width * height where replace[index] { whiteLayer.channels[channel][index] = blurred[index] }
        }
    }

    // MARK: - 4. Which pixels are iris, and which are reflections

    mutating func classify() {
        let whiteValue = Self.median((0..<width * height).filter { scleraPixels[$0] }.map { value[$0] }) ?? 230
        let coreValue = Self.median((0..<width * height).filter { seen[$0] && distance[$0] < 0.6 * radius }.map { value[$0] }) ?? 80
        let core = (0..<width * height).map { seen[$0] && distance[$0] < 0.6 * radius }
        let dark = (0..<width * height).map { index -> Float in
            seen[index] && distance[index] < 0.97 * radius && (core[index] || value[index] < 0.5 * (whiteValue + coreValue)) ? 1 : 0
        }
        let eroded = EyePatchFilters.erode(dark, width: width, height: height, radius: 1)
        irisPixels = (0..<width * height).map { eroded[$0] > 0.5 || core[$0] }
        // A reflection is on the cornea: well inside the opening and a bright speck against its surroundings, brighter than the white.
        let solid = seen.map { $0 ? Float(1) : 0 }
        let deep = EyePatchFilters.erode(solid, width: width, height: height, radius: max(1, Int(0.05 * eyeWidth)))
        let speck = EyePatchFilters.topHat(value, width: width, height: height, radius: max(2, Int(0.25 * radius)))
        let bright = max(coreValue + 0.6 * (whiteValue - coreValue), 0.92 * whiteValue)
        let found = (0..<width * height).map { index -> Float in
            deep[index] > 0.5 && distance[index] < 0.9 * radius && value[index] > bright && speck[index] > 0.3 * (whiteValue - coreValue) ? 1 : 0
        }
        reflections = EyePatchFilters.dilate(found, width: width, height: height, radius: 1).map { $0 > 0.5 }
        measureEdge(whiteValue: whiteValue, coreValue: coreValue)
        // Not the thin bands along the lids (the tear line's shine on the lower one, the lashes' shadow on the upper one).
        let upperBand = 0.03 * eyeWidth, lowerBand = 0.05 * eyeWidth
        for index in 0..<width * height where irisPixels[index] {
            let x = index % width, y = Double(index / width)
            if reflections[index] || y <= upperLid[x] + upperBand || y >= lowerLid[x] - lowerBand { irisPixels[index] = false }
        }
        // The rows a column's hidden iris is reflected about: only iris darker than halfway to the white (the lid's wet line can sit
        // inside the outline, near the centre), a pixel and a half inside so a sample between rows doesn't take in that line.
        irisTop = [Double?](repeating: nil, count: width)
        irisBottom = [Double?](repeating: nil, count: width)
        let middle = 0.5 * (whiteValue + coreValue)
        for x in 0..<width {
            let rows = (0..<height).filter { irisPixels[$0 * width + x] && value[$0 * width + x] < middle }
            guard let first = rows.first, let last = rows.last else { continue }
            irisTop[x] = Double(first) + 1.5
            irisBottom[x] = Double(last) - 1.5
        }
    }

    /// `edge` from the filmed iris's sides: the step from iris to white over its steepest slope across (the median of the rows near
    /// the centre), between 1.2 pixels and 0.3 of the radius.
    private mutating func measureEdge(whiteValue: Float, coreValue: Float) {
        let smooth = EyePatchFilters.blur(value, width: width, height: height, sigma: 0.7)
        var slopes: [Float] = []
        for y in 1..<max(1, height - 1) where abs(Double(y) - center.y) < 0.5 * radius {
            var steepest: Float = -1
            for x in 1..<max(1, width - 1) {
                let index = y * width + x
                guard seen[index], !reflections[index], distance[index] > 0.6 * radius, distance[index] < 1.3 * radius else { continue }
                // Sobel across, per pixel.
                let right = smooth[index - width + 1] + 2 * smooth[index + 1] + smooth[index + width + 1]
                let left = smooth[index - width - 1] + 2 * smooth[index - 1] + smooth[index + width - 1]
                steepest = max(steepest, abs(right - left) / 8)
            }
            if steepest >= 0 { slopes.append(steepest) }
        }
        guard slopes.count > 2, let slope = Self.median(slopes), slope > 0 else { return }
        edge = min(max(Double((whiteValue - coreValue) / slope), 1.2), max(1.2, 0.3 * radius))
    }

    // MARK: - 5. The iris moves up

    mutating func moveIris() {
        let newCenter = SIMD2(center.x, center.y - rise)
        var sources = [SIMD2<Double>?](repeating: nil, count: width * height)
        var missing: [Int] = []
        // Reflected pixels and how far into the iris's colour they fade (0–1).
        var faded: [(index: Int, amount: Float)] = []
        for index in 0..<width * height {
            let offset = SIMD2(Double(index % width), Double(index / width)) - newCenter
            guard (offset * offset).sum() < (radius + 1) * (radius + 1) else { continue }
            let direct = center + offset, mirrored = SIMD2(center.x - offset.x, center.y + offset.y)
            var source: SIMD2<Double>? = isIris(direct) ? direct : isIris(mirrored) ? mirrored : nil
            // Hidden by a lid (the band the lower lid covered comes into view as the iris rises), or just past the rows the column's
            // iris is reflected about: that column reflected about its last (or first) iris row, so its texture and its edge at the
            // sides carry on across the seam.
            let at = source ?? direct
            let column = min(max(Int(at.x.rounded()), 0), width - 1)
            if let top = irisTop[column], let bottom = irisBottom[column], at.y > bottom || at.y < top {
                let axis = at.y > bottom ? bottom : top
                let reflected = SIMD2(at.x, 2 * axis - at.y)
                if isIris(reflected) {
                    source = reflected
                    // Further from the seam the reflection would repeat what's nearer the middle (the pupil, a window's
                    // reflection): it fades into the iris's colour at that distance from its centre.
                    faded.append((index, Float(min(abs(at.y - axis) / (EyeRedraw.reflectionFade * radius), 1))))
                }
            }
            if let source { sources[index] = source } else { missing.append(index) }
        }
        let rings = ringTable()
        var unfound: [Int] = []
        for index in missing {
            let offset = SIMD2(Double(index % width), Double(index / width)) - newCenter
            let r = (offset * offset).sum().squareRoot()
            let ring = min(Int(r / radius * Double(Self.rings)), Self.rings - 1)
            let angle = (atan2(offset.y, offset.x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
            guard let mirrored = rings[ring].mirror(angle) else { unfound.append(index); continue }
            sources[index] = center + r * SIMD2(cos(mirrored * .pi / 180), sin(mirrored * .pi / 180))
        }
        for index in 0..<width * height {
            guard let source = sources[index] else { continue }
            for channel in 0..<3 { irisLayer.channels[channel][index] = crop.sample(channel, x: Float(source.x), y: Float(source.y)) }
        }
        fillFromProfile(unfound.map { ($0, 1) } + faded.filter { $0.amount > 0 }, newCenter: newCenter)
    }

    private func isIris(_ point: SIMD2<Double>) -> Bool {
        let x = Int(point.x.rounded()), y = Int(point.y.rounded())
        guard x >= 0, y >= 0, x < width, y < height else { return false }
        let offset = point - center
        return irisPixels[y * width + x] && (offset * offset).sum() < 0.97 * 0.97 * radius * radius
    }

    static let rings = 12

    /// Per ring of the filmed iris: which of 360 degrees show iris.
    private func ringTable() -> [EyeIrisRing] {
        var seenAngles = Array(repeating: [Bool](repeating: false, count: 360), count: Self.rings)
        for index in 0..<width * height where irisPixels[index] {
            let offset = SIMD2(Double(index % width), Double(index / width)) - center
            let ring = min(Int(distance[index] / radius * Double(Self.rings)), Self.rings - 1)
            let angle = Int((atan2(offset.y, offset.x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)) % 360
            seenAngles[ring][angle] = true
        }
        return seenAngles.map(EyeIrisRing.init)
    }

    /// Pixels with no iris to mirror (and, by `amount`, reflected ones far from their seam): the iris's own colour at that distance
    /// from its centre (the median of what's seen there).
    private mutating func fillFromProfile(_ pixels: [(index: Int, amount: Float)], newCenter: SIMD2<Double>) {
        guard !pixels.isEmpty else { return }
        let bins = 16
        var byBin = Array(repeating: [[Float]](repeating: [], count: 3), count: bins)
        for index in 0..<width * height where irisPixels[index] {
            let bin = min(Int(distance[index] / radius * Double(bins)), bins - 1)
            for channel in 0..<3 { byBin[bin][channel].append(crop.channels[channel][index]) }
        }
        let known = (0..<bins).filter { byBin[$0][0].count >= 3 }
        guard !known.isEmpty else { return }
        let profile = (0..<bins).map { bin -> [Float] in
            let nearest = known.min { abs($0 - bin) < abs($1 - bin) } ?? known[0]
            return (0..<3).map { Self.median(byBin[nearest][$0]) ?? 0 }
        }
        for (index, amount) in pixels {
            let offset = SIMD2(Double(index % width), Double(index / width)) - newCenter
            let bin = min(Int((offset * offset).sum().squareRoot() / radius * Double(bins)), bins - 1)
            for channel in 0..<3 {
                let own = irisLayer.channels[channel][index]
                irisLayer.channels[channel][index] = own + (profile[bin][channel] - own) * amount
            }
        }
    }

    // MARK: - 6–7. The eyeball, the lid's shadow and lashes, and the blend

    mutating func compose(into patch: inout EyePatch) {
        let count = width * height
        let newCenter = SIMD2(center.x, center.y - rise)
        let reflectionAlpha = EyePatchFilters.blur(reflections.map { $0 ? Float(1) : 0 }, width: width, height: height, sigma: 0.8)
        let union = zip(sourceOpen, newOpen).map { max($0, $1) }
        let grow = max(1, Int((0.03 * eyeWidth).rounded()))
        let dilated = EyePatchFilters.dilate(union, width: width, height: height, radius: grow)
        let grown = EyePatchFilters.blur(dilated, width: width, height: height, sigma: 0.025 * eyeWidth)
        // The opening's edge as soft as the filmed iris's (the raised lid over the eyeball).
        let opening = edge > 1.5 ? EyePatchFilters.blur(newOpen, width: width, height: height, sigma: edge / 2.5) : newOpen
        let raisedUpper = EyeShape.upperLid.map { raised[$0] }
        let tops = (0..<width).map { Self.lidY(raisedUpper, x: Double($0)) }
        // Per pixel, once: the iris disc's edge, what's kept as filmed, the lid's shadow, the lash band, the reflections, the opening
        // and the blend.
        var disc = [Float](repeating: 0, count: count), keep = [Bool](repeating: false, count: count)
        var shade = [Float](repeating: 1, count: count), lashes = [Float](repeating: 0, count: count)
        var reflection = [Float](repeating: 0, count: count), blend = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let x = index % width, y = Double(index / width)
            let dx = Double(x) - newCenter.x, dy = y - newCenter.y
            let r = (dx * dx + dy * dy).squareRoot()
            disc[index] = Float(min(max((radius - r) / edge + 0.5, 0), 1))
            keep[index] = !replace[index] && r > radius + 1.5
            shade[index] = 1 - EyeRedraw.lidShade * Float(1 - min(max((y - tops[x]) / (0.16 * eyeWidth), 0), 1))
            lashes[index] = Float(min(max(1 - (y - tops[x]) / (EyeRedraw.lashBand * eyeWidth), 0), 1))
            reflection[index] = r < radius ? reflectionAlpha[index] : 0
            blend[index] = max(min(grown[index], 1), union[index])
            patch.alpha[index] = shift[index] > 0.05 ? 1 : blend[index]
        }
        for channel in 0..<3 {
            let filmed = crop.channels[channel], white = whiteLayer.channels[channel], iris = irisLayer.channels[channel]
            let raisedPixels = lifted.channels[channel]
            patch.channels[channel].withUnsafeMutableBufferPointer { out in
                for index in 0..<count {
                    let original = filmed[index], liftedPixel = raisedPixels[index]
                    var ball = original
                    if !keep[index] {
                        ball = white[index] * (1 - disc[index]) + iris[index] * disc[index]
                        ball = ball * (1 - reflection[index]) + original * reflection[index]
                    }
                    ball *= shade[index]
                    ball = ball * (1 - lashes[index]) + min(ball, liftedPixel) * lashes[index]
                    let inside = opening[index]
                    let corrected = liftedPixel * (1 - inside) + ball * inside
                    let base = shift[index] > 0.05 ? liftedPixel : original
                    out[index] = min(max(base + (corrected - base) * blend[index], 0), 255)
                }
            }
        }
    }

    static func median(_ values: [Float]) -> Float? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
