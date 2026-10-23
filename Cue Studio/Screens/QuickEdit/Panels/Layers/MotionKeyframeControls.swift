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
    /// The language's direction, for the words between the arrows (which stay left to right).
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let here = viewModel.hasKeyframeAtPlayhead
        MotionPresetPicker(viewModel: viewModel)
        trackRow
        PanelRowLabel(label: String(localized: "Keyframes"), detail: String(localized: "To move it your own way"))
            .padding(.top, 4)
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                arrow("chevron.left", label: Text("Previous keyframe"), enabled: viewModel.hasKeyframe(forward: false), identifier: "edit.keyframe.previous") {
                    viewModel.jumpToKeyframe(forward: false)
                }
                Button(action: viewModel.toggleKeyframe) {
                    HStack(spacing: 8) {
                        Image(systemName: "diamond.fill").font(.editorGlyph(EditorGlyph.chip))
                        Text(here ? "Remove keyframe" : "Add keyframe").font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(here ? Palette.accInk : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(here ? Palette.acc : Palette.fill, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .environment(\.layoutDirection, direction)
                .accessibilityIdentifier("edit.keyframe.toggle")
                arrow("chevron.right", label: Text("Next keyframe"), enabled: viewModel.hasKeyframe(forward: true), identifier: "edit.keyframe.next") {
                    viewModel.jumpToKeyframe(forward: true)
                }
            }
            // Keyframes go by time: the earlier one on the left in every language, like the timeline.
            .environment(\.layoutDirection, .leftToRight)
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
            ? String(localized: "Add a keyframe, move the playhead, then drag the text in the video. Cue moves it between keyframes.")
            : String(localized: "Add a keyframe, move the playhead, then drag the photo or video. Cue moves it between keyframes."))
    }

    /// Track: follows what's under the item at the playhead; while it runs, how far it is and Cancel.
    @ViewBuilder
    private var trackRow: some View {
        PanelRowLabel(label: String(localized: "Track"), detail: String(localized: "Follows what’s under it in the video"))
            .padding(.top, 4)
        if let label = viewModel.trackingLabel {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("edit.track.progress")
                    ProgressView(value: viewModel.trackingProgress ?? 0).tint(Palette.acc)
                }
                Button(String(localized: "Cancel"), action: viewModel.cancelTracking)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .accessibilityIdentifier("edit.track.cancel")
            }
        } else {
            PanelButton(
                label: String(localized: "Track what’s under it"), systemImage: "scope", identifier: "edit.track",
                action: viewModel.trackSelectedItem
            )
            PanelNote(text: String(localized: "Put it on what it should follow at the playhead, then tap Track. Cue makes keyframes you can adjust."))
        }
    }

    private func arrow(_ symbol: String, label: Text, enabled: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.editorGlyph(EditorGlyph.button, weight: .bold))
                .frame(width: 40, height: 40)
                .background(Palette.fill, in: Circle())
                .opacity(enabled ? 1 : Metrics.disabledOpacity)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
