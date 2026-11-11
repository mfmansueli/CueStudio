//
//  SelfieTopBar.swift
//  Cue Studio
//

import SwiftUI

/// The Selfie recorder's navigation bar, the system's: close at the start, Selfie | Studio in the middle and the network chip at the end.
/// While recording, only the REC pill (with the clock) and, beside it, the take's number and the time left to the platform's minimum, in one
/// item that fits the screen (`RecordingBarLayout`): nothing in the middle or at the end to run into (owner, 11/11/2026). The bar's middle
/// is measured (`SelfieScreenMetrics.topBarCenter`): the text window starts under its buttons.
struct SelfieTopBar: ToolbarContent {
    let viewModel: PrompterViewModel
    let onClose: () -> Void

    var body: some ToolbarContent {
        if viewModel.isRecording {
            ToolbarItem(placement: .topBarLeading) {
                RecordingBarLayout(maxWidth: max(0, viewModel.screenMetrics.screen.width - Self.barMargins)) {
                    RecordingBadge(seconds: viewModel.recordingSeconds)
                    RecordingTakeTitle(viewModel: viewModel)
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { y in
                    viewModel.measured { $0.topBarCenter = y }
                }
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close, action: onClose)
                    .accessibilityIdentifier("prompter.closeButton")
            }
            ToolbarItem(placement: .principal) {
                ModeSwitcher(mode: .selfie) { mode in
                    Task { await viewModel.switchMode(to: mode) }
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { y in
                    viewModel.measured { $0.topBarCenter = y }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                aspectButton
            }
        }
    }

    /// The bar's margins at both sides, and a little air: what the recording item may not use of the screen's width.
    private static let barMargins: CGFloat = 40

    /// The chip at the end of the bar: the network this recording is for, its colored dot and its name ("● TikTok"), the script's or,
    /// freestyle, the creator's default. It opens Create for (the Scripts dock's picker) and changes only this session's network; the
    /// frame lives in the camera pill and the Camera sheet.
    private var aspectButton: some View {
        let platform = viewModel.platform
        return Button {
            viewModel.platformChipTapped()
        } label: {
            HStack(spacing: 6) {
                PlatformDot(color: platform.tint)
                Text(platform.label).cueFont(.footnote, weight: .semibold)
            }
            .foregroundStyle(Palette.ink)
        }
        .accessibilityLabel(Text("Create for"))
        .accessibilityValue(Text(platform.label))
        .accessibilityHint(Text("Changes the platform and its preset"))
        .accessibilityIdentifier("prompter.aspectButton")
    }
}
