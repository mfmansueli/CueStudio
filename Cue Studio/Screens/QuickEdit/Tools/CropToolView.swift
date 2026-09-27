//
//  CropToolView.swift
//  Cue Studio
//

import SwiftUI

/// Crop: 9:16, 4:5, 1:1 or 16:9; drag the video to reposition, Reset to center it.
struct CropToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(AspectRatio.allCases) { aspect in
                    let isOn = viewModel.edit.aspect == aspect
                    Button { viewModel.setAspect(aspect) } label: {
                        SelectableCard(isSelected: isOn) {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .frame(width: 26 * min(1, aspect.widthOverHeight), height: 26 * min(1, 1 / aspect.widthOverHeight))
                                Text(aspect.label).font(.footnote.weight(.semibold))
                            }
                            .frame(height: 74)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("edit.crop.\(aspect.label)")
                }
            }
            HStack {
                Text("Drag the video to reposition")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink.opacity(0.8))
                Spacer()
                Button("Reset", action: viewModel.resetCropPosition)
                    .buttonStyle(.cueSecondary(.compact, expands: false))
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(minHeight: 52)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        }
    }
}
