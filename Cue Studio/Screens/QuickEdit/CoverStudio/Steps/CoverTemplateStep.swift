//
//  CoverTemplateStep.swift
//  Cue Studio
//

import SwiftUI

/// Template: each template drawn with this cover's own picture and title, so the choice is the real result. Picking one keeps
/// what was made (the words, the highlighted words, the framing, the graphics added).
struct CoverTemplateStep: View {
    let viewModel: CoverStudioViewModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(CoverTemplate.allCases) { template in
                    tile(template)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    private func tile(_ template: CoverTemplate) -> some View {
        let isOn = viewModel.composition.template == template
        let width: CGFloat = 92
        let height = width / CGFloat(viewModel.aspect)
        return Button { viewModel.applyTemplate(template) } label: {
            VStack(spacing: 6) {
                Group {
                    if let image = viewModel.thumbnails[template] {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Palette.surface2.overlay(ProgressView().tint(Palette.ink2))
                    }
                }
                .frame(width: width, height: min(height, 164))
                .clipShape(RoundedRectangle(cornerRadius: Metrics.editorInsetRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.editorInsetRadius, style: .continuous)
                        .strokeBorder(isOn ? Palette.acc : Palette.separator, lineWidth: isOn ? 2.5 : 1)
                }
                Text(template.label)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .accessibilityLabel(Text(template.label))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier("cover.template.\(template.rawValue)")
    }
}
