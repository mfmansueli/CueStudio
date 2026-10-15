//
//  QualityRunFixture.swift
//  Cue StudioTests
//

import Foundation

/// What a script-quality run kept on a device (`Fixtures/ScriptQuality/quality-run-<run>.json`, written by `tools/quality/collect.py`), read from the
/// test bundle: the real model's texts, so the pure parts of the engine can be run again on them without a device.
enum QualityRunFixture {
    enum LoadError: Error { case missing(String) }

    private final class BundleToken {}

    static func samples(_ run: String) throws -> [QualityRunSample] {
        let name = "quality-run-\(run)"
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json") else { throw LoadError.missing(name) }
        return try JSONDecoder().decode([QualityRunSample].self, from: Data(contentsOf: url))
    }
}
