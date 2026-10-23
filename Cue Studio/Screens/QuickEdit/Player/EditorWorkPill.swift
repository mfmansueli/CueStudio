//
//  EditorWorkPill.swift
//  Cue Studio
//

import SwiftUI

/// Over the foot of the preview while a reverse or an import runs (`EditorWork`): what it is, how far, and Cancel. It shows
/// only once the work has taken a moment, so a photo already on the iPhone never flashes it.
struct EditorWorkPill: View {
    let viewModel: QuickEditViewModel
    let work: EditorWork
    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            ProgressView(value: work.fraction ?? 0)
                .progressViewStyle(.circular)
                .tint(Palette.ink)
                .controlSize(.small)
                .accessibilityHidden(true)
            Text(work.label)
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Button(action: viewModel.cancelWork) {
                Text("Cancel")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.accText)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit.work.cancel")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .background(Palette.Editor.toast, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(work.label))
        .accessibilityIdentifier("edit.work")
        .opacity(isShown ? 1 : 0)
        .task(id: work.job) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isShown = true }
        }
    }
}
