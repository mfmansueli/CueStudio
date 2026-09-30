//
//  MotionControls.swift
//  Cue Studio
//

import SwiftUI

/// Keyframes of the picked text or photo or video: the one before, add or take away the one at the
/// playhead, the next one; on a keyframe, how the motion gets there and how big and opaque the item
/// is. Moving or resizing the item on the preview sets the keyframe at the playhead.
struct MotionControls: View {
    let viewModel: QuickEditViewModel
    let item: QuickEditViewModel.MotionItem

    var body: some View {
        let keyframes = viewModel.keyframes(of: item)
        let current = viewModel.keyframeAtPlayhead(of: item)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button { viewModel.jumpToKeyframe(forward: false) } label: {
                    Image(systemName: "chevron.backward")
                }
                .buttonStyle(.cueIcon(.surface, diameter: 32))
                .disabled(keyframes.isEmpty)
                .accessibilityLabel(Text("Previous keyframe"))
                Button(action: viewModel.toggleKeyframe) {
                    Image(systemName: current == nil ? "diamond" : "diamond.fill")
                }
                .buttonStyle(.cueIcon(current == nil ? .surface : .accent, diameter: 32))
                .accessibilityLabel(Text(current == nil ? "Add keyframe" : "Remove keyframe"))
                .accessibilityIdentifier("edit.keyframeButton")
                Button { viewModel.jumpToKeyframe(forward: true) } label: {
                    Image(systemName: "chevron.forward")
                }
                .buttonStyle(.cueIcon(.surface, diameter: 32))
                .disabled(keyframes.isEmpty)
                .accessibilityLabel(Text("Next keyframe"))
                if let current {
                    Picker("Easing", selection: Binding(get: { current.easing }, set: { viewModel.setKeyframeEasing($0) })) {
                        ForEach(KeyframeEasing.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("edit.keyframeEasing")
                } else {
                    Text(keyframes.isEmpty
                        ? String(localized: "Add a keyframe to move it over time")
                        : String(localized: "\(keyframes.count) keyframes · move it here to add one"))
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(2)
                }
            }
            if let current {
                HStack(spacing: 12) {
                    slider(String(localized: "Scale"), value: current.scale, range: 0.2...3) { viewModel.setKeyframeScale($0) }
                    slider(String(localized: "Opacity"), value: current.opacity, range: 0...1) { viewModel.setKeyframeOpacity($0) }
                }
            }
        }
    }

    /// A small slider; the whole drag is one undo step.
    private func slider(_ title: String, value: Double, range: ClosedRange<Double>, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(title) \(value.formatted(.percent.precision(.fractionLength(0)).locale(.interface)))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Palette.ink2)
            Slider(value: Binding(get: { value }, set: set), in: range) { editing in
                if editing { viewModel.beginChange() } else { viewModel.endChange() }
            }
            .tint(Palette.acc)
            .accessibilityLabel(Text(title))
        }
    }
}
