//
//  CometPlayer.swift
//  Cue Studio
//

import SwiftUI

/// Plays a comet once when `trigger` changes: it travels `duration` seconds along `path`.
struct CometPlayer: View {
    let path: Path
    var trigger: Int
    var duration = 1.6
    var color: Color = Palette.acc

    @State private var progress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CometTravel(path: path, progress: progress, color: color)
            .onChange(of: trigger, initial: false) { _, _ in
                progress = 0
                withAnimation(CueMotion.animation(CueMotion.travel(duration: duration), reduced: reduceMotion)) {
                    progress = 1
                }
            }
    }
}
