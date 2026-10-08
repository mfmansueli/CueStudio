//
//  DisplaySettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Aa" in Studio: how the prompter reads, with a live preview behind the sheet. Selfie opens the Prompter page of Settings
/// instead (`PrompterSettingsSheet`).
struct DisplaySettingsSheet: View {
    let viewModel: PrompterViewModel
    /// Tallest the sheet may grow, so the text above stays in sight (nil: as tall as its content, whatever that is).
    var maxHeight: CGFloat?

    @Environment(SessionSetupService.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// The controls' own height, measured; until then, a guess.
    @State private var contentHeight: CGFloat = 330

    private var mode: PrompterMode { viewModel.mode }

    var body: some View {
        @Bindable var session = session
        // A navigation bar of its own: the title and, under it, that the preview behind is live; Done at its end, as the system's toolbar item.
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DisplaySettingsControls(settings: $session.prompter, mode: mode)
                }
                .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Display")
            .navigationSubtitle("Live preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            // The sheet's own glass, not the navigation stack's.
            .containerBackground(Palette.sheetGlass, for: .navigation)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("display.doneButton")
                }
            }
        }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.sheetGlass)
        .presentationCornerRadius(32)
        .presentationBackgroundInteraction(.enabled)
    }

    /// As tall as the controls and the bar over them, and no taller (the system's grabber has nothing to stretch it to), unless that is more than
    /// the text above can spare: then the controls scroll.
    private var height: CGFloat {
        let fitted = contentHeight + Metrics.sheetBarHeight
        return maxHeight.map { min(fitted, $0) } ?? fitted
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
