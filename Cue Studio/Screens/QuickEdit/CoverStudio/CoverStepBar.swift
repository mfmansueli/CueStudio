//
//  CoverStepBar.swift
//  Cue Studio
//

import SwiftUI

/// Cover Studio's five steps along the bottom, numbered, the open one in yellow. Any can be opened.
struct CoverStepBar: View {
    @Bindable var viewModel: CoverStudioViewModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(CoverStudioStep.allCases.enumerated()), id: \.element) { index, step in
                let isOn = viewModel.step == step
                Button {
                    Haptics.selection()
                    viewModel.step = step
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: step.systemImage).font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                        // With the largest text sizes only the icons: five names never fit, and the panel above names the open step.
                        if !typeSize.isAccessibilitySize {
                            Text(step.label).font(.system(.caption2, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Step \(index + 1) of \(CoverStudioStep.allCases.count): \(step.label)"))
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
                .accessibilityShowsLargeContentViewer { Label(step.label, systemImage: step.systemImage) }
                .accessibilityIdentifier("cover.step.\(step.rawValue)")
            }
        }
        .padding(.horizontal, 8)
        .background(Palette.Editor.toolbarFill)
    }
}
