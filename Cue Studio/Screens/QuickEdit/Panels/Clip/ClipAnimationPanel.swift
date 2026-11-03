//
//  ClipAnimationPanel.swift
//  Cue Studio
//

import SwiftUI

/// Animation (this clip): In or Out, then None or a style (Fade, Slide up or down, Slide in or out, Zoom in or out, Blur) and how
/// long it takes. Picking one plays that end of the clip; "Preview" in the header plays it again.
struct ClipAnimationPanel: View {
    @Bindable var viewModel: QuickEditViewModel
    @State private var isIn = true

    private var clips: ClipsViewModel { viewModel.clips }

    var body: some View {
        let current = clips.clipAnimation(isIn: isIn)
        let play = current == nil ? nil : PanelPlay { clips.previewClipAnimation(isIn: isIn) }
        PanelFrame(viewModel: viewModel, panel: .clipAnimation, play: play) {
            PanelSegmented(
                options: [
                    PanelOption(true, String(localized: "In", comment: "Clip animation: how the clip comes in at its start"), key: "in"),
                    PanelOption(false, String(localized: "Out", comment: "Clip animation: how the clip goes out at its end"), key: "out"),
                ],
                selection: isIn, identifier: "edit.clipAnimation.side"
            ) { isIn = $0 }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    tile(String(localized: "None"), systemImage: "nosign", key: "none", isOn: current == nil) {
                        clips.setClipAnimation(nil, isIn: isIn)
                    }
                    ForEach(ClipAnimationStyle.allCases) { style in
                        tile(style.label(isIn: isIn), systemImage: style.systemImage(isIn: isIn), key: style.rawValue, isOn: current?.style == style) {
                            clips.setClipAnimation(style, isIn: isIn)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            if let current {
                PanelSlider(
                    label: String(localized: "Duration"), value: current.duration, range: ClipAnimation.durationRange, step: 0.1,
                    defaultValue: ClipAnimation.defaultDuration, format: .seconds, identifier: "edit.clipAnimation.duration",
                    onChange: { clips.setClipAnimationDuration($0, isIn: isIn) },
                    onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
                )
            }
        }
    }

    private func tile(_ label: String, systemImage: String, key: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.editorGlyph(EditorGlyph.tool, weight: .semibold))
                // Two lines broken between words, never inside one (owner, 02/11/2026: no label is ever cut).
                WholeWordsLabel(text: label, minimumScale: 0.8).font(.system(.caption, weight: .semibold))
            }
            .foregroundStyle(isOn ? Palette.accText : Palette.ink)
            .frame(width: 76, height: 70)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.clipAnimation.style.\(key)")
    }
}
