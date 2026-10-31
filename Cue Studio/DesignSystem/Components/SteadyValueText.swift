//
//  SteadyValueText.swift
//  Cue Studio
//

import SwiftUI

/// A value that changes while a control moves ("1×", "1.1×", "+5", "−100"), always as wide as the widest it can show: the words and
/// buttons beside it never move or get squeezed, and it is never cut. `samples` are the values whose width differs (a slider's ends,
/// every stop of a short scale); they are laid out hidden and the value is drawn over them at `alignment`. Font and colour come from
/// the caller, as on a `Text`.
struct SteadyValueText: View {
    let text: String
    var samples: [String] = []
    var alignment: Alignment = .trailing

    var body: some View {
        ZStack(alignment: alignment) {
            ForEach(samples, id: \.self) { Text(verbatim: $0).hidden() }
            Text(verbatim: text)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .trailing, spacing: 8) {
        SteadyValueText(text: "1×", samples: ["0.2×", "2×"])
        SteadyValueText(text: "1.1×", samples: ["0.2×", "2×"])
    }
    .monospacedDigit()
    .foregroundStyle(Palette.ink)
    .padding()
    .background(Palette.bg)
}
#endif
