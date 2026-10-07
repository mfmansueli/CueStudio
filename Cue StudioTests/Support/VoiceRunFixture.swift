//
//  VoiceRunFixture.swift
//  Cue StudioTests
//

import Foundation

/// The scripts a device run kept (`Fixtures/VoiceRuns/voice-run-<run>.json`, written by `tools/voice/collect_runs.py`), read from the test bundle
/// like the speech recordings: they are resources of the target.
enum VoiceRunFixture {
    enum LoadError: Error { case missing(String) }

    private final class BundleToken {}

    static func samples(_ run: String) throws -> [VoiceRunSample] {
        let name = "voice-run-\(run)"
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json") else { throw LoadError.missing(name) }
        return try JSONDecoder().decode([VoiceRunSample].self, from: Data(contentsOf: url))
    }
}
