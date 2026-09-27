//
//  AudioToolView.swift
//  Cue Studio
//

import SwiftUI

/// Audio: volume up to 150%, Enhance voice and Reduce background noise.
struct AudioToolView: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(spacing: 10) {
            ValueSlider(
                title: String(localized: "Volume"),
                valueText: viewModel.edit.volume.formatted(.percent.precision(.fractionLength(0))),
                value: $viewModel.edit.volume,
                range: TakeEdit.volumeRange, step: 0.05,
                identifier: "edit.volume"
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            GroupedCard(radius: Metrics.innerRadius) {
                toggle(String(localized: "Enhance voice"), detail: String(localized: "Clearer, fuller speech"), isOn: $viewModel.edit.enhancesVoice)
                toggle(String(localized: "Reduce background noise"), detail: nil, isOn: $viewModel.edit.reducesNoise)
            }
        }
    }

    private func toggle(_ title: String, detail: String?, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
        }
        .tint(Palette.success)
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
    }
}
