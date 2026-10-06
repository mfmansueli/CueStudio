//
//  MessageWords.swift
//  Cue Studio
//

import SwiftUI

/// One part of the message (HOOK, BODY or CTA) as words that arrive one by one out of a blur, each with a glow that fades (09 §16). The board
/// writes 19 words (3 + 11 + 5) with their own times; a message of another length takes the board's time of the word at the same place in
/// its part, so the arrival always has the board's rhythm.
struct MessageWords: View {
    enum Part {
        case hook, body, cta

        /// The layers of the board's words of this part.
        var layers: [String] {
            switch self {
            case .hook: (26...28).map { "L\($0)" }
            case .body: (30...40).map { "L\($0)" }
            case .cta: (42...46).map { "L\($0)" }
            }
        }
    }

    let text: String
    let part: Part
    let color: Color
    /// The second of the board.
    let board: Double
    /// A caret that blinks after the last word (the CTA's).
    var caret: Color?
    let ambient: Double

    private static let clip = MotionLibrary.clip("1.4_first-message")

    var body: some View {
        let words = Self.displayed(text).split(whereSeparator: \.isWhitespace).map(String.init)
        FlowLayout(spacing: 6, lineSpacing: 0) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let pose = pose(of: index, in: words.count)
                Text(word)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(color)
                    .shadow(color: pose.glow ?? .clear, radius: pose.glowRadius)
                    .frame(height: 28)
                    .motion(pose)
            }
            if let caret {
                Rectangle()
                    .fill(caret)
                    .frame(width: 2, height: 22)
                    .padding(.leading, -3)
                    .opacity(caretOpacity)
            }
        }
    }

    /// The words the creator reads: the prompter's cues (`[pause]`, `[look at camera]`) are for the teleprompter, not for the card.
    static func displayed(_ text: String) -> String {
        text.replacingOccurrences(of: "\\[[^\\]]*\\]", with: " ", options: .regularExpression)
    }

    private func pose(of index: Int, in count: Int) -> MotionPose {
        let layers = part.layers
        let template = count <= 1 ? 0 : Int((Double(index) * Double(layers.count - 1) / Double(count - 1)).rounded())
        return Self.clip.pose(of: layers[template], at: board)
    }

    /// The caret waits for the last word (5.4–5.5 s), then blinks (1 s).
    private var caretOpacity: Double {
        let arrived = Self.clip.pose(of: "L47", at: board).opacity
        return arrived * (Int(ambient * 2) % 2 == 0 ? 1 : 0.15)
    }
}
