//
//  FaceMeshModel.swift
//  Cue Studio
//

import CoreML
import CoreVideo
import Foundation

/// MediaPipe's face mesh (Face Landmarker V2, Apache 2.0), converted to Core ML by `tools/eyecontact/landmarks.py`: 478 points of a
/// face, both irises included, from a 256-pixel crop of it. Bundled (2.9 MB) and loaded the first time a frame needs it; it runs on
/// the Neural Engine or the CPU, never the GPU, so an analysis can go on in the background.
///
/// `@unchecked Sendable`: the model and its loading state are only touched under `lock`, one prediction at a time.
nonisolated final class FaceMeshModel: FaceMeshing, @unchecked Sendable {
    static let shared = FaceMeshModel()

    private let lock = NSLock()
    private var model: MLModel?
    private var failedToLoad = false
    private let url: URL?

    init(url: URL? = Bundle.main.url(forResource: "FaceMeshV2", withExtension: "mlmodelc")) {
        self.url = url
    }

    /// Whether the model is in the app and loads (it loads now if it hasn't).
    var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return loaded() != nil
    }

    func mesh(in crop: CVPixelBuffer) -> FaceMesh? {
        lock.lock()
        defer { lock.unlock() }
        guard let model = loaded(), let input = try? MLDictionaryFeatureProvider(dictionary: ["face": MLFeatureValue(pixelBuffer: crop)]) else {
            return nil
        }
        // The model's arrays go with each frame (it runs on every frame of an analysis).
        return autoreleasepool {
            guard let output = try? model.prediction(from: input),
                  let points = output.featureValue(for: "landmarks")?.multiArrayValue.flatMap(Self.points),
                  let score = output.featureValue(for: "faceScore")?.multiArrayValue.flatMap(Self.firstValue) else { return nil }
            // The score is a logit.
            return FaceMesh(points: points, score: 1 / (1 + exp(-score)))
        }
    }

    /// The model, loaded once; nil when it isn't in the app or can't load (asked again never retries a failure).
    private func loaded() -> MLModel? {
        if let model { return model }
        guard !failedToLoad, let url else { return nil }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        do {
            let loaded = try MLModel(contentsOf: url, configuration: configuration)
            model = loaded
            return loaded
        } catch {
            failedToLoad = true
            return nil
        }
    }

    /// A 1 × 478 × 3 output's x and y.
    private static func points(_ array: MLMultiArray) -> [SIMD2<Double>]? {
        guard array.shape.count == 3, array.shape[1].intValue == FaceMesh.count, array.shape[2].intValue >= 2 else { return nil }
        let strides = array.strides.map(\.intValue)
        var points = [SIMD2<Double>](repeating: .zero, count: FaceMesh.count)
        func fill<T: MLShapedArrayScalar>(_ type: T.Type, _ convert: (T) -> Double) {
            array.withUnsafeBufferPointer(ofType: type) { pointer in
                for index in 0..<FaceMesh.count {
                    points[index] = SIMD2(convert(pointer[index * strides[1]]), convert(pointer[index * strides[1] + strides[2]]))
                }
            }
        }
        switch array.dataType {
        case .float32: fill(Float.self) { Double($0) }
        case .float16: fill(Float16.self) { Double($0) }
        case .double: fill(Double.self) { $0 }
        default: return nil
        }
        return points
    }

    private static func firstValue(_ array: MLMultiArray) -> Double? {
        array.count > 0 ? array[0].doubleValue : nil
    }
}
