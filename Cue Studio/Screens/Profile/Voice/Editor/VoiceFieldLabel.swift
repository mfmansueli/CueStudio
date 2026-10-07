//
//  VoiceFieldLabel.swift
//  Cue Studio
//

import SwiftUI

/// The small grey label above a group of answers in the voice editor ("Why do they watch you? · up to 2"): what is asked, and the limit, in one line.
struct VoiceFieldLabel: View {
    let text: String
    var detail: String?

    init(_ text: String, detail: String? = nil) {
        self.text = text
        self.detail = detail
    }

    /// The question in bold and its limit after it, in regular.
    private var attributed: AttributedString {
        var question = AttributedString(text)
        question.font = .subheadline.weight(.semibold)
        guard let detail else { return question }
        var rest = AttributedString(" · \(detail)")
        rest.font = .subheadline
        return question + rest
    }

    var body: some View {
        Text(attributed)
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}
