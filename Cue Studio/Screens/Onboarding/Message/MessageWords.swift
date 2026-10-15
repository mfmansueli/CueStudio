//
//  MessageWords.swift
//  Cue Studio
//

import SwiftUI

/// One part of the script (HOOK, BODY or CTA) as words that arrive one by one out of a blur, each with a glow that fades (09 §16). The board
/// writes 19 words (3 + 11 + 5) with their own times; a script of another length takes the board's time of the word at the same place in
/// its part, so the arrival always has the board's rhythm. Japanese, Chinese and Thai arrive by dictionary word, with nothing between them.
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
    /// The words' size: the card picks the largest that fits the screen (`MessageCard`).
    var size: CGFloat = 21

    private static let clip = MotionLibrary.clip("1.4_first-message")

    var body: some View {
        let shown = Self.displayed(text)
        let words = OnboardingWords.pieces(of: shown)
        FlowLayout(spacing: OnboardingWords.isUnspaced(shown) ? 0 : size * 0.29, lineSpacing: 0) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let pose = pose(of: index, in: words.count)
                Text(word)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(color)
                    .shadow(color: pose.glow ?? .clear, radius: pose.glowRadius)
                    .frame(height: (size * 1.33).rounded())
                    .motion(pose)
            }
            if let caret {
                Rectangle()
                    .fill(caret)
                    .frame(width: 2, height: (size * 1.05).rounded())
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
