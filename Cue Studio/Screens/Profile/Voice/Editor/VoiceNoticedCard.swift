//
//  VoiceNoticedCard.swift
//  Cue Studio
//

import SwiftUI

/// "✦ Cue noticed · right?" (the owner's item 6, 02/11/2026): what Cue can tell from what the creator did (`VoiceInference`), each with what it is
/// based on, **Yes** to keep it and **Change** to answer it in the editor. Shown on the voice page only while there is something to confirm.
struct VoiceNoticedCard: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ScriptLibraryService.self) private var library
    @Environment(TakeLibraryService.self) private var takes
    @Environment(ExportLedgerService.self) private var ledger
    @Environment(LanguageService.self) private var languages

    let onChange: (VoiceEditorField) -> Void

    private var suggestions: [VoiceInference.Suggestion] {
        let code = (languages.scriptLanguage ?? languages.interfaceLanguage).rawValue
        let exports = ledger.operations.filter { !$0.deliveries.isEmpty }.sorted { $0.createdAt < $1.createdAt }.map { operation in
            VoiceInference.Export(
                platform: operation.deliveries.lazy.compactMap(VoiceInference.platform(of:)).first,
                seconds: takes.takes.first { $0.id == operation.takeID }?.duration
            )
        }
        return VoiceInference.suggestions(
            for: profile.profile, scripts: library.scripts, exports: exports, deviceGender: WordGender.fromThisDevice,
            asksGender: AgreementGuide.genderExample(in: code, team: false) != nil
        )
    }

    var body: some View {
        let suggestions = suggestions
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("✦ Cue noticed · right?")
                    .monoFont(size: 10.5, weight: .bold)
                    .interfaceTracking(1)
                    .foregroundStyle(Palette.aiText)
                ForEach(suggestions) { row($0) }
            }
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
            .accessibilityIdentifier("voicePage.noticed")
        }
    }

    private func row(_ suggestion: VoiceInference.Suggestion) -> some View {
        let (title, value, basis, field) = describe(suggestion)
        return VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).cueFont(.footnote).foregroundStyle(Palette.ink2)
                Text(value).cueFont(16, weight: .semibold).foregroundStyle(Palette.ink)
                Text(basis).cueFont(.footnote).foregroundStyle(Palette.ink2)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 8) {
                Button {
                    Haptics.selection()
                    withAnimation(.easeOut(duration: 0.25)) { profile.confirm(suggestion) }
                } label: {
                    Text("Yes").frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.acc)
                .foregroundStyle(Palette.accInk)
                .accessibilityIdentifier("voicePage.noticed.yes.\(suggestion.id)")
                Button {
                    onChange(field)
                } label: {
                    Text("Change").frame(minWidth: 64)
                }
                .buttonStyle(.bordered)
                .tint(Palette.ink2)
                .accessibilityIdentifier("voicePage.noticed.change.\(suggestion.id)")
            }
            .cueFont(.subheadline, weight: .semibold)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
    }

    private func describe(_ suggestion: VoiceInference.Suggestion) -> (String, String, String, VoiceEditorField) {
        switch suggestion {
        case .formats(let kinds, _):
            (String(localized: "What you film most"), kinds.map(\.label).joined(separator: " · "), String(localized: "From your recent scripts"), .formats)
        case .reach(let platform, let length, _):
            (
                String(localized: "Where you post most · how long"), ([platform.label] + [length?.label].compactMap { $0 }).joined(separator: " · "),
                String(localized: "From your recent exports"), .reach
            )
        case .gender(let gender):
            (String(localized: "Write me as"), gender.label, String(localized: "From your iPhone"), .role)
        }
    }
}
