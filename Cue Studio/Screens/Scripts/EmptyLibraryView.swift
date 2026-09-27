//
//  EmptyLibraryView.swift
//  Cue Studio
//

import SwiftUI

/// First run: nudges toward writing a script, but recording right away is one tap too.
struct EmptyLibraryView: View {
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
                GroupedCard(dividerInset: 72) {
                    option(title: "Write a script", detail: "Blank page, with read-time as you type", systemImage: "square.and.pencil", identifier: "empty.writeButton", action: onWrite)
                    option(title: "Import", detail: "Files, Google Docs exports or clipboard", systemImage: "doc.text", identifier: "empty.importButton", action: onImport)
                    option(title: "Generate with AI", detail: "Describe the video, get a first draft", systemImage: "sparkles", identifier: "empty.generateButton", highlighted: true, action: onGenerate)
                }
                Button(action: onSkip) {
                    HStack(spacing: 6) {
                        Text("Skip for now — record without a script")
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.hitTarget)
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("empty.skipButton")
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
                Image(systemName: "chevron.right")
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
    EmptyLibraryView(onWrite: {}, onImport: {}, onGenerate: {}, onSkip: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
