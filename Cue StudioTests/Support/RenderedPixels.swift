//
//  RenderedPixels.swift
//  Cue StudioTests
//

import CoreImage
import Foundation

/// A Core Image picture rendered once (by the software renderer, so the same on every machine) to sRGB-encoded bytes, for tests to measure.
struct RenderedPixels {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ image: CIImage) {
        let extent = image.extent.integral
        width = Int(extent.width)
        height = Int(extent.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
        if let space = CGColorSpace(name: CGColorSpace.sRGB) {
            context.render(image, toBitmap: &bytes, rowBytes: width * 4, bounds: extent, format: .RGBA8, colorSpace: space)
        }
        self.bytes = bytes
    }

    /// The color at a point of the picture, y up from the bottom, 0 to 255.
    func rgb(at point: CGPoint) -> (red: Double, green: Double, blue: Double) {
        let column = min(max(Int(point.x), 0), width - 1)
        let row = min(max(height - 1 - Int(point.y), 0), height - 1)
        let index = (row * width + column) * 4
        return (Double(bytes[index]), Double(bytes[index + 1]), Double(bytes[index + 2]))
    }

    /// The brightness (Rec. 601) at each pixel of `rect`.
    func luma(in rect: CGRect) -> [Double] {
        var values: [Double] = []
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                let color = rgb(at: CGPoint(x: x, y: y))
                values.append(0.299 * color.red + 0.587 * color.green + 0.114 * color.blue)
            }
        }
        return values
    }

    /// The average color over `rect`.
    func mean(in rect: CGRect) -> (red: Double, green: Double, blue: Double) {
        var sum = (red: 0.0, green: 0.0, blue: 0.0)
        var count = 0.0
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                let color = rgb(at: CGPoint(x: x, y: y))
                sum = (sum.red + color.red, sum.green + color.green, sum.blue + color.blue)
                count += 1
            }
        }
        return (sum.red / count, sum.green / count, sum.blue / count)
    }

    /// How much the brightness varies over `rect` (its standard deviation, 0 to 255).
    func texture(in rect: CGRect) -> Double {
        let values = luma(in: rect)
        let average = values.reduce(0, +) / Double(values.count)
        return (values.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count)).squareRoot()
    }

    /// The largest difference between two pictures of the same size on any channel of any pixel of `rect`.
    func greatestDifference(from other: RenderedPixels, in rect: CGRect) -> Double {
        var greatest = 0.0
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                let first = rgb(at: CGPoint(x: x, y: y)), second = other.rgb(at: CGPoint(x: x, y: y))
                greatest = max(greatest, abs(first.red - second.red), abs(first.green - second.green), abs(first.blue - second.blue))
            }
        }
        return greatest
    }
}
