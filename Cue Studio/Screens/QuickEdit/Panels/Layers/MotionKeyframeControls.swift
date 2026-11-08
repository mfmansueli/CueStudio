//
//  MotionKeyframeControls.swift
//  Cue Studio
//

import SwiftUI

/// Motion for the picked text (Text style › Motion), graphic or photo or video, in the order a creator reaches for it (owner,
/// canvas 2 F15, 07/11/2026): the ready-made ways in with their duration (Pop first), Track, then ◀ Add (or Remove) keyframe ▶
/// with how many there are and how keyframes work; when it starts and ends is under Advanced. The bar's shortcuts still open it.
struct MotionKeyframeControls: View {
    let viewModel: QuickEditViewModel
    /// The language's direction, for the words between the arrows (which stay left to right).
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let here = viewModel.overlays.hasKeyframeAtPlayhead
        MotionPresetPicker(viewModel: viewModel)
        trackRow
        PanelRowLabel(label: String(localized: "Keyframes"), detail: String(localized: "To move it your own way"))
            .padding(.top, 4)
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                arrow("chevron.left", label: Text("Previous keyframe"), enabled: viewModel.overlays.hasKeyframe(forward: false), identifier: "edit.keyframe.previous") {
                    viewModel.overlays.jumpToKeyframe(forward: false)
                }
                Button(action: viewModel.overlays.toggleKeyframe) {
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
                arrow("chevron.right", label: Text("Next keyframe"), enabled: viewModel.overlays.hasKeyframe(forward: true), identifier: "edit.keyframe.next") {
                    viewModel.overlays.jumpToKeyframe(forward: true)
                }
            }
            // Keyframes go by time: the earlier one on the left in every language, like the timeline.
            .environment(\.layoutDirection, .leftToRight)
            Text(viewModel.overlays.keyframeCountLabel)
                .font(.system(.caption))
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("edit.keyframe.count")
        }
        PanelNote(text: viewModel.selectedMediaID == nil
            ? String(localized: "Add a keyframe, move the playhead, then drag the text in the video. Cue moves it between keyframes.")
            : String(localized: "Add a keyframe, move the playhead, then drag the photo or video. Cue moves it between keyframes."), teaches: true)
        if let item = viewModel.overlays.motionItem, let span = viewModel.overlays.editedSpan(of: item) {
            PanelAdvancedButton(isOpen: viewModel.showsAdvanced) { viewModel.showsAdvanced.toggle() }
            if viewModel.showsAdvanced {
                VStack(alignment: .leading, spacing: 12) {
                    PanelStepper(
                        label: String(localized: "Starts"), value: DurationText.editor(span.start), identifier: "edit.text.starts",
                        onEditingChanged: { $0 ? viewModel.beginPanelChange() : viewModel.endPanelChange() },
                        onDecrease: { viewModel.nudgeLayerEdge(.start, by: -0.1) }, onIncrease: { viewModel.nudgeLayerEdge(.start, by: 0.1) }
                    )
                    PanelStepper(
                        label: String(localized: "Ends"), value: DurationText.editor(span.end), identifier: "edit.text.ends",
                        onEditingChanged: { $0 ? viewModel.beginPanelChange() : viewModel.endPanelChange() },
                        onDecrease: { viewModel.nudgeLayerEdge(.end, by: -0.1) }, onIncrease: { viewModel.nudgeLayerEdge(.end, by: 0.1) }
                    )
                }
            }
        }
    }

    /// Track: follows what's under the item at the playhead; while it runs, how far it is and Cancel.
    @ViewBuilder
    private var trackRow: some View {
        PanelRowLabel(label: String(localized: "Track"), detail: String(localized: "Follows what’s under it in the video"))
            .padding(.top, 4)
        if let label = viewModel.overlays.trackingLabel {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("edit.track.progress")
                    ProgressView(value: viewModel.overlays.trackingProgress ?? 0).tint(Palette.acc)
                }
                // "Stop", not "Cancel": what was tracked stays (owner, canvas 2 R6), as in Blur area.
                Button(String(localized: "Stop"), action: viewModel.overlays.stopTracking)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .accessibilityHint(Text("Keeps what was tracked"))
                    .accessibilityIdentifier("edit.track.stop")
            }
        } else {
            PanelButton(
                label: String(localized: "Track what’s under it"), systemImage: "scope", identifier: "edit.track",
                action: viewModel.overlays.trackSelectedItem
            )
            PanelNote(text: String(localized: "Put it on what it should follow at the playhead, then tap Track. Cue makes keyframes you can adjust."), teaches: true)
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
