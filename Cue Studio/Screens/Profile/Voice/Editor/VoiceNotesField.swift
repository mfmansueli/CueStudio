//
//  VoiceNotesField.swift
//  Cue Studio
//

import SwiftUI

/// "Also true about me" (the owner's item 7, 02/11/2026): the notes in the creator's own words that no question has a place for, each one shown,
/// changed with a tap and removed with ✕, and a field to add another.
struct VoiceNotesField: View {
    @Environment(CreatorProfileService.self) private var profile

    @State private var editing: String?

    private var notes: [String] { profile.profile.notes }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !notes.isEmpty {
                GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 16) {
                    ForEach(notes, id: \.self) { note in
                        if editing == note {
                            VoiceTypedField(
                                placeholder: note,
                                submit: { text, _ in
                                    let result = profile.replaceNote(note, with: text)
                                    if result == .added || result == .removed { editing = nil }
                                    return result
                                },
                                addLabel: String(localized: "Save"), initialText: note, clearsWhenAdded: false, identifier: "voice.notes.edit"
                            )
                            .padding(8)
                        } else {
                            row(note)
                        }
                    }
                }
            }
            VoiceTypedField(
                placeholder: String(localized: "e.g. I film in my car on the way to work"),
                submit: { text, _ in profile.addNote(text) },
                identifier: "voice.notes.field"
            )
            Text("Add anything true about you that the questions don’t ask.")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
    }

    private func row(_ note: String) -> some View {
        HStack {
            Button {
                editing = note
            } label: {
                Text(note)
                    .cueFont(.body)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Change it"))
            .accessibilityIdentifier("voice.note")
            Button {
                profile.removeNote(note)
            } label: {
                Image(systemName: "xmark")
                    .cueFont(.footnote, weight: .bold)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            }
            .accessibilityLabel(Text("Remove \(note)"))
            .accessibilityIdentifier("voice.note.remove")
        }
        .padding(.leading, 16)
    }
}
