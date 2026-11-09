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

    /// What the sheet lists, in reading order.
    private static let fields: [SetupField] = [.camera, .microphone, .format, .quality, .frameRate, .textSize, .speed, .mirror, .safeZones]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(
                title: String(localized: "This take"),
                subtitle: String(localized: "What Cue records with, and why.")
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

            Text("Changes here apply to this video only.")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
    }

    // MARK: - Recommendation

    /// The recommendation with the same lines and the same two choices as the card over the camera: what "Use Recommended" would change
    /// against what records now. Nothing left to change once it matches.
    private func recommendationCard(_ recommendation: SetupRecommendation) -> some View {
        let changes = viewModel.recommendationChanges
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Palette.accText)
                Text(recommendation.title).cueFont(.subheadline, weight: .semibold)
            }
            Text(recommendation.summary)
                .cueFont(.footnote).monospacedDigit()
                .foregroundStyle(Palette.ink2)
            if changes.isEmpty {
                Text("Your setup already matches it.")
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
            } else {
                SetupChangeList(changes: changes, titleColor: Palette.ink2)
                // Side by side while both names fit whole, one over the other otherwise (owner, 02/11/2026: "Manter minh…").
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { choiceChips }
                    VStack(alignment: .leading, spacing: 0) { choiceChips }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.accWashFaint, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous).strokeBorder(Palette.accBorder, lineWidth: 0.5))
    }

    /// In the card's order: Keep as is, then Use Recommended.
    @ViewBuilder private var choiceChips: some View {
        choiceChip(String(localized: "Keep as is"), isSelected: session.choice == .keepAsIs, identifier: "setup.keepAsIs") {
            viewModel.keepAsIs()
        }
        choiceChip(String(localized: "Use Recommended"), isSelected: session.choice == .useRecommended, identifier: "setup.useRecommended") {
            viewModel.useRecommendedSetup()
        }
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

    /// The field, its value and where the value comes from; when the three don't fit on one line ("Fotogramas por segundo · 30 fps ·
    /// Configuración de Instagram"), the value and its source go under the field, whole (owner, 02/11/2026: no label is ever cut).
    private func row(_ field: SetupField) -> some View {
        let source = session.source(of: field)
        let value = HStack(spacing: 10) {
            Text(session.current.label(for: field))
                .foregroundStyle(Palette.ink2)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            TagPill(text: source.label, dotColor: dotColor(for: source))
                .fixedSize()
        }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Text(field.label)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 8)
                value
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(field.label)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                value
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cueFont(.subheadline)
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
                        .cueFont(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .cueFont(.footnote, weight: .semibold)
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
