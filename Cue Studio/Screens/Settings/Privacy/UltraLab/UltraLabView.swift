//
//  UltraLabView.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// Settings › Privacy & AI data › Ultra AI · Lab (Debug only): writes one idea with Ultra AI under a length condition (free, about 90 s as a
/// reference, 60–90 s required) and shows the draft, the polished script, the editor's changes, each call's time and tokens, and the lab's calls
/// left. It uses the same service and permission as the Scripts screen: nothing goes out until Ultra AI is allowed.
struct UltraLabView: View {
    @State private var model: UltraLabViewModel?
    @State private var asksPermission = false

    @Environment(UltraScriptService.self) private var ultra
    @Environment(ScriptStarter.self) private var starter
    @Environment(ScriptLibraryService.self) private var library
    @Environment(LanguageService.self) private var languages
    @Environment(PresentationService.self) private var presentation

    var body: some View {
        Group {
            if let model { lab(model) }
        }
        .navigationTitle(Text(verbatim: "Ultra AI · Lab"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if model == nil { model = UltraLabViewModel(ultra: ultra, starter: starter, library: library, languages: languages) }
        }
        .onDisappear { model?.stop() }
    }

    private func lab(_ model: UltraLabViewModel) -> some View {
        @Bindable var model = model
        return List {
            Section {
                if !model.ultra.consent.isGranted {
                    Button { asksPermission = true } label: { Text(verbatim: "Allow Ultra AI…") }
                        .accessibilityIdentifier("ultraLab.allow")
                }
                LabeledContent { Text(verbatim: "\(model.ultra.budget.remaining) / \(model.ultra.budget.limit)") } label: { Text(verbatim: "Test calls left") }
                    .accessibilityIdentifier("ultraLab.budget")
            } footer: {
                Text(verbatim: "Two calls a script: the draft and its polish. Failed calls count too.")
                    .foregroundStyle(Palette.ink2)
            }
            if let allowance = model.ultra.allowance {
                Section {
                    LabeledContent {
                        Text(verbatim: UltraAllowanceLabels.menu(allowance.allowance))
                    } label: {
                        Text(verbatim: "Creator’s scripts")
                    }
                    .accessibilityIdentifier("ultraLab.allowance")
                    Button { allowance.resetPreview() } label: { Text(verbatim: "Give the free scripts back") }
                        .accessibilityIdentifier("ultraLab.resetAllowance")
                    Button { model.ultra.invite?.reopen() } label: { Text(verbatim: "Show the invitation again") }
                        .accessibilityIdentifier("ultraLab.resetInvite")
                } header: {
                    Text(verbatim: "Preview of the free scripts")
                } footer: {
                    Text(verbatim: "What a creator would see, kept on this iPhone to judge the product: not a protection of credits (that needs a server). The lab’s scripts don’t count here; the test calls above are never given back. The invitation shows only while Ultra AI isn’t allowed (Privacy & AI data › Ultra AI off).")
                        .foregroundStyle(Palette.ink2)
                }
            }
            Section {
                TextField(text: $model.prompt, axis: .vertical) { Text(verbatim: "Your idea, as you’d type it on Scripts") }
                    .lineLimit(3...8)
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("ultraLab.prompt")
                Picker(selection: $model.length) {
                    ForEach(UltraLabLength.allCases) { Text(verbatim: $0.label).tag($0) }
                } label: {
                    Text(verbatim: "Length")
                }
                .pickerStyle(.segmented)
                .disabled(model.isWorking)
                .accessibilityIdentifier("ultraLab.length")
                DisclosureGroup("What Cue sends") {
                    UltraPayloadView(payload: model.payload)
                }
            } header: {
                Text(verbatim: "Idea")
            }
            Section {
                if model.isWorking {
                    HStack {
                        ProgressView()
                        if let meter = model.meter { WritingProgressLabel(meter: meter).foregroundStyle(Palette.ink2) }
                        Spacer()
                        Button("Stop", role: .cancel) { model.stop() }
                            .accessibilityIdentifier("ultraLab.stop")
                    }
                } else {
                    Button { model.generate() } label: { Text(verbatim: "Write with Ultra AI") }
                        .disabled(!model.canGenerate)
                        .accessibilityIdentifier("ultraLab.generate")
                }
                if let failure = model.failure {
                    Text(failure).foregroundStyle(Palette.warnText).accessibilityIdentifier("ultraLab.failure")
                }
            }
            if let run = model.run { result(run, model: model) }
            if let draft = model.unfinishedDraft {
                Section {
                    Text(draft).textSelection(.enabled).foregroundStyle(Palette.ink2)
                } header: {
                    Text(verbatim: "Unfinished draft · not saved")
                } footer: {
                    Text(verbatim: "The polish failed, so this draft isn’t a finished Ultra AI script.")
                }
            }
        }
        .cueGroupedList()
        .sheet(isPresented: $asksPermission) {
            UltraConsentSheet(payload: model.payload) { model.ultra.consent.grant() }
        }
    }

    @ViewBuilder
    private func result(_ run: UltraRun, model: UltraLabViewModel) -> some View {
        Section {
            Text(run.script.title).font(.headline).foregroundStyle(Palette.ink)
            Text(run.script.text).textSelection(.enabled).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("ultraLab.script")
            if let seconds = model.estimatedSeconds {
                Text(verbatim: "About \(seconds) s at a natural pace (estimated from the words, not a reading)")
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            Button {
                if let id = model.save() { presentation.openScript(id, editing: true) }
            } label: {
                Text(verbatim: model.savedID == nil ? "Save and open" : "Open the saved script")
            }
            .accessibilityIdentifier("ultraLab.save")
        } header: {
            Text(verbatim: "Script")
        }
        Section {
            Text(run.draft).textSelection(.enabled).foregroundStyle(Palette.ink2)
        } header: {
            Text(verbatim: "Draft")
        }
        if !run.changes.isEmpty {
            Section {
                ForEach(Array(run.changes.enumerated()), id: \.offset) { Text($0.element).foregroundStyle(Palette.ink2) }
            } header: {
                Text(verbatim: "What the polish changed")
            }
        }
        Section {
            callRow("Draft", seconds: run.draftSeconds, reply: run.draftReply)
            callRow("Polish", seconds: run.reviewSeconds, reply: run.reviewReply)
        } header: {
            Text(verbatim: "Calls")
        }
    }

    private func callRow(_ title: String, seconds: Double, reply: UltraModelReply) -> some View {
        LabeledContent {
            Text(verbatim: "\(Int(seconds.rounded())) s · in \(reply.promptTokens ?? 0) · out \(reply.outputTokens ?? 0) · thinking \(reply.thinkingTokens ?? 0)")
                .monoFont(size: 11)
                .foregroundStyle(Palette.ink2)
        } label: {
            Text(verbatim: title)
        }
    }
}
#endif
