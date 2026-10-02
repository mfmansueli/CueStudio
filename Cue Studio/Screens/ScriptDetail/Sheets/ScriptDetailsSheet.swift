//
//  ScriptDetailsSheet.swift
//  Cue Studio
//

import SwiftUI

/// Script details: where it's for and what kind of script it is, how its length sits with the
/// destination (the meter and the blocks), the capture format, the version and the monetization
/// goals. Everything that used to sit above the text lives here, one tap away.
struct ScriptDetailsSheet: View {
    let viewModel: ScriptDetailViewModel

    @Environment(CreatorProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var profile = profile
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(
                    title: String(localized: "Script details"),
                    subtitle: viewModel.script?.displayTitle,
                    onClose: { dismiss() }
                )
                if let script = viewModel.script {
                    GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 14) {
                        ScriptOptionRow(title: String(localized: "Create for"), identifier: "details.destination") {
                            viewModel.sheet = .destination
                        } value: {
                            HStack(spacing: 6) {
                                ColorDot(color: script.platform.tint, size: 7)
                                Text(script.platform.destinationName)
                            }
                        }
                        ScriptOptionRow(title: String(localized: "Script type"), identifier: "details.type") {
                            viewModel.sheet = .scriptType
                        } value: {
                            Text(viewModel.structure.label)
                        }
                    }
                    lengthCard
                    GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 14) {
                        valueRow(String(localized: "Format"), viewModel.preset.captureSummary)
                        valueRow(String(localized: "Version"), versionLabel(script))
                        Toggle("Monetization goals", isOn: $profile.profile.monetizationGoals)
                            .font(.body)
                            .tint(Palette.successText)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                            .accessibilityIdentifier("details.monetizationToggle")
                    }
                }
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
    }

    private var lengthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LengthMeterView(zone: viewModel.zone)
            BlockChipsView(
                summaries: viewModel.summaries,
                isSerious: viewModel.structure.isSerious,
                hookRunsLong: viewModel.hookOverrun != nil,
                onTap: viewModel.showBlock
            )
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.body)
            Spacer(minLength: 8)
            Text(value)
                .font(.body)
                .foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }

    /// "v2 · 3 takes".
    private func versionLabel(_ script: Script) -> String {
        let count = viewModel.scriptTakes.count
        return count == 1
            ? String(localized: "v\(script.version) · 1 take")
            : String(localized: "v\(script.version) · \(count) takes")
    }
}
