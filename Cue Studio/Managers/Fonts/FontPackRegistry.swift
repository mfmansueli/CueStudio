//
//  FontPackRegistry.swift
//  Cue Studio
//

import Foundation
import Synchronization

/// The library files this launch can draw, for the renderers (preview, export, cards), which run off the main actor:
/// `FontPackStore` puts each here once it is checked and registered with Core Text. While a video exports, files that arrive
/// wait (`beginExport`/`endExport`), so a video never changes face halfway through; the preview draws them when it ends.
/// It also keeps which script Chinese characters with no kana around them are read in (`WritingScript.hanReading`), from the
/// creator's languages, the same for the preview and the export.
nonisolated final class FontPackRegistry: Sendable {
    static let shared = FontPackRegistry()

    private struct State {
        /// "pack/file" → the PostScript name it registered under.
        var ready: [String: String] = [:]
        var held: [String: String] = [:]
        var exports = 0
        var generation = 0
        var hanReading = WritingScript.chineseSimplified
    }

    private let state = Mutex(State())

    static func key(_ pack: FontPack, _ file: FontPack.File) -> String {
        "\(pack.id)/\(file.file)"
    }

    /// The face that draws `pack` at `weight` when its file is here: its registered name and the file (a variable one is drawn
    /// at the weight on its axis).
    func face(of pack: FontPack, weight: TextOverlayWeight) -> (postScriptName: String, file: FontPack.File)? {
        let file = pack.file(for: weight)
        let key = Self.key(pack, file)
        return state.withLock { state in state.ready[key].map { ($0, file) } }
    }

    func isReady(_ pack: FontPack, _ file: FontPack.File) -> Bool {
        let key = Self.key(pack, file)
        return state.withLock { $0.ready[key] != nil }
    }

    /// A file checked and registered: drawn from now on (after the export running, if one is).
    func add(_ pack: FontPack, _ file: FontPack.File, postScriptName: String) {
        let key = Self.key(pack, file)
        state.withLock { state in
            if state.exports > 0 {
                state.held[key] = postScriptName
            } else {
                state.ready[key] = postScriptName
                state.generation += 1
            }
        }
    }

    func remove(_ pack: FontPack, _ file: FontPack.File) {
        let key = Self.key(pack, file)
        state.withLock { state in
            state.held[key] = nil
            if state.ready.removeValue(forKey: key) != nil { state.generation += 1 }
        }
    }

    func removeAll() {
        state.withLock { state in
            state.held = [:]
            state.ready = [:]
            state.generation += 1
        }
    }

    /// Counts up whenever the faces drawn change: part of every cached drawing's name, so it is drawn again.
    var generation: Int {
        state.withLock(\.generation)
    }

    func beginExport() {
        state.withLock { $0.exports += 1 }
    }

    /// The export ended; whether files that waited for it are drawn now.
    @discardableResult
    func endExport() -> Bool {
        state.withLock { state in
            state.exports = max(0, state.exports - 1)
            guard state.exports == 0, !state.held.isEmpty else { return false }
            state.ready.merge(state.held) { _, new in new }
            state.held = [:]
            state.generation += 1
            return true
        }
    }

    var hanReading: WritingScript {
        get { state.withLock(\.hanReading) }
        set {
            state.withLock { state in
                guard state.hanReading != newValue else { return }
                state.hanReading = newValue
                state.generation += 1
            }
        }
    }
}
