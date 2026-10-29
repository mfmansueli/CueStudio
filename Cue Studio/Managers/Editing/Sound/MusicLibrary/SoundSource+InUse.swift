//
//  SoundSource+InUse.swift
//  Cue Studio
//

import Foundation

/// Which sample libraries the app actually plays: what Settings › Acknowledgements lists.
nonisolated extension SoundSource {
    /// The libraries the recorded sound effects are made from, as `tools/music/sounds.py` and `variants.py` build them: CC0 only,
    /// so no effect asks for credit.
    static let soundEffectSources: [SoundSource] = [.vsco2, .vcsl, .virtuosityDrums, .kenney]

    /// Every library a library track or a recorded effect uses, in the libraries' order.
    static var inUse: [SoundSource] {
        let used = Set(CueTrack.allCases.flatMap(\.sources) + soundEffectSources)
        return allCases.filter(used.contains)
    }
}
