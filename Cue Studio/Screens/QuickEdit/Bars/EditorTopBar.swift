//
//  EditorTopBar.swift
//  Cue Studio
//

import SwiftUI

/// Done (save the edit on the take and go back) · "Take 3" over "00:21.6 · Saved" · Export
/// (make the file). Three actions, three places: a panel's ✓ only applies and closes the panel.
struct EditorTopBar: View {
    let viewModel: QuickEditViewModel
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Palette.editorBarButton, in: Capsule())
                    .overlay(Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(minHeight: Metrics.hitTarget)
            .accessibilityHint(Text("Saves your edits to this take"))
            .accessibilityIdentifier("edit.doneButton")
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text(viewModel.take.label)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(viewModel.topBarStatus)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .accessibilityIdentifier("edit.durationChange")
            }
            Spacer(minLength: 0)
            Button { viewModel.openExport() } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .labelStyle(.titleAndIcon)
                    .padding(.leading, 12)
                    .padding(.trailing, 15)
                    .frame(height: 36)
                    .foregroundStyle(Palette.accInk)
                    .background(Palette.acc, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(minHeight: Metrics.hitTarget)
            .disabled(!viewModel.isReady)
            .accessibilityIdentifier("edit.exportButton")
        }
        .padding(.horizontal, 14)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
