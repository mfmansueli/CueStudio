//
//  VoyageCard.swift
//  Cue Studio
//

import SwiftUI

/// The first voyage on Scripts and Takes: "YOUR FIRST VOYAGE · 3 OF 6", the six segments, the next step with what it takes, "All
/// steps" (the list) and the step's button, which goes straight to where it happens. A step done since the card was last seen lights
/// its segment up (it fills and glows, with a soft tap); with Reduce Motion it is simply filled. Once the first video is shared the
/// card says so, and Done ends the voyage. A card, not a layer over the screen: nothing waits for it.
struct VoyageCard: View {
    /// The tab the card is on: only the card on screen lights its segments (both tabs stay alive).
    let host: AppTab

    @Environment(FirstVoyageService.self) private var voyage
    @Environment(PresentationService.self) private var presentation
    @Environment(ScriptLibraryService.self) private var library
    @Environment(TakeLibraryService.self) private var takes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsSteps = false
    @State private var lighting: Set<VoyageStep> = []

    private static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        let progress = voyage.progress
        let unlit = Set(voyage.stepsToCelebrate)
        VStack(alignment: .leading, spacing: 12) {
            header(progress)
            VoyageProgressBar(done: progress.done, unlit: unlit, lighting: lighting)
            if let step = progress.current {
                next(step)
            } else {
                complete
            }
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 10, trailing: 16))
        .background(Palette.surface, in: Self.shape)
        .cardDepth(Self.shape)
        .sheet(isPresented: $showsSteps) { VoyageStepsSheet() }
        .task(id: CelebrationKey(done: progress.done, isOnScreen: isOnScreen)) { await celebrate() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voyage.card")
    }

    // MARK: - Parts

    private func header(_ progress: VoyageProgress) -> some View {
        HStack {
            Label {
                Text("YOUR FIRST VOYAGE")
            } icon: {
                Image(systemName: "star.fill").foregroundStyle(Palette.acc)
            }
            .labelStyle(VoyageEyebrowLabelStyle())
            .foregroundStyle(Palette.aiText)
            Spacer(minLength: 8)
            Text("\(progress.doneCount) OF \(VoyageProgress.stepCount)")
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("voyage.count")
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .tracking(1.2)
        .accessibilityElement(children: .combine)
    }

    private func next(_ step: VoyageStep) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { showsSteps = true } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.next)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("voyage.next")
                    Text(step.nextDetail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack {
                Button { showsSteps = true } label: {
                    HStack(spacing: 4) {
                        Text("All steps")
                        Image(systemName: "chevron.forward").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voyage.allSteps")
                Spacer(minLength: 8)
                Button(step.action) { navigator.start(step) }
                    .buttonStyle(.cuePrimary(.compact, expands: false))
                    .accessibilityIdentifier("voyage.action")
            }
        }
    }

    private var complete: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your first video is out there.")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("voyage.complete")
                Text("That's your first star. New tools will show up when they make sense for your videos.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer(minLength: 0)
                Button("Done") { withAnimation(.smooth(duration: 0.3)) { voyage.finish() } }
                    .buttonStyle(.cuePrimary(.compact, expands: false))
                    .accessibilityIdentifier("voyage.finish")
            }
        }
    }

    // MARK: - Lighting a step up

    private var isOnScreen: Bool {
        presentation.selectedTab == host && presentation.prompter == nil && presentation.sheet == nil
    }

    private var navigator: VoyageNavigator {
        VoyageNavigator(library: library, takes: takes, presentation: presentation)
    }

    /// The steps done since the card was last seen fill their segments, one soft tap, and a moment later they are simply done.
    private func celebrate() async {
        let steps = voyage.stepsToCelebrate
        guard isOnScreen, !steps.isEmpty else { return }
        if reduceMotion {
            voyage.markCelebrated(steps)
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        withAnimation(.smooth(duration: 0.6)) { lighting = Set(steps) }
        Haptics.soft()
        try? await Task.sleep(for: .milliseconds(1400))
        voyage.markCelebrated(steps)
        withAnimation(.smooth(duration: 0.5)) { lighting = [] }
    }

    private struct CelebrationKey: Equatable {
        let done: Set<VoyageStep>
        let isOnScreen: Bool
    }
}
