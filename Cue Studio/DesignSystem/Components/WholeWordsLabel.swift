//
//  WholeWordsLabel.swift
//  Cue Studio
//

import SwiftUI

/// A name in a tile, a card or a narrow button that is never cut, in any language (owner, 02/11/2026: no label is ever cut): on
/// one line while it fits; else on two even lines broken between words (`LabelLineBreak`), never inside one; only past that a
/// little smaller, at most to `minimumScale`. A plain `Text` on two lines would split a long word ("Unschärfeber-eich") before
/// it shrank. Its font and color come from the environment, as a `Text`'s do.
struct WholeWordsLabel: View {
    let text: String
    var alignment: TextAlignment = .center
    var minimumScale: CGFloat = 0.7

    var body: some View {
        let lines = LabelLineBreak.twoLines(text)
        ViewThatFits(in: .horizontal) {
            Text(text).lineLimit(1)
            if let lines {
                Text(lines).lineLimit(2)
            }
            // The last resort shrinks each line on its own: a two-line `Text` cut "Colpo drammati…" rather than shrink.
            VStack(alignment: stackAlignment, spacing: 0) {
                ForEach(Array((lines ?? text).components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .lineLimit(1)
                        .minimumScaleFactor(minimumScale)
                }
            }
        }
        .multilineTextAlignment(alignment)
        // VoiceOver (and the UI tests) read the name as written, without the line break.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .accessibilityAddTraits(.isStaticText)
    }

    private var stackAlignment: HorizontalAlignment {
        switch alignment {
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        ForEach(["Blur area", "Voce fuori campo", "Unschärfebereich", "スライドするボックス"], id: \.self) { name in
            WholeWordsLabel(text: name)
                .font(.system(.footnote, weight: .semibold))
                .frame(width: 62)
                .border(Palette.ink3)
        }
    }
    .padding()
    .background(Palette.bg)
}
#endif
