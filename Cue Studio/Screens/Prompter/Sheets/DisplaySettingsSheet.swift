//
//  DisplaySettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Aa": how the prompter reads, with a live preview behind the sheet. In Selfie mode the layout
/// comes first (reading line, text window, safe zone); then quick settings, and the rest under
/// Advanced. Over the Selfie camera the sheet never covers the text window.
struct DisplaySettingsSheet: View {
    let viewModel: PrompterViewModel
    /// Tallest the sheet may grow in Selfie mode, so the text window above stays in sight.
    var maxHeight: CGFloat?

    @Environment(SessionSetupService.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// The medium detent, as in the design.
    private static let compactHeight: CGFloat = 330

    private var mode: PrompterMode { viewModel.mode }

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if mode == .selfie {
                        DisplayLayoutSection(viewModel: viewModel)
                            .padding(.bottom, 6)
                    }
                    DisplaySettingsControls(settings: $session.prompter, mode: mode)
                }
                .padding(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
            }
        }
        .presentationDetents(detents)
        .presentationBackground(Palette.sheetGlass)
        .presentationCornerRadius(32)
        .presentationBackgroundInteraction(.enabled)
    }

    private var detents: Set<PresentationDetent> {
        guard let maxHeight else { return [.height(Self.compactHeight), .large] }
        return [.height(min(Self.compactHeight, maxHeight)), .height(maxHeight)]
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Display").font(.title3.bold())
            HStack(spacing: 5) {
                Circle().fill(Palette.live).frame(width: 6, height: 6)
                Text("Live preview")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.ink2)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.cuePrimary(.compact, expands: false))
                .accessibilityIdentifier("display.doneButton")
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 10, trailing: 16))
    }
}

#if DEBUG
#Preview {
    let viewModel = PrompterViewModel.preview()
    Color.black.sheet(isPresented: .constant(true)) {
        DisplaySettingsSheet(viewModel: viewModel)
    }
    .environment(viewModel.session)
    .previewEnvironment()
}
#endif
