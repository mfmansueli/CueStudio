//
//  TipCard.swift
//  Cue Studio
//

import SwiftUI

/// The one form of a tip in Cue (owner, 30/10/2026): the system's glass in a 22 pt corner, the sign's disc (the toast's own: ★ yellow when
/// Cue guides, ✦ violet when the subject is AI, ✓ green when the step is done), an optional mono eyebrow, a title, one line, at most two
/// buttons and the ✕. A tap on the body can open what the tip is about. A question it can take in one tap lists its answers under the title
/// instead, as a row of buttons that wraps to more lines as the text grows. Compact without an eyebrow, buttons or answers: the title and its
/// line.
/// Who decides when it shows is the caller's (the voyage, My Cue Voice, `GuidanceGate`).
struct TipCard<Eyebrow: View>: View {
    enum Sign {
        /// ★ on yellow: Cue guiding.
        case guide
        /// ✦ on violet: the subject is AI (My Cue Voice).
        case ai
        /// ✓ on green: the step is done (it draws itself).
        case done
    }

    let sign: Sign
    let title: Text
    var message: Text?
    var primary: (title: String, action: () -> Void)?
    var secondary: (title: String, action: () -> Void)?
    /// The answers of a one-tap question, under the title; a tap on one is the answer.
    var choices: [TipChoice] = []
    var onChoose: ((TipChoice) -> Void)?
    /// A tap on the body (not on its buttons or ✕).
    var onOpen: (() -> Void)?
    /// The parts' identifiers start with it: "voice.tip" names "voice.tip.open", "voice.tip.close", "voice.tip.primary", "voice.tip.secondary"
    /// and each answer "voice.tip.choice.<id>".
    var identifierPrefix = "tip"
    let onClose: () -> Void
    @ViewBuilder var eyebrow: Eyebrow

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }

    private var hasButtons: Bool { primary != nil || secondary != nil }
    private var isCompact: Bool { !hasButtons && choices.isEmpty && Eyebrow.self == EmptyView.self }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: isCompact ? .center : .top, spacing: 0) {
                if let onOpen {
                    Button(action: onOpen) { content.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("\(identifierPrefix).open")
                } else {
                    content
                }
                closeButton
                    .padding(.top, isCompact ? 0 : -6)
            }
            if !choices.isEmpty { choiceRow }
            if hasButtons { buttons }
        }
        .padding(.leading, 14)
        .padding(.trailing, 2)
        .padding(.top, isCompact ? 6 : 10)
        .padding(.bottom, isCompact ? 6 : (hasButtons || !choices.isEmpty ? 8 : 12))
        .glassEffect(.regular, in: Self.shape)
    }

    private var content: some View {
        HStack(alignment: isCompact ? .center : .top, spacing: 12) {
            disc
            VStack(alignment: .leading, spacing: 2) {
                eyebrow
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .cueFont(15, weight: .semibold)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    message?
                        .cueFont(13)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The sign's 30 pt disc, the toast's colours: black on yellow (14.9:1), black on green (9.5:1), lilac on violet.
    private var disc: some View {
        ZStack {
            Circle().fill(discFill)
            switch sign {
            case .guide:
                Image(systemName: "star.fill")
                    .cueFont(13, weight: .bold)
                    .foregroundStyle(Palette.Toast.glyph)
            case .ai:
                Text(verbatim: "✦")
                    .cueFont(15, weight: .semibold)
                    .foregroundStyle(Palette.Scripts.tipGlyph)
            case .done:
                Image(systemName: "checkmark")
                    .cueFont(13, weight: .bold)
                    .foregroundStyle(Palette.Toast.glyph)
                    .transition(.symbolEffect(.drawOn))
            }
        }
        .frame(width: 30, height: 30)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.3), value: sign == .done)
        .accessibilityHidden(true)
    }

    private var discFill: Color {
        switch sign {
        case .guide: Palette.Toast.cue
        case .ai: Palette.Scripts.tipGlyphFill
        case .done: Palette.Toast.done
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.fixed(12, weight: .bold))
                .foregroundStyle(Palette.ink2)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close tip"))
        .accessibilityIdentifier("\(identifierPrefix).close")
    }

    /// The answers in a row under the title (aligned with it, past the disc), wrapping to a second line rather than cutting a word.
    private var choiceRow: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(choices) { choice in
                Button(choice.label) { onChoose?(choice) }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .accessibilityIdentifier("\(identifierPrefix).choice.\(choice.id)")
            }
        }
        .padding(.leading, 42)
        .padding(.trailing, 12)
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            if let secondary {
                Button(secondary.title, action: secondary.action)
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.hitTarget)
                    .padding(.horizontal, 8)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(identifierPrefix).secondary")
            }
            if let primary {
                Button(primary.title, action: primary.action)
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .accessibilityIdentifier("\(identifierPrefix).primary")
            }
        }
        .padding(.trailing, 12)
    }
}

extension TipCard where Eyebrow == EmptyView {
    init(
        sign: Sign, title: Text, message: Text? = nil, choices: [TipChoice] = [], onChoose: ((TipChoice) -> Void)? = nil,
        onOpen: (() -> Void)? = nil, identifierPrefix: String = "tip", onClose: @escaping () -> Void
    ) {
        self.init(
            sign: sign, title: title, message: message, choices: choices, onChoose: onChoose, onOpen: onOpen,
            identifierPrefix: identifierPrefix, onClose: onClose, eyebrow: { EmptyView() }
        )
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        TipCard(
            sign: .ai, title: Text(verbatim: "How do you like to open?"), message: Text(verbatim: "One quick question · voice 40%"), onClose: {}
        )
        TipCard(
            sign: .ai, title: Text(verbatim: "How should scripts write you?"), message: Text(verbatim: "One tap · voice 40%"),
            choices: [
                TipChoice(id: "feminine", label: "Feminine"), TipChoice(id: "masculine", label: "Masculine"),
                TipChoice(id: "neutral", label: "No gender"),
            ],
            onChoose: { _ in }, onClose: {}
        )
        TipCard(
            sign: .guide, title: Text(verbatim: "Now, for real"), message: Text(verbatim: "Redo it as often as you like."),
            primary: ("Record", {}), onClose: {},
            eyebrow: { Text(verbatim: "3 OF 6").monoFont(size: 10.5, weight: .semibold).foregroundStyle(Palette.accText) }
        )
    }
    .padding()
    .skyBackground()
}
#endif
