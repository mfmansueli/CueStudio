//
//  SmartPanel.swift
//  Cue Studio
//

import SwiftUI

/// ✦ Smart: what Cue can do for the take with one tap, as violet tiles: Auto captions,
/// Remove pauses, Studio Voice, Auto adjust and the take's Background. Each opens the panel that does it (Auto adjust
/// opens Adjust and measures the picture), so nothing happens that the creator can't see and undo.
/// Violet is the AI's color; everything here runs on the iPhone.
struct SmartPanel: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        EditorPanelContainer(
            title: viewModel.panelTitle(.smart),
            subtitle: viewModel.panelSubtitle(.smart),
            onApply: { viewModel.closePanel() },
            content: { tiles }
        )
    }

    private var tiles: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                tile(id: "captions", title: "Auto captions", systemImage: "captions.bubble", status: viewModel.smartCaptionsStatus) {
                    viewModel.openCaptions()
                }
                tile(id: "pauses", title: "Remove pauses", systemImage: "waveform", status: nil) {
                    viewModel.panel = .pauses
                }
                tile(id: "voice", title: "Studio Voice", systemImage: "waveform.and.mic", status: viewModel.smartVoiceStatus) {
                    viewModel.panel = .voice
                }
                tile(id: "autoAdjust", title: "Auto adjust", systemImage: "wand.and.stars", status: viewModel.smartAdjustStatus) {
                    viewModel.panel = .adjust
                    viewModel.autoAdjust()
                }
                tile(id: "background", title: "Background", systemImage: "person.and.background.dotted", status: nil) {
                    // The whole take's background; a picked clip's own is in its tools.
                    viewModel.lookScopeIsClip = false
                    viewModel.panel = .background
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    /// A 100 × 100 tile: the icon at the top, the name and, in mono capitals, what is on.
    private func tile(
        id: String, title: LocalizedStringKey, systemImage: String, status: String?, action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let isOn = status != nil
        return Button {
            Haptics.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Palette.aiText)
                Spacer(minLength: 4)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.aiTextStrong)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                Text(status ?? " ")
                    .textCase(.uppercase)
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Palette.aiText)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            .padding(10)
            .frame(width: 100, height: 100, alignment: .topLeading)
            .background(Palette.aiFill, in: shape)
            .overlay(shape.strokeBorder(isOn ? Palette.acc : Palette.aiBorder, lineWidth: isOn ? 1.5 : 0.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.smart.\(id)")
    }
}
