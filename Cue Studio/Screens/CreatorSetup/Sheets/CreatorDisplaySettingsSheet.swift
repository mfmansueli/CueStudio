//
//  CreatorDisplaySettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// The recorder's Display editor, bound to saved creator defaults without starting capture,
/// audio or speech. The original Creator Setup controls remain on the page.
struct CreatorDisplaySettingsSheet: View {
    @Bindable var viewModel: CreatorSetupViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var mode: PrompterMode = .selfie

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Display").font(.title3.bold())
                Text("Your setup")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.cuePrimary(.compact, expands: false))
                    .accessibilityIdentifier("display.doneButton")
            }
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 10, trailing: 16))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ModeSwitcher(mode: mode) { mode = $0 }
                        .padding(.bottom, 6)
                    if mode == .selfie {
                        SectionHeading(text: String(localized: "Layout"))
                            .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
                        GroupedCard(background: Palette.surface2, radius: 22) {
                            DisplayLayoutControls.window(settings: $viewModel.prompter)
                        }
                    }
                    DisplaySettingsControls(settings: $viewModel.prompter, mode: mode, showsCoreControls: false)
                    if mode == .selfie {
                        SectionHeading(text: String(localized: "Social safe zone") + " · " + String(localized: "Custom"))
                            .padding(EdgeInsets(top: 6, leading: 4, bottom: 0, trailing: 4))
                        GroupedCard(background: Palette.surface2, radius: 22) {
                            DisplayLayoutControls.safeZoneMargins(settings: $viewModel.prompter)
                        }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.sheetGlass)
        .presentationCornerRadius(32)
    }
}
