//
//  CreatorMicrophoneSheet.swift
//  Cue Studio
//

import SwiftUI

/// Creator Setup › Microphone: the usual input for every take. Lists what's connected now; a saved
/// mic that isn't stays listed, since it's still the choice. Cue can't pair Bluetooth devices, so
/// the sheet says where to do it.
struct CreatorMicrophoneSheet: View {
    let viewModel: CreatorSetupViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: String(localized: "Microphone"),
                subtitle: String(localized: "What Cue listens with in every take."),
                onClose: { dismiss() }
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 16)

            GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius, dividerInset: 48) {
                row(
                    title: String(localized: "Automatic"),
                    detail: String(localized: "The connected mic, or the iPhone's"),
                    isSelected: viewModel.setup.microphone == .automatic
                ) {
                    select(nil)
                }
                if viewModel.isPreferredMicrophoneMissing, let name = viewModel.setup.microphone.name {
                    row(title: name, detail: String(localized: "Not connected right now"), isSelected: true) {}
                }
                ForEach(viewModel.inputs) { input in
                    row(title: input.name, detail: input.detail, isSelected: viewModel.setup.microphone.id == input.id) {
                        select(input)
                    }
                }
            }
            .accessibilityIdentifier("creatorSetup.microphoneList")

            Text("Pair a Bluetooth mic in Settings › Bluetooth.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 4))
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
        .onAppear { viewModel.refreshInputs() }
    }

    private func row(title: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Palette.accText : Palette.ink3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("creatorSetup.microphoneOption")
    }

    private func select(_ input: MicrophoneOption?) {
        viewModel.selectMicrophone(input)
        dismiss()
    }
}
