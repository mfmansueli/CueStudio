//
//  PanelPresetCard.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// A preset as it draws on the video: the sample drawn by the export's own renderer over a frame
/// of the take, its name under it, ringed in yellow when picked.
struct PanelPresetCard: View {
    let name: String
    let sample: UIImage?
    let frame: UIImage?
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if let frame {
                        Image(uiImage: frame).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors: [Palette.Takes.thumbnailTop, Palette.Takes.thumbnailBottom], startPoint: .top, endPoint: .bottom)
                    }
                    Palette.Editor.presetCardDim
                    if let sample {
                        Image(uiImage: sample)
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 14)
                    }
                }
                .frame(width: 96, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Palette.acc : Palette.Editor.presetCardBorder, lineWidth: 2)
                )
                Text(name)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
