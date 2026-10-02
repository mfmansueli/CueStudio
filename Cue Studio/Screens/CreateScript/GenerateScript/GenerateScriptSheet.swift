//
//  GenerateScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Generate with AI · Apple Intelligence · private · no cost": Prompt, Themes or Formats (which
/// pushes the format's brief). Calls `onCreated` with the new script. Opened from the idea card
/// (`ideaDraft`), it shows the request filled in, with the platform, length and voice to confirm;
/// nothing is written until "Generate script" is tapped.
struct GenerateScriptSheet: View {
    @State private var viewModel: GenerateScriptViewModel
    let onCreated: (Script) -> Void

    @Environment(\.dismiss) private var dismiss

    init(services: AppServices, initialTab: GenerateTab = .prompt, ideaDraft: IdeaDraftService? = nil, onCreated: @escaping (Script) -> Void) {
        _viewModel = State(initialValue: GenerateScriptViewModel(
            initialTab: initialTab,
            ideaDraft: ideaDraft,
            writer: services.writer,
            library: services.library,
            profile: services.profile,
            rules: services.rules,
            toast: services.toast,
            scriptLanguage: services.languages.scriptLanguage,
            interfaceLanguage: services.languages.interfaceLanguage
        ))
        self.onCreated = onCreated
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Picker("Generate from", selection: $viewModel.tab) {
                        ForEach(GenerateTab.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("generate.tabs")
                    switch viewModel.tab {
                    case .prompt:
                        PromptTabView(viewModel: viewModel) {
                            viewModel.startPromptGeneration(onCreated: onCreated)
                        }
                    case .themes:
                        ThemesTabView(viewModel: viewModel)
                    case .formats:
                        FormatsTabView(viewModel: viewModel)
                    }
                }
                .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 28, trailing: Metrics.gutter))
                .animation(.smooth(duration: 0.2), value: viewModel.tab)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(item: $viewModel.selectedType) { type in
                ScriptBriefView(viewModel: viewModel, type: type) {
                    viewModel.startBriefGeneration(onCreated: onCreated)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel(Text("Close"))
                    }
                }
            }
        }
        // Closing the screen stops a request that is still running: nothing is created behind its back.
        .onDisappear { viewModel.cancelGeneration() }
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
        .alert("Couldn't write the script", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Try again") { viewModel.retryGeneration(onCreated: onCreated) }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Generate with AI")
                    .font(.title2.bold())
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").foregroundStyle(Palette.accText)
                    Text("Apple Intelligence").fontWeight(.semibold).foregroundStyle(Palette.ink)
                    Text("· private · no cost").foregroundStyle(Palette.ink2)
                }
                .font(.footnote)
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink2)
            }
            .buttonStyle(.cueIcon(.surface, diameter: 32))
            .accessibilityLabel(Text("Close"))
        }
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        GenerateScriptSheet(services: .preview, onCreated: { _ in })
    }
    .previewEnvironment()
}
#endif
