//
//  LanguagePickerView.swift
//  Cue Studio
//

import SwiftUI

/// One of the Language & Region lists: an automatic choice, then Cue's languages by their own name
/// (and in the interface language underneath). Voice Following also says, for each language,
/// whether this iPhone can listen in it. An unavailable one can still be picked (a download or an
/// update may bring it); the prompter then says it can't follow the words.
struct LanguagePickerView: View {
    struct Automatic {
        let title: String
        let detail: String
    }

    let title: LocalizedStringKey
    let automatic: Automatic
    let selection: CueLanguage?
    var showsVoiceFollowingAvailability = false
    let onPick: (CueLanguage?) -> Void

    @Environment(SpeechRecognitionManager.self) private var speech
    @Environment(\.dismiss) private var dismiss

    @State private var availability: [CueLanguage: VoiceFollowingAvailability] = [:]

    var body: some View {
        List {
            Section {
                option(title: automatic.title, detail: automatic.detail, id: "automatic", isSelected: selection == nil) {
                    pick(nil)
                }
            }
            Section {
                ForEach(CueLanguage.allCases) { language in
                    let status = availability[language]
                    option(
                        title: language.nativeName,
                        detail: language.localizedName == language.nativeName ? nil : language.localizedName,
                        status: status,
                        id: language.rawValue,
                        isSelected: selection == language
                    ) {
                        pick(language)
                    }
                }
            } footer: {
                if showsVoiceFollowingAvailability {
                    Text("Voice Following runs on this iPhone with Apple’s speech recognition. Nothing you say leaves the device.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard showsVoiceFollowingAvailability else { return }
            for language in CueLanguage.allCases {
                availability[language] = await speech.availability(of: language)
            }
        }
    }

    private func option(
        title: String, detail: String?, status: VoiceFollowingAvailability? = nil, id: String,
        isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).foregroundStyle(Palette.ink)
                    if let detail {
                        Text(verbatim: detail)
                            .font(.footnote)
                            .foregroundStyle(Palette.ink2)
                    }
                    if let status {
                        Text(status.label)
                            .font(.footnote)
                            .foregroundStyle(status == .unavailable ? Palette.warn : Palette.ink3)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.acc)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("languagePicker.option.\(id)")
    }

    private func pick(_ language: CueLanguage?) {
        onPick(language)
        dismiss()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        LanguagePickerView(
            title: "Voice Following Language",
            automatic: .init(title: "Same as Script", detail: "Listens in each script’s language"),
            selection: .portugueseBrazil,
            showsVoiceFollowingAvailability: true,
            onPick: { _ in }
        )
    }
    .previewEnvironment()
}
#endif
