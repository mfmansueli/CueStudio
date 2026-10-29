//
//  RenderedSoundFiles.swift
//  Cue Studio
//

import Foundation
import os

/// The sounds a renderer wrote into the temporary folder this session (a curved clip's, `CurveSoundRenderer`; a voice effect's,
/// `VoiceEffectRenderer`), by the name of what they render, and the names each clip used, oldest first. A clip keeps its newest
/// `kept` renders (the preview may still be playing the one before while the new item is built); its older ones that no other
/// clip uses are removed. The rest goes at the next launch with the other sounds (`EditStorageCleaner`).
nonisolated final class RenderedSoundFiles: Sendable {
    private struct State {
        var files: [String: URL] = [:]
        var byClip: [String: [String]] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let kept: Int

    init(kept: Int) {
        self.kept = kept
    }

    /// The file rendered as `name` this session, while it's still on disk.
    func file(named name: String) -> URL? {
        guard let url = state.withLock({ $0.files[name] }), FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }
        return url
    }

    /// `name` is the clip's newest render; its renders older than the last `kept` that no other clip uses are removed.
    func remember(_ name: String, at url: URL, for clip: String) {
        let kept = kept
        let removed: [URL] = state.withLock { state in
            state.files[name] = url
            var names = state.byClip[clip] ?? []
            names.removeAll { $0 == name }
            names.append(name)
            let dropped = names.count > kept ? Array(names.prefix(names.count - kept)) : []
            names.removeFirst(dropped.count)
            state.byClip[clip] = names
            let stillUsed = Set(state.byClip.values.joined())
            return dropped.filter { !stillUsed.contains($0) }.compactMap { old in state.files.removeValue(forKey: old) }
        }
        for url in removed { try? FileManager.default.removeItem(at: url) }
    }

    /// A hash that's the same on every launch (Swift's `hashValue` isn't), for a render's name.
    static func stableHash(_ text: String) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 36)
    }
}
