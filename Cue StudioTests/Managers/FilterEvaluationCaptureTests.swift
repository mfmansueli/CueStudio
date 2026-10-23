//
//  FilterEvaluationCaptureTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Every filter of the collection on portraits, at the intensity it starts with, for a person to judge (skin, grain, glow).
/// Opt-in: `TEST_RUNNER_CUE_FILTER_PORTRAITS=<folder of .jpg>` and `TEST_RUNNER_CUE_FILTER_OUTPUT=<folder>`.
@Suite("Filter evaluation capture")
struct FilterEvaluationCaptureTests {
    @Test func everyFilterOnEveryPortrait() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let input = environment["CUE_FILTER_PORTRAITS"], let output = environment["CUE_FILTER_OUTPUT"] else { return }
        let folder = URL(fileURLWithPath: output, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let portraits = try FileManager.default.contentsOfDirectory(atPath: input).filter { $0.hasSuffix(".jpg") }.sorted()
        let context = CIContext()
        for name in portraits {
            guard let image = CIImage(contentsOf: URL(fileURLWithPath: input).appending(path: name)) else { continue }
            for filter in [VideoFilter.original] + VideoFilter.collection {
                var look = LookSettings()
                look.filter = filter
                look.filterAmount = filter.defaultAmount
                let graded = FrameLook.apply(look, to: image, time: 2)
                guard let cg = context.createCGImage(graded, from: image.extent),
                      let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85) else { continue }
                try data.write(to: folder.appending(path: "\(name.replacingOccurrences(of: ".jpg", with: ""))-\(filter.rawValue).jpg"))
            }
        }
    }
}
