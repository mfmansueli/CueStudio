//
//  VoyageStrip.swift
//  Cue Studio
//

import SwiftUI

/// The first voyage on an empty Scripts: a slim strip over "How do you want to start?", whose three ways in are the first step
/// itself, so the strip has no button of its own. A tap opens the list of steps.
struct VoyageStrip: View {
    @Environment(FirstVoyageService.self) private var voyage

    @State private var showsSteps = false

    private static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        let progress = voyage.progress
        Button { showsSteps = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label {
                        Text("YOUR FIRST VOYAGE")
                    } icon: {
                        Image(systemName: "star.fill").foregroundStyle(Palette.acc)
                    }
                    .labelStyle(VoyageEyebrowLabelStyle())
                    .foregroundStyle(Palette.aiText)
                    Spacer(minLength: 8)
                    Text("\(progress.doneCount) OF \(VoyageProgress.stepCount)").foregroundStyle(Palette.ink2)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                VoyageProgressBar(done: progress.done)
                Text("Write your first script: pick a way to start below.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: Self.shape)
            .cardDepth(Self.shape)
            .contentShape(Self.shape)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Shows every step"))
        .accessibilityIdentifier("voyage.strip")
        .sheet(isPresented: $showsSteps) { VoyageStepsSheet() }
    }
}
