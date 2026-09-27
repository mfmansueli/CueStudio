//
//  NewScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// "What are you recording?" — before the camera: write, paste, import, generate, pick a recent
/// script, or skip. In attach mode it adds a script to a freestyle recording.
struct NewScriptSheet: View {
    enum Mode { case new, attach }

    let mode: Mode
    let recent: [Script]
    let readSeconds: (Script) -> TimeInterval
    var onWrite: (() -> Void)?
    let onPaste: () -> Void
    let onImport: () -> Void
    let onGenerate: () -> Void
    let onPick: (Script) -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(mode == .attach ? "Add a script" : "What are you recording?")
                        .font(.title2.bold())
                    Text(mode == .attach
                         ? "Cue will scroll it under the lens. Your camera stays where it is."
                         : "A script keeps you on track and cuts retakes. Start one now, or skip it.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 18)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    if let onWrite {
                        tile("Write", detail: "Blank page", systemImage: "square.and.pencil", identifier: "newScript.write", action: onWrite)
                    }
                    tile("Paste", detail: "From clipboard", systemImage: "doc.on.clipboard", identifier: "newScript.paste", action: onPaste)
                    tile("Import", detail: "Files and exports", systemImage: "doc.text", identifier: "newScript.import", action: onImport)
                    tile("Generate", detail: "Draft with AI", systemImage: "sparkles", identifier: "newScript.generate", highlighted: true, action: onGenerate)
                }

                if !recent.isEmpty {
                    SectionHeading(text: String(localized: "Or use a script"))
                        .padding(EdgeInsets(top: 22, leading: 4, bottom: 8, trailing: 4))
                    GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius, dividerInset: 34) {
                        ForEach(recent) { script in
                            Button { onPick(script) } label: {
                                HStack(spacing: 12) {
                                    ColorDot(color: script.platform.tint, size: 8)
                                    Text(script.displayTitle)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("~\(DurationText.short(readSeconds(script)))")
                                        .font(.footnote)
                                        .foregroundStyle(Palette.ink2)
                                }
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let onSkip {
                    Button(action: onSkip) {
                        HStack(spacing: 10) {
                            Circle().fill(Palette.record).frame(width: 12, height: 12)
                            Text("Record without a script")
                        }
                    }
                    .buttonStyle(.cueOutline(.large))
                    .padding(.top, 18)
                    .accessibilityIdentifier("newScript.skip")
                    Text("You can add a script later, right from the camera.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
            }
            .padding(EdgeInsets(top: 24, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surface)
    }

    private func tile(
        _ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String,
        identifier: String, highlighted: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(highlighted ? Palette.acc.opacity(0.75) : Palette.ink2)
                }
            }
            .foregroundStyle(highlighted ? Palette.acc : Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(highlighted ? Palette.acc.opacity(0.12) : Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            .overlay {
                if highlighted {
                    RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
                        .strokeBorder(Palette.accLine, lineWidth: 0.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        NewScriptSheet(
            mode: .new, recent: Array(SampleScripts.all.prefix(3)), readSeconds: { _ in 62 },
            onWrite: {}, onPaste: {}, onImport: {}, onGenerate: {}, onPick: { _ in }, onSkip: {}
        )
    }
}
#endif
