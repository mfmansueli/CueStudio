//
//  FilterLUT.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// A filter's grade (`FilterGrade`) sampled into a color cube, which Core Image draws in one
/// lookup per pixel (`CIColorCubeWithColorSpace`). The cube is made once per filter, from the
/// grade's own math, and kept: the preview, the export, the cover and the thumbnails share it,
/// and at most a handful stay in memory (the system may drop them sooner and they are made again,
/// in a few milliseconds). Nothing is read from a file, so no LUT travels with the app and none
/// carries a licence.
nonisolated enum FilterLUT {
    /// Samples per side of the cube: 32 keeps gradients smooth in 8-bit video.
    static let dimension = 32

    /// `NSCache` is safe to use from any thread.
    nonisolated(unsafe) private static let cubes: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 12
        return cache
    }()

    /// The cube of `grade`, kept under `key` (the filter's identifier).
    static func cube(for grade: FilterGrade, key: String) -> Data {
        if let kept = cubes.object(forKey: key as NSString) { return kept as Data }
        let data = make(grade)
        cubes.setObject(data as NSData, forKey: key as NSString)
        return data
    }

    /// Premultiplied RGBA floats, red varying fastest, then green, then blue (the order
    /// `CIColorCube` reads).
    static func make(_ grade: FilterGrade, dimension: Int = FilterLUT.dimension) -> Data {
        var values: [Float] = []
        values.reserveCapacity(dimension * dimension * dimension * 4)
        let last = Double(dimension - 1)
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    let graded = grade.apply(to: FilterGrade.Color(Double(red) / last, Double(green) / last, Double(blue) / last))
                    values.append(contentsOf: [Float(graded.x), Float(graded.y), Float(graded.z), 1])
                }
            }
        }
        return values.withUnsafeBytes { Data($0) }
    }

    /// `image` through the cube, read in sRGB-encoded values (the way the grade was designed).
    static func apply(_ grade: FilterGrade, key: String, to image: CIImage) -> CIImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return image }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = image
        filter.cubeDimension = Float(dimension)
        filter.cubeData = cube(for: grade, key: key)
        filter.colorSpace = colorSpace
        return filter.outputImage ?? image
    }
}
