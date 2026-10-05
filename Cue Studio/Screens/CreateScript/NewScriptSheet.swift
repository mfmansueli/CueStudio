//
//  NewScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// "New script": write your own or import a document. The AI lives in the idea card on Scripts
/// ("Let's Cue!"), not here. Over the camera (attach mode) a blank page makes no sense, so Paste
/// takes Write's place.
struct NewScriptSheet: View {
    enum Mode { case new, attach }

    let mode: Mode
    var onLetCue: () -> Void = {}
    var onWrite: () -> Void = {}
    var onPaste: () -> Void = {}
    let onImport: () -> Void
    var onStartFromFormat: () -> Void = {}
    var onAnswer: () -> Void = {}
    var onFreestyle: () -> Void = {}
    /// Whether Apple Intelligence can write: without it, "Let Cue write it" and "Answer a comment" aren't offered as
    /// AI (the first goes away; a reply is written by hand).
    var hasAI = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: mode == .new ? String(localized: "Start a video") : String(localized: "New script"),
                subtitle: mode == .new ? nil : String(localized: "Your words, your way.")
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 16)

            VStack(spacing: 10) {
                switch mode {
                case .new:
                    if hasAI {
                        row(
                            "Let Cue write it", detail: "Say or type an idea · in your voice", systemImage: "sparkles",
                            style: .ai, identifier: "newScript.letCue", action: onLetCue
                        )
                    }
                    row(
                        "Write it myself", detail: "Start with your own words", systemImage: "pencil",
                        style: .plain, identifier: "newScript.write", action: onWrite
                    )
                    row(
                        "Start from a format", detail: "Talking head, tutorial, sponsored ad… you write it",
                        systemImage: "rectangle.3.group", style: .plain, identifier: "newScript.format", action: onStartFromFormat
                    )
                case .attach:
                    row(
                        "Paste", detail: "From clipboard", systemImage: "doc.on.clipboard",
                        style: .primary, identifier: "newScript.paste", action: onPaste
                    )
                }
                row(
                    "Import", detail: "Scan, photo, file or paste", systemImage: "square.and.arrow.down",
                    style: .plain, identifier: "newScript.import", action: onImport
                )
                if mode == .new {
                    row(
                        "Answer a comment", detail: "Turn a question from your audience into a script", systemImage: "text.bubble",
                        style: .plain, identifier: "newScript.answer", action: onAnswer
                    )
                    Button(action: onFreestyle) {
                        HStack(spacing: 10) {
                            Circle().fill(Palette.record).frame(width: 10, height: 10)
                            Text("Record without a script").font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.ink2)
                        }
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .accessibilityIdentifier("newScript.freestyle")
                }
            }
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
    }

    private enum RowStyle { case ai, primary, plain }

    /// A full-width row: Let Cue write it in violet, the others in the sheet's grey.
    private func row(
        _ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String, style: RowStyle,
        badge: LocalizedStringKey? = nil, identifier: String, action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(style == .ai ? Palette.aiTextStrong : (style == .primary ? Palette.accText : Palette.ink))
                    .frame(width: 42, height: 42)
                    .background(
                        style == .ai ? Palette.aiFill : (style == .primary ? Palette.accSoft : Palette.overlayFill),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.body.weight(.semibold))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Palette.accText)
                                .padding(.horizontal, 7).frame(height: 20)
                                .background(Palette.accSoft, in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(style == .ai ? Palette.aiText : Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.ink)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
            .background(style == .ai ? Palette.aiFill : Palette.surface2, in: shape)
            .overlay(shape.strokeBorder(style == .ai ? Palette.aiBorder : (style == .primary ? Palette.acc : .clear), lineWidth: style == .primary ? 1.5 : 0.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        NewScriptSheet(mode: .new, onWrite: {}, onImport: {})
    }
}
#endif
