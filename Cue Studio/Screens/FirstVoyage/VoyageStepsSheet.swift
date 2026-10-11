//
//  VoyageStepsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Your first voyage": the six steps, done, next (with Start) and ahead, and "Hide guide" at the bottom, which says where the guide
/// comes back. Nothing in it is locked: Start goes straight to where the next step happens.
struct VoyageStepsSheet: View {
    @Environment(FirstVoyageService.self) private var voyage
    @Environment(PresentationService.self) private var presentation
    @Environment(ScriptLibraryService.self) private var library
    @Environment(TakeLibraryService.self) private var takes
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let progress = voyage.progress
        VStack(alignment: .leading, spacing: 0) {
            Text("Your first voyage")
                .font(.title2.weight(.bold))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Six steps from an idea to your first star. Go at your own pace; nothing here is locked.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            VStack(spacing: 4) {
                ForEach(VoyageStep.allCases) { step in
                    VoyageStepRow(step: step, state: state(of: step, in: progress)) { start(step) }
                }
            }
            .padding(.top, 18)
            VStack(spacing: 2) {
                Button("Hide guide") {
                    voyage.setOn(false)
                    dismiss()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("voyage.hide")
                Text("You can bring it back in Settings › Personalize.")
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 20)
        .fittedSheet()
        .accessibilityIdentifier("voyage.steps")
    }

    private func state(of step: VoyageStep, in progress: VoyageProgress) -> VoyageStepRow.State {
        if progress.done.contains(step) { return .done }
        return progress.current == step ? .next : .ahead
    }

    /// The sheet goes first, then the step opens (the prompter or the review would sit over a closing sheet).
    private func start(_ step: VoyageStep) {
        dismiss()
        let navigator = VoyageNavigator(library: library, takes: takes, presentation: presentation)
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            navigator.start(step)
        }
    }
}
