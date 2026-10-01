//
//  MotionKeyframeControls.swift
//  Cue Studio
//

import SwiftUI

/// Motion for the picked text (Text style › Motion) or photo or video (Media › Advanced): ◀ Add
/// (or Remove) keyframe ▶ with how many there are, when it starts and ends, and how keyframes
/// work.
struct MotionKeyframeControls: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let here = viewModel.hasKeyframeAtPlayhead
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                arrow("chevron.left", label: Text("Previous keyframe"), enabled: viewModel.hasKeyframe(forward: false), identifier: "edit.keyframe.previous") {
                    viewModel.jumpToKeyframe(forward: false)
                }
                Button(action: viewModel.toggleKeyframe) {
                    HStack(spacing: 8) {
                        Image(systemName: "diamond.fill").font(.system(size: 12))
                        Text(here ? "Remove keyframe" : "Add keyframe").font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(here ? Palette.accInk : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(here ? Palette.acc : Palette.fill, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("edit.keyframe.toggle")
                arrow("chevron.right", label: Text("Next keyframe"), enabled: viewModel.hasKeyframe(forward: true), identifier: "edit.keyframe.next") {
                    viewModel.jumpToKeyframe(forward: true)
                }
            }
            Text(viewModel.keyframeCountLabel)
                .font(.system(.caption))
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("edit.keyframe.count")
        }
        if let item = viewModel.motionItem, let span = viewModel.editedSpan(of: item) {
            PanelStepper(
                label: String(localized: "Starts"), value: DurationText.editor(span.start), identifier: "edit.text.starts",
                onDecrease: { viewModel.nudgeLayerEdge(.start, by: -0.1) }, onIncrease: { viewModel.nudgeLayerEdge(.start, by: 0.1) }
            )
            PanelStepper(
                label: String(localized: "Ends"), value: DurationText.editor(span.end), identifier: "edit.text.ends",
                onDecrease: { viewModel.nudgeLayerEdge(.end, by: -0.1) }, onIncrease: { viewModel.nudgeLayerEdge(.end, by: 0.1) }
            )
        }
        PanelNote(text: viewModel.selectedMediaID == nil
            ? String(localized: "Add a keyframe, move the playhead, then drag the text in the video — Cue moves it between keyframes.")
            : String(localized: "Add a keyframe, move the playhead, then drag the photo or video — Cue moves it between keyframes."))
    }

    private func arrow(_ symbol: String, label: Text, enabled: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 40)
                .background(Palette.fill, in: Circle())
                .opacity(enabled ? 1 : 0.3)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
