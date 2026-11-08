//
//  MyWordsSheet.swift
//  Cue Studio
//

import SwiftUI

/// Captions › ••• › My words, over the editor (half height): the creator's names and terms, spelled as they want them, which
/// speech recognition listens for in new captions and recordings. A field adds one (Return or Add), a tap on a word changes its
/// spelling, a swipe deletes it. Nothing here changes the video's captions; it is kept on this iPhone, apart from My Cue Voice.
struct MyWordsSheet: View {
    @Bindable var captions: CaptionsViewModel

    @State private var typed = ""
    /// What the last Add said when it saved nothing new ("Already in My words"); cleared as the field changes.
    @State private var note: String?
    /// The word whose spelling is being changed, and the spelling typed for it.
    @State private var changing: String?
    @State private var changed = ""
    @FocusState private var fieldFocused: Bool

    private var canAdd: Bool { MyWordsList.isValid(MyWordsList.cleaned(typed)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: String(localized: "My words"), subtitle: String(localized: "Names and terms Cue listens for in new captions and recordings."))
                .padding(.horizontal, 16)
            addField
                .padding(.horizontal, 16)
            if let note {
                Text(note)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("edit.myWords.note")
            }
            if captions.myWords.isEmpty { emptyState } else { list }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("On this iPhone only. Never used for drafts.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(captions.myWords.count) of \(MyWordsList.limit)")
                    .monospacedDigit()
                    .accessibilityIdentifier("edit.myWords.count")
            }
            .font(.system(.footnote))
            .foregroundStyle(Palette.ink2)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .cueSheetChrome()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: typed) { note = nil }
        .alert(
            String(localized: "Change spelling"),
            isPresented: Binding(get: { changing != nil }, set: { if !$0 { changing = nil } }),
            presenting: changing
        ) { word in
            TextField(String(localized: "Word"), text: $changed)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("edit.myWords.changeField")
            Button(String(localized: "Cancel"), role: .cancel) { changing = nil }
            Button(String(localized: "Save")) {
                captions.changeMyWord(word, to: changed)
                changing = nil
            }
            .accessibilityIdentifier("edit.myWords.changeSave")
        } message: { _ in
            Text("Saved exactly as you type it.")
        }
        .accessibilityIdentifier("edit.myWords")
    }

    // MARK: - Adding

    private var addField: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.editorGlyph(EditorGlyph.row, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            // The prompt in `ink2`, as `SearchField`: the system's grey is far under 4.5:1 on the field's fill.
            TextField(String(localized: "Word"), text: $typed, prompt: Text("A name or term, as it's spelled").foregroundStyle(Palette.ink2))
                .font(.system(.body))
                .foregroundStyle(Palette.ink)
                // Brand names keep the capitals the creator types ("iPhone"), never the keyboard's.
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($fieldFocused)
                .onSubmit(add)
                .accessibilityLabel(Text("New word"))
                .accessibilityIdentifier("edit.myWords.field")
            PanelButton(label: String(localized: "Add"), isCompact: true, isEnabled: canAdd, identifier: "edit.myWords.add", action: add)
                .padding(.trailing, 6)
        }
        .padding(.leading, 12)
        .frame(minHeight: Metrics.hitTarget)
        .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous)
                .strokeBorder(fieldFocused ? Palette.acc : Color.clear, lineWidth: 1.5)
        )
    }

    private func add() {
        guard canAdd else { return }
        switch captions.addToMyWords(typed) {
        case .added, .respelled:
            typed = ""
        case .alreadyThere(let word):
            note = String(localized: "“\(word)” is already in My words")
        case .full:
            note = String(localized: "My words is full · Delete one to add another")
        case .invalid:
            break
        }
    }

    // MARK: - The list

    private var list: some View {
        List {
            ForEach(captions.myWords.words, id: \.self) { word in
                Button {
                    changed = word
                    changing = word
                } label: {
                    HStack(spacing: 10) {
                        Text(verbatim: word)
                            .font(.system(.body))
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "pencil")
                            .font(.editorGlyph(EditorGlyph.row))
                            .foregroundStyle(Palette.ink2)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Changes its spelling"))
                .listRowBackground(Palette.Editor.panelCard)
                .accessibilityIdentifier("edit.myWords.word.\(word)")
            }
            .onDelete { captions.deleteMyWords(atOffsets: $0) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("edit.myWords.list")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "character.book.closed")
                .font(.editorGlyph(EditorGlyph.button, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            Text("No words yet")
                .font(.system(.headline))
                .foregroundStyle(Palette.ink)
            Text("Add your brand, the people you mention and the terms you use.")
                .font(.system(.subheadline))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.myWords.empty")
    }
}
