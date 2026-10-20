//
//  EyePatchFilters.swift
//  Cue Studio
//

import Accelerate
import Foundation

/// The small image operations `EyeRedraw` needs on an `EyePatch`'s planes: a polygon's anti-aliased coverage, square erosion and
/// dilation, a separable Gaussian blur and a top-hat (bright specks). The filters run in vImage: in Swift loops a Debug build took
/// 3 s an eye (29 ms optimized). Pure.
nonisolated enum EyePatchFilters {
    /// How much of each pixel `polygon` (pixel coordinates, pixel centres at whole numbers) covers, 0–1: scanlines at four
    /// sub-rows a pixel, exact coverage along each.
    static func coverage(of polygon: [SIMD2<Double>], width: Int, height: Int) -> [Float] {
        var result = [Float](repeating: 0, count: width * height)
        guard polygon.count >= 3 else { return result }
        let subRows = 4
        let minY = max(0, Int(floor((polygon.map(\.y).min() ?? 0) + 0.5)))
        let maxY = min(height - 1, Int(ceil((polygon.map(\.y).max() ?? 0) + 0.5)))
        guard minY <= maxY else { return result }
        var crossings: [Double] = []
        for row in minY...maxY {
            for sub in 0..<subRows {
                // Pixel `row` spans y from row - 0.5 to row + 0.5.
                let y = Double(row) - 0.5 + (Double(sub) + 0.5) / Double(subRows)
                crossings.removeAll(keepingCapacity: true)
                for index in polygon.indices {
                    let a = polygon[index], b = polygon[(index + 1) % polygon.count]
                    if (a.y <= y && b.y > y) || (b.y <= y && a.y > y) {
                        crossings.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
                    }
                }
                crossings.sort()
                var pair = 0
                while pair + 1 < crossings.count {
                    add(span: crossings[pair], to: crossings[pair + 1], row: row, weight: 1 / Float(subRows), width: width, into: &result)
                    pair += 2
                }
            }
        }
        return result
    }

    /// Adds `weight` × the share of each pixel of `row` between x `from` and `to`.
    private static func add(span from: Double, to: Double, row: Int, weight: Float, width: Int, into result: inout [Float]) {
        // Pixel `x` spans from x - 0.5 to x + 0.5.
        let first = max(0, Int(floor(from + 0.5))), last = min(width - 1, Int(floor(to + 0.5)))
        guard first <= last else { return }
        for x in first...last {
            let left = max(from, Double(x) - 0.5), right = min(to, Double(x) + 0.5)
            if right > left { result[row * width + x] += weight * Float(right - left) }
        }
    }

    /// Each pixel the least (erode) or most (dilate) of the `2 radius + 1` square around it.
    static func erode(_ plane: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        morphology(plane, width: width, height: height, radius: radius, most: false)
    }

    static func dilate(_ plane: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        morphology(plane, width: width, height: height, radius: radius, most: true)
    }

    private static func morphology(_ plane: [Float], width: Int, height: Int, radius: Int, most: Bool) -> [Float] {
        guard radius > 0, plane.count == width * height, width > 0, height > 0 else { return plane }
        var source = plane
        var result = [Float](repeating: 0, count: plane.count)
        let side = vImagePixelCount(2 * radius + 1)
        source.withUnsafeMutableBufferPointer { input in
            result.withUnsafeMutableBufferPointer { output in
                var from = vImage_Buffer(data: input.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                var into = vImage_Buffer(data: output.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                let flags = vImage_Flags(kvImageNoFlags)
                _ = most
                    ? vImageMax_PlanarF(&from, &into, nil, 0, 0, side, side, flags)
                    : vImageMin_PlanarF(&from, &into, nil, 0, 0, side, side, flags)
            }
        }
        return result
    }

    /// A Gaussian blur of `sigma` pixels (edges repeated).
    static func blur(_ plane: [Float], width: Int, height: Int, sigma: Double) -> [Float] {
        guard sigma > 0.05, plane.count == width * height, width > 0, height > 0 else { return plane }
        let reach = max(1, Int(ceil(3 * sigma)))
        var weights = (-reach...reach).map { Float(exp(-0.5 * Double($0 * $0) / (sigma * sigma))) }
        let total = weights.reduce(0, +)
        weights = weights.map { $0 / total }
        var source = plane
        var result = [Float](repeating: 0, count: plane.count)
        source.withUnsafeMutableBufferPointer { input in
            result.withUnsafeMutableBufferPointer { output in
                var from = vImage_Buffer(data: input.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                var into = vImage_Buffer(data: output.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                _ = vImageSepConvolve_PlanarF(
                    &from, &into, nil, 0, 0, weights, UInt32(weights.count), weights, UInt32(weights.count), 0, 0, vImage_Flags(kvImageEdgeExtend)
                )
            }
        }
        return result
    }

    /// The plane minus its opening (erode then dilate) with a `2 radius + 1` square: bright specks smaller than the square.
    static func topHat(_ plane: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        let opened = dilate(erode(plane, width: width, height: height, radius: radius), width: width, height: height, radius: radius)
        return zip(plane, opened).map { $0 - $1 }
    }
}
