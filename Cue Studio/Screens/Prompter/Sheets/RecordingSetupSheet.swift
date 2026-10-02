//
//  RecordingSetupSheet.swift
//  Cue Studio
//

import SwiftUI

/// "This take", from the setup pill: what the recording uses and why — the creator's setup, the
/// platform's recommendation or a change for this take — with the recommendation's choice, a way
/// back to the usual setup and the remote.
struct RecordingSetupSheet: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// What the sheet lists, in reading order.
    private static let fields: [SetupField] = [.camera, .microphone, .format, .quality, .frameRate, .textSize, .speed, .mirror, .safeZones]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(
                title: String(localized: "This take"),
                subtitle: String(localized: "What Cue records with, and why."),
                onClose: { dismiss() }
            )
            .padding(.horizontal, 4)

            if let recommendation = session.recommendation {
                recommendationCard(recommendation)
            }

            GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius) {
                ForEach(Self.fields) { field in
                    row(field)
                }
            }
            .accessibilityIdentifier("setup.list")

            if session.hasChanges || session.choice == .useRecommended {
                Button("Back to my setup") {
                    viewModel.backToCreatorSetup()
                }
                .buttonStyle(.cueSecondary())
                .accessibilityIdentifier("setup.backToMySetupButton")
            }

            remoteRow

            Text("Changes here are for this video. Your usual setup stays in Settings › Creator Setup.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
    }

    // MARK: - Recommendation

    private func recommendationCard(_ recommendation: SetupRecommendation) -> some View {
        let conflicts = session.conflicts
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Palette.accText)
                Text(recommendation.title).font(.subheadline.weight(.semibold))
            }
            Text(recommendation.summary)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
            if conflicts.isEmpty {
                Text("Your setup already matches it.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            } else {
                Text("Your usual setup is \(session.usualSummary).")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                HStack(spacing: 8) {
                    choiceChip(String(localized: "Use Recommended"), isSelected: session.choice == .useRecommended, identifier: "setup.useRecommended") {
                        viewModel.useRecommendedSetup()
                    }
                    choiceChip(String(localized: "Keep My Setup"), isSelected: session.choice == .keepCreatorSetup, identifier: "setup.keepMySetup") {
                        viewModel.keepCreatorSetup()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.accWashFaint, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous).strokeBorder(Palette.accBorder, lineWidth: 0.5))
    }

    private func choiceChip(_ title: String, isSelected: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            FilterChip(label: title, isSelected: isSelected, systemImage: isSelected ? "checkmark" : nil)
        }
        .buttonStyle(.plain)
        .frame(minHeight: Metrics.hitTarget)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Rows

    private func row(_ field: SetupField) -> some View {
        let source = session.source(of: field)
        return HStack(spacing: 10) {
            Text(field.label)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(session.current.label(for: field))
                .foregroundStyle(Palette.ink2)
                .monospacedDigit()
                .lineLimit(1)
            TagPill(text: source.label, dotColor: dotColor(for: source))
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("setup.row.\(field.rawValue)")
    }

    /// Yellow for a recommendation, blue for a change for this take; the creator's own values need
    /// no mark.
    private func dotColor(for source: SetupSource) -> Color? {
        switch source {
        case .creatorSetup: nil
        case .recommended: Palette.acc
        case .thisTake: Palette.info
        }
    }

    private var remoteRow: some View {
        Button {
            viewModel.openRemoteControl()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundStyle(viewModel.isRemoteConnected ? Palette.accText : Palette.ink2)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Remote Control").foregroundStyle(Palette.ink)
                    Text(viewModel.remote.state.label)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("setup.remoteButton")
    }
}

#if DEBUG
#Preview {
    let viewModel = PrompterViewModel.preview()
    Color.black.sheet(isPresented: .constant(true)) {
        RecordingSetupSheet(viewModel: viewModel)
    }
    .environment(viewModel.session)
    .previewEnvironment()
}
#endif
