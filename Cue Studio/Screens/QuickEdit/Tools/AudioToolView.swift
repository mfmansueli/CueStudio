//
//  AudioToolView.swift
//  Cue Studio
//

import SwiftUI

/// Voice: the take's own sound. Volume up to 150%; Enhance Voice and Reduce Noise, each Off, Soft
/// or Strong; and "Compare with original", which plays the untreated sound as loud as the treated
/// one. An edit from before the levels says it keeps its first treatment until one is changed.
struct AudioToolView: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(spacing: 10) {
            ValueSlider(
                title: String(localized: "Volume"),
                valueText: viewModel.edit.volume.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
                value: $viewModel.edit.volume,
                range: TakeEdit.volumeRange, step: 0.05,
                identifier: "edit.volume"
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            GroupedCard(radius: Metrics.innerRadius) {
                strength(
                    String(localized: "Enhance voice"), detail: String(localized: "Clearer, fuller speech"),
                    value: currentEnhancement, identifier: "edit.enhanceVoice"
                ) { viewModel.setVoiceEnhancement($0) }
                strength(
                    String(localized: "Reduce noise"), detail: String(localized: "Less rumble, hiss and room between words"),
                    value: currentNoise, identifier: "edit.reduceNoise"
                ) { viewModel.setNoiseReduction($0) }
            }
            compareButton
            if viewModel.edit.audioVersion < 2 {
                Text("This edit keeps its first sound treatment until you change a setting.")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// An edit from before the levels shows its switches as Soft.
    private var currentEnhancement: AudioStrength {
        viewModel.edit.audioVersion < 2 ? (viewModel.edit.enhancesVoice ? .soft : .off) : viewModel.edit.voiceEnhancement
    }

    private var currentNoise: AudioStrength {
        viewModel.edit.audioVersion < 2 ? (viewModel.edit.reducesNoise ? .soft : .off) : viewModel.edit.noiseReduction
    }

    private var compareButton: some View {
        Toggle(isOn: Binding(
            get: { viewModel.comparesOriginal },
            set: { viewModel.setComparesOriginal($0) }
        )) {
            HStack(spacing: 8) {
                if viewModel.comparesOriginal, viewModel.originalVolume == nil {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "ear")
                }
                Text(viewModel.comparesOriginal ? "Playing the original" : "Compare with original")
            }
        }
        .toggleStyle(.button)
        .buttonStyle(.cueSecondary(.medium))
        .disabled(!viewModel.canCompareOriginal && !viewModel.comparesOriginal)
        .accessibilityHint(Text("Plays your take without the treatment, just as loud"))
        .accessibilityIdentifier("edit.compareOriginal")
    }

    private func strength(
        _ title: String, detail: String, value: AudioStrength, identifier: String, set: @escaping @MainActor @Sendable (AudioStrength) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
            }
            Picker(title, selection: Binding(get: { value }, set: set)) {
                ForEach(AudioStrength.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
