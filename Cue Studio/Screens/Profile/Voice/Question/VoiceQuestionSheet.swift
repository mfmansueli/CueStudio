//
//  VoiceQuestionSheet.swift
//  Cue Studio
//

import SwiftUI

/// The My Cue Voice question sheet (04 §F9): the system's sheet, a grabber, the close button in a glass circle (leading; it counts as
/// "Not now"), "My Cue Voice · ✦ nn%" in the bar, the question as a large title, the answers as an inset-grouped list (one tap is the
/// answer), then "+ Something else" (violet) and "None of these". A list that takes several answers has Save. After an answer it says
/// "Saved · voice nn%" and offers one more question.
struct VoiceQuestionSheet: View {
    @State private var model: VoiceQuestionSheetModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldIsFocused: Bool

    init(model: VoiceQuestionSheetModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.question == .example {
                    VoiceExamplesBody()
                } else if let saved = model.savedStrength {
                    savedView(strength: saved)
                } else {
                    list
                }
            }
            .navigationTitle("My Cue Voice")
            .navigationSubtitle("✦ \(model.strength)%")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }.accessibilityIdentifier("sheet.closeButton")
                }
                if model.savedStrength == nil, case .multiple = model.kind {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { model.save() }.accessibilityIdentifier("voice.sheet.save")
                    }
                }
            }
        }
        .presentationDetents(model.mode == .tip ? [.medium, .large] : [.large])
        .presentationDragIndicator(.visible)
        .onDisappear { model.dismissedWithoutAnswer() }
        .onChange(of: model.shouldClose) { _, shouldClose in
            guard shouldClose else { return }
            Task {
                // The "Saved" shows for a moment, then the sheet goes.
                try? await Task.sleep(for: .milliseconds(900))
                dismiss()
            }
        }
        // A container of its own: the sheet's identifier would otherwise replace its controls'.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice.sheet.\(model.question.rawValue)")
    }

    // MARK: - The question

    private var list: some View {
        List {
            Section {
                ForEach(model.options) { option in
                    answerRow(option)
                }
                if model.allowsSomethingElse { somethingElse }
                if model.allowsNone { noneRow }
            } header: {
                Text(model.title)
                    .font(.title2.bold())
                    .foregroundStyle(Palette.ink)
                    .textCase(nil)
                    .padding(.bottom, 6)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("voice.sheet.title")
            } footer: {
                if case .multiple(let limit) = model.kind {
                    Text("Pick up to \(limit) · tap again to remove")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                } else {
                    Text("Change it anytime in Profile › My Cue Voice.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if model.question.kind == .freeTextFirst {
                model.showsSomethingElse = true
                fieldIsFocused = true
            }
        }
    }

    private func answerRow(_ option: VoiceOption) -> some View {
        let isOn = model.isSelected(option)
        return Button {
            Haptics.selection()
            model.choose(option)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label).font(.body).foregroundStyle(Palette.ink)
                    if let detail = option.detail {
                        Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isOn {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.accText)
                }
            }
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("voice.option.\(option.id)")
        .listRowBackground(Palette.surface2.opacity(0.7))
    }

    // MARK: - Something else, None of these

    @ViewBuilder
    private var somethingElse: some View {
        if model.showsSomethingElse {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    TextField(String(localized: "Type yours"), text: $model.typed)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($fieldIsFocused)
                        .onSubmit { model.addSomethingElse() }
                        .accessibilityIdentifier("voice.field")
                    Button("Save") { model.addSomethingElse() }
                        .buttonStyle(.cueSecondary(.compact, expands: false))
                        .disabled(model.typed.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("voice.add")
                }
                if let feedback = model.feedback { feedbackView(feedback) }
            }
            .padding(.vertical, 4)
            .listRowBackground(Palette.surface2.opacity(0.7))
        } else {
            Button {
                model.showsSomethingElse = true
                fieldIsFocused = true
            } label: {
                Text("+ Something else")
                    .font(.body)
                    .foregroundStyle(Palette.aiText)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice.somethingElse")
            .listRowBackground(Palette.surface2.opacity(0.7))
        }
    }

    private var noneRow: some View {
        Button { model.none() } label: {
            Text("None of these")
                .font(.body)
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voice.sheet.none")
        .listRowBackground(Palette.surface2.opacity(0.7))
    }

    @ViewBuilder
    private func feedbackView(_ feedback: VoiceQuestionSheetModel.Feedback) -> some View {
        switch feedback {
        case .message(let text):
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.warnText)
                .accessibilityIdentifier("voice.feedback")
        case .typo(let suggestion, let original):
            HStack(spacing: 10) {
                Text("Did you mean “\(suggestion)”?")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Use “\(suggestion)”") { model.useSuggestion(suggestion) }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .accessibilityIdentifier("voice.typo.use")
                Button("Keep mine") { model.keepTyped(original) }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("voice.typo.keep")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("voice.feedback")
        }
    }

    // MARK: - Saved

    private func savedView(strength: Int) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Text("Saved · voice \(strength)%")
                .font(.title2.bold())
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier("voice.saved")
            if model.canAskMore {
                Button("One more question") { model.askMore() }
                    .buttonStyle(.cuePrimary(.large, expands: false))
                    .accessibilityIdentifier("voice.more")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(Metrics.gutter)
    }
}
