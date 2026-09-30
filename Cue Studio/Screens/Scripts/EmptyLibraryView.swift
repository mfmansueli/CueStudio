//
//  EmptyLibraryView.swift
//  Cue Studio
//

import SwiftUI

/// First run: nudges toward a script (the prompt box first), but recording right away is one tap too.
struct EmptyLibraryView: View {
    var animatesPromptBackground = true
    let onPrompt: () -> Void
    let onWrite: () -> Void
    let onImport: () -> Void
    let onGenerate: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start with a script.\nSound like you rehearsed.")
                        .font(.title.bold())
                        .foregroundStyle(Palette.ink)
                    Text("Write, paste or import what you want to say. Cue scrolls it right under the lens while you record.")
                        .font(.body)
                        .foregroundStyle(Palette.ink2)
                }
                PromptCard(base: Palette.surface, animatesBackground: animatesPromptBackground, action: onPrompt)
                    .accessibilityIdentifier("empty.promptCard")
                GroupedCard(dividerInset: 72) {
                    option(
                        title: "Write a script", detail: "Blank page, with read-time as you type",
                        systemImage: "pencil.line", identifier: "empty.writeButton", action: onWrite
                    )
                    option(title: "Import", detail: "Files or clipboard", systemImage: "doc.text", identifier: "empty.importButton", action: onImport)
                    option(
                        title: "Generate with AI", detail: "Describe the video, get a first draft",
                        systemImage: "sparkles", identifier: "empty.generateButton", highlighted: true, action: onGenerate
                    )
                }
                VStack(spacing: 10) {
                    Button(action: onSkip) {
                        HStack(spacing: 10) {
                            Circle().fill(Palette.record).frame(width: 12, height: 12)
                            Text("Record without a script")
                            Image(systemName: "chevron.forward").font(.footnote.weight(.bold))
                        }
                    }
                    .buttonStyle(.cueOutline(.large))
                    .accessibilityIdentifier("empty.skipButton")
                    Text("Freestyle now — add a script anytime from the camera.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Metrics.textGutter)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    private func option(
        title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String,
        identifier: String, highlighted: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(highlighted ? Palette.acc : Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(highlighted ? Palette.accSoft : Palette.surface2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    EmptyLibraryView(onPrompt: {}, onWrite: {}, onImport: {}, onGenerate: {}, onSkip: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
