//
//  RemoteCodeChips.swift
//  Cue Studio
//

import SwiftUI

/// The pairing code under the scene while the teleprompter waits, a character to a tile in two groups of three ("K7M 4QX"), for the
/// other device to type when it can't scan. The tiles rise into place one after another, out of a blur, like words from light; a new code
/// arrives the same way. Reduce Motion: they fade in together.
struct RemoteCodeChips: View {
    let code: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: String?

    var body: some View {
        let characters = Array(code)
        let half = characters.count / 2
        HStack(spacing: 6) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                if index == half { Spacer().frame(width: 10) }
                tile(character, index: index)
            }
        }
        .onAppear { shown = code }
        .onChange(of: code) { shown = $1 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Code \(characters.map(String.init).joined(separator: " "))"))
        .accessibilityIdentifier("remote.code")
    }

    private func tile(_ character: Character, index: Int) -> some View {
        let isShown = shown == code
        return Text(String(character))
            .monoFont(size: 24, weight: .bold)
            .foregroundStyle(Palette.ink)
            .frame(width: 40, height: 50)
            .background(Palette.Remote.codeTile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.Remote.codeTileRim, lineWidth: 1))
            .opacity(isShown ? 1 : 0)
            .blur(radius: isShown || reduceMotion ? 0 : 6)
            .offset(y: isShown || reduceMotion ? 0 : 10)
            .animation(
                reduceMotion ? CueMotion.fade : CueMotion.light(duration: 0.55).delay(0.35 + Double(index) * 0.06),
                value: isShown
            )
    }
}
