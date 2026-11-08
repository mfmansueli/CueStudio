//
//  AutoEditSheet.swift
//  Cue Studio
//

import SwiftUI

/// Auto edit over the editor, half height so the preview stays in sight (`QuickEditViewModel+AutoEdit`): the steps to pick and
/// what each does; while it runs, what it is doing and Cancel; after, what each step did, Before | After and Turn off.
struct AutoEditSheet: View {
    @Bindable var viewModel: QuickEditViewModel
    @Bindable var session: AutoEditSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetHeader(title: String(localized: "Auto edit"), subtitle: subtitle)
                .padding(.horizontal, 16)
            switch session.phase {
            case .choosing: choosing
            case .working(let stage): working(stage)
            case .done: results
            }
        }
        .padding(.top, 8)
        .cueSheetChrome()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(session.isWorking)
        .onDisappear { viewModel.closeAutoEdit() }
    }

    private var subtitle: String {
        switch session.phase {
        case .choosing: String(localized: "A first pass with what you pick. Nothing else changes, and Undo takes it all back.")
        case .working: String(localized: "Nothing changes until it's done.")
        case .done: String(localized: "Check it on the video. Each step can be turned off on its own.")
        }
    }

    // MARK: - Choosing

    private var choosing: some View {
        Form {
            Section {
                Toggle(isOn: binding(.speech)) {
                    rowLabel(AutoEditStep.speech.title, String(localized: "Clear pauses, ums and earlier tries of a line (the last try stays)"))
                }
                .accessibilityIdentifier("edit.autoEdit.speech")
                Toggle(isOn: binding(.captions)) {
                    rowLabel(
                        AutoEditStep.captions.title,
                        viewModel.autoEditCanMakeCaptions
                            ? String(localized: "From your voice, in your caption style")
                            : String(localized: "This video has captions: they stay as they are")
                    )
                }
                .disabled(!viewModel.autoEditCanMakeCaptions)
                .accessibilityIdentifier("edit.autoEdit.captions")
                Toggle(isOn: binding(.zoom)) {
                    rowLabel(AutoEditStep.zoom.title, String(localized: "A short zoom on lines with a clear number, value or name"))
                }
                .disabled(!viewModel.autoEditCanZoom(session))
                .accessibilityIdentifier("edit.autoEdit.zoom")
                Toggle(isOn: binding(.punchIn)) {
                    rowLabel(
                        AutoEditStep.punchIn.title,
                        viewModel.autoEditCanPunchIn
                            ? String(localized: "Every other clip a little closer")
                            : String(localized: "Already on in this video")
                    )
                }
                .disabled(!viewModel.autoEditCanPunchIn)
                .accessibilityIdentifier("edit.autoEdit.punchIn")
                if session.isOn(.zoom) || session.isOn(.punchIn) {
                    Picker(String(localized: "Zoom"), selection: $session.zoomStrength) {
                        ForEach(PhraseZoom.Strength.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("edit.autoEdit.zoomStrength")
                }
            } footer: {
                Text("No music, effects, styles or other cuts are added.")
            }
        }
        .scrollContentBackground(.hidden)
        // At half height the steps can run past the fold: the button stays in sight.
        .safeAreaInset(edge: .bottom) {
            Button(String(localized: "Auto edit"), action: viewModel.runAutoEdit)
                .buttonStyle(.cuePrimary())
                .disabled(session.steps.isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .accessibilityIdentifier("edit.autoEdit.run")
        }
    }

    private func binding(_ step: AutoEditStep) -> Binding<Bool> {
        Binding(get: { session.isOn(step) }, set: { session.set(step, on: $0) })
    }

    private func rowLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(Palette.ink)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Working

    private func working(_ stage: AutoEditSession.Stage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                Text(stageText(stage))
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("edit.autoEdit.stage")
            }
            Button(String(localized: "Cancel"), role: .cancel, action: viewModel.cancelAutoEdit)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("edit.autoEdit.cancel")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func stageText(_ stage: AutoEditSession.Stage) -> String {
        switch stage {
        case .listening: String(localized: "Listening to the speech…")
        case .captions: String(localized: "Making captions…")
        case .applying: String(localized: "Putting it together…")
        }
    }

    // MARK: - Results

    private var results: some View {
        Form {
            Section {
                Picker(String(localized: "Compare"), selection: Binding(
                    get: { session.showsBefore }, set: { viewModel.showAutoEditBefore($0) }
                )) {
                    Text("Before").tag(true)
                    Text("After").tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.canCompareAutoEdit)
                .accessibilityIdentifier("edit.autoEdit.compare")
            } footer: {
                if !viewModel.canCompareAutoEdit {
                    Text("Before and After compare right after the run; Undo still takes it all back.")
                }
            }
            Section {
                ForEach(AutoEditStep.allCases) { step in
                    resultRow(step)
                }
            }
            Section {
                Button(String(localized: "Run again"), action: viewModel.autoEditAgain)
                    .disabled(session.showsBefore)
                    .accessibilityIdentifier("edit.autoEdit.again")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func resultRow(_ step: AutoEditStep) -> some View {
        HStack(spacing: 12) {
            rowLabel(step.title, viewModel.autoEditResult(step))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("edit.autoEdit.result.\(step.rawValue)")
            if viewModel.autoEditShownRecord?.isOn(step) == true {
                Button(String(localized: "Turn off")) { viewModel.turnOffAutoEditStep(step) }
                    .buttonStyle(.bordered)
                    .disabled(session.showsBefore)
                    .accessibilityIdentifier("edit.autoEdit.off.\(step.rawValue)")
            }
        }
    }
}
