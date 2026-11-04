//
//  UltraLabView.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// Settings › Privacy & AI data › Ultra AI · Lab (Debug only): writes one idea with Ultra AI under a length condition (free, about 90 s as a
/// reference, 60–90 s required) and shows the draft, the polished script, the editor's changes, each call's time and tokens, what the script
/// cost, and the lab's calls left. Above, what every Ultra script and fit from this iPhone cost (`UltraSpendLedger`). It uses the same service
/// and permission as the Scripts screen: nothing goes out until Ultra AI is allowed.
struct UltraLabView: View {
    @State private var model: UltraLabViewModel?
    @State private var asksPermission = false
    @AppStorage(UltraLabProvider.key) private var provider = UltraLabProvider.cueServer
    @AppStorage(UltraLabEffort.key) private var effort = UltraLabEffort.high

    @Environment(UltraScriptService.self) private var ultra
    @Environment(ScriptStarter.self) private var starter
    @Environment(ScriptLibraryService.self) private var library
    @Environment(LanguageService.self) private var languages
    @Environment(PresentationService.self) private var presentation

    var body: some View {
        ZStack {
            // Never empty: an empty view never appears, so the lab was never made and the screen stayed black (the owner saw it, 29/10/2026).
            Color.clear
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
                Text(verbatim: "Two or three calls a script (the steps below). Failed calls count too.")
                    .foregroundStyle(Palette.ink2)
            }
            writer(model)
            if let spend = model.ultra.spend { cost(spend) }
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
                    Button { allowance.setFreeLeft(0) } label: { Text(verbatim: "Use up the free scripts") }
                        .accessibilityIdentifier("ultraLab.useUpAllowance")
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
                Picker(selection: $model.flow) {
                    Text(verbatim: "Draft · check · polish").tag(UltraFlow.checked)
                    Text(verbatim: "Draft · polish").tag(UltraFlow.polished)
                } label: {
                    Text(verbatim: "Steps")
                }
                .pickerStyle(.segmented)
                .disabled(model.isWorking)
                .accessibilityIdentifier("ultraLab.flow")
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
        // The keyboard would cover "Write with Ultra AI": a scroll closes it.
        .scrollDismissesKeyboard(.immediately)
        .sheet(isPresented: $asksPermission) {
            UltraConsentSheet { model.ultra.consent.grant() }
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
        if run.checked != nil {
            Section {
                if run.corrections.isEmpty {
                    Text(verbatim: "Nothing to correct.").foregroundStyle(Palette.ink2)
                }
                ForEach(Array(run.corrections.enumerated()), id: \.offset) { Text($0.element).foregroundStyle(Palette.ink2) }
            } header: {
                Text(verbatim: "What the check corrected")
            }
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
            if let seconds = run.checkSeconds, let reply = run.checkReply { callRow("Check", seconds: seconds, reply: reply) }
            callRow("Polish", seconds: run.reviewSeconds, reply: run.reviewReply)
            LabeledContent {
                // A call more than the steps is the fit that followed by itself.
                let fitted = run.cost.calls > run.flow.calls ? ", fit included" : ""
                Text(verbatim: "\(run.cost.calls) calls\(fitted) · \(Self.dollars(run.cost.dollars()))")
                    .monoFont(size: 11)
                    .foregroundStyle(Palette.ink)
            } label: {
                Text(verbatim: "Cost")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ultraLab.runCost")
        } header: {
            Text(verbatim: "Calls")
        }
    }

    /// Who writes Ultra AI's scripts on this iPhone, here and on Scripts: Gemini or Claude (`UltraLabProvider`), for the comparison.
    private func writer(_ model: UltraLabViewModel) -> some View {
        Section {
            Picker(selection: $provider) {
                ForEach(UltraLabProvider.allCases) { Text(verbatim: $0.label).tag($0) }
            } label: {
                Text(verbatim: "Model")
            }
            .disabled(model.isWorking)
            .accessibilityIdentifier("ultraLab.provider")
            if provider.claudeModel != nil {
                Picker(selection: $effort) {
                    ForEach(UltraLabEffort.allCases) { Text(verbatim: $0.label).tag($0) }
                } label: {
                    Text(verbatim: "Effort")
                }
                .pickerStyle(.segmented)
                .disabled(model.isWorking)
                .accessibilityIdentifier("ultraLab.effort")
            }
        } header: {
            Text(verbatim: "Who writes")
        } footer: {
            Text(verbatim: "Gemini: the lab’s Firebase app (\(UltraLabConfiguration.isPresent ? "set up" : "not on this iPhone")). Claude: the key copied by tools/ultra/install-claude-key.sh (\(ClaudeLabConfiguration.isPresent ? "set up" : "not on this iPhone")), a call straight to the Claude API; lower effort thinks less, so it costs less. The permission sheet still says Google.")
                .foregroundStyle(Palette.ink2)
        }
    }

    /// What every Ultra script and fit from this iPhone cost, finished or not, and what a finished one costs on average and at most.
    private func cost(_ spend: UltraSpendLedger) -> some View {
        Section {
            LabeledContent {
                Text(verbatim: "\(Self.dollars(spend.total.dollars())) · \(spend.total.calls) calls")
            } label: {
                Text(verbatim: "Spent on this iPhone")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ultraLab.spend.total")
            if let scripts = spend.summary(of: .script) {
                summaryRow("Per script (\(scripts.count))", scripts).accessibilityIdentifier("ultraLab.spend.scripts")
            }
            if let fits = spend.summary(of: .fit) {
                summaryRow("Per fit (\(fits.count))", fits).accessibilityIdentifier("ultraLab.spend.fits")
            }
            Button { spend.startOver() } label: { Text(verbatim: "Start a new measurement") }
                .disabled(spend.total.calls == 0)
                .accessibilityIdentifier("ultraLab.spend.startOver")
        } header: {
            Text(verbatim: "Cost")
        } footer: {
            Text(verbatim: "The provider’s own token counts for every call, at the price of the model picked above (\(provider.label)): USD \(Self.rate(UltraPrice.current.inputPerMillion)) per million tokens in, \(Self.rate(UltraPrice.current.outputPerMillion)) per million out (thinking included). Start a new measurement when you switch models: the totals are priced at the model picked now. Failed and stopped requests count in the total, not in the averages. Google’s bill for every phone together: tools/ultra/spend.js.")
                .foregroundStyle(Palette.ink2)
        }
    }

    private func summaryRow(_ title: String, _ summary: UltraSpendSummary) -> some View {
        LabeledContent {
            Text(verbatim: "\(Self.dollars(summary.mean)) average · \(Self.dollars(summary.most)) most")
        } label: {
            Text(verbatim: title)
        }
        .accessibilityElement(children: .combine)
    }

    /// Dollars to a tenth of a cent: a script costs a few cents.
    private static func dollars(_ amount: Double) -> String {
        amount.formatted(.currency(code: "USD").precision(.fractionLength(3)))
    }

    private static func rate(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(2)))
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
