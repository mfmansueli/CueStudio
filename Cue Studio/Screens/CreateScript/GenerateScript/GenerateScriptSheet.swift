//
//  GenerateScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// Two steps: format, then brief. Calls `onCreated` with the new script.
struct GenerateScriptSheet: View {
    @State private var viewModel: GenerateScriptViewModel
    let onCreated: (Script) -> Void

    @Environment(\.dismiss) private var dismiss

    init(services: AppServices, onCreated: @escaping (Script) -> Void) {
        let store = services.store
        _viewModel = State(initialValue: GenerateScriptViewModel(
            writer: services.writer,
            library: services.library,
            profile: services.profile,
            quota: services.quota,
            tier: { store.tier },
            toast: services.toast
        ))
        self.onCreated = onCreated
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScriptTypePickerView(viewModel: viewModel, onClose: { dismiss() })
                .navigationDestination(item: $viewModel.selectedType) { type in
                    ScriptBriefView(viewModel: viewModel, type: type) {
                        Task {
                            if let script = await viewModel.generate() {
                                onCreated(script)
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { dismiss() } label: { Image(systemName: "xmark") }
                                .accessibilityLabel(Text("Close"))
                        }
                    }
                }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .fullScreenCover(item: $viewModel.paywall) { context in
            PaywallView(context: context)
        }
        .alert("Couldn't write the script", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
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
