//
//  VoiceFieldSection.swift
//  Cue Studio
//

import SwiftUI

/// One question of My Cue Voice (the owner, 03/11/2026: clearer, more direct titles and the questions further apart, without cards): the
/// question in `.headline` `ink` with its limit after it in `ink2`, what it does right under it, then its answers. The fields put
/// `Metrics.questionGap` between them. The guided questions, the tip's sheet and the editor show the same.
struct VoiceFieldSection<Content: View>: View {
    private let title: String?
    private let detail: String?
    private let help: String?
    private let content: Content

    /// - Parameters:
    ///   - title: the question; nil when the sheet's title already asks it.
    ///   - detail: the limit or "optional", after the question.
    ///   - help: what the answer changes, in a short line under the question.
    init(_ title: String? = nil, detail: String? = nil, help: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.help = help
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || help != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(heading(title))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let help {
                        Text(help)
                            .cueFont(.footnote)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The question in semibold `ink`, its limit after it in regular `ink2`.
    private func heading(_ title: String) -> AttributedString {
        var question = AttributedString(title)
        question.font = .headline
        question.foregroundColor = Palette.ink
        guard let detail else { return question }
        var rest = AttributedString(" · \(detail)")
        rest.font = .subheadline
        rest.foregroundColor = Palette.ink2
        return question + rest
    }
}
