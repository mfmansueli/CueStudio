//
//  EditorTopBar.swift
//  Cue Studio
//

import SwiftUI

/// Back (keeps the draft, asks nothing) · "● IN EDIT · AUTOSAVED" · Done (yellow, the screen's one
/// primary action: it asks "Is it ready to post?"). A panel's ✓ only applies and closes the panel.
struct EditorTopBar: View {
    let viewModel: QuickEditViewModel
    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
                    .background(Palette.editorBarButton, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.glassBorder, lineWidth: 0.5))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
            .accessibilityLabel(Text("Back"))
            .accessibilityHint(Text("Keeps your edit as a draft"))
            .accessibilityIdentifier("edit.backButton")
            Spacer(minLength: 0)
            statusChip
            Spacer(minLength: 0)
            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .foregroundStyle(Palette.accInk)
                    .background(Palette.acc, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(minHeight: Metrics.hitTarget)
            .disabled(!viewModel.isReady)
            .accessibilityHint(Text("Asks if the video is ready to post"))
            .accessibilityIdentifier("edit.doneButton")
        }
        .padding(.horizontal, 14)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// "● IN EDIT · AUTOSAVED" once something changed (the draft keeps it), "● NO CHANGES YET" before.
    private var statusChip: some View {
        let changed = viewModel.hasUnsavedChanges
        return HStack(spacing: 6) {
            Circle().fill(changed ? Color.white : Palette.ink2).frame(width: 5, height: 5)
            Text(changed ? "In edit · Autosaved" : "No changes yet")
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
        .tracking(0.6)
        .foregroundStyle(changed ? Palette.ink : Palette.ink2)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Palette.editorBarButton, in: Capsule())
        .overlay(Capsule().strokeBorder(changed ? Color.white.opacity(0.3) : Palette.glassBorder, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(changed ? "In edit · Autosaved" : "No changes yet"))
        .accessibilityIdentifier("edit.statusChip")
    }
}
