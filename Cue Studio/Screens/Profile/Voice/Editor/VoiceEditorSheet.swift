//
//  VoiceEditorSheet.swift
//  Cue Studio
//

import SwiftUI

/// The one editor of My Cue Voice (screen 2): a sheet with a line in mono capitals above the title ("Essentials · 2 of 4"), the field, and Done in
/// yellow. Every row of the page, the topics of Settings, the dock and the tip open it, so an answer is edited the same way wherever it is reached.
/// Answers are kept as they are given.
struct VoiceEditorSheet: View {
    let field: VoiceEditorField

    @Environment(CreatorProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    content
                }
                .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 32, trailing: Metrics.gutter))
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glassProminent)
                        .tint(Palette.acc)
                        .foregroundStyle(Palette.accInk)
                        .accessibilityIdentifier("voice.editor.done")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        // A container of its own: the sheet's identifier would otherwise replace its controls'.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice.editor.\(field.rawValue)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.eyebrow(for: profile.profile).uppercased())
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Palette.aiText)
                .accessibilityIdentifier("voice.editor.eyebrow")
            Text(field.title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.56)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch field {
        case .role: VoiceRoleField()
        case .topics: VoiceTopicsField()
        case .audience: VoiceAudienceField()
        case .tone: VoiceToneField()
        case .formats: VoiceFormatsField()
        case .phrases: VoicePhrasesField()
        case .reach: VoiceReachField()
        case .examples: VoiceExamplesField()
        }
    }
}
