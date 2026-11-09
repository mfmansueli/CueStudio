//
//  LastTakeButton.swift
//  Cue Studio
//

import SwiftUI

/// The newest take of the video being recorded (this script, this network) at the start of the capture row, with how many there are on a
/// small yellow badge. Opens its review.
struct LastTakeButton: View {
    let viewModel: PrompterViewModel

    var body: some View {
        let count = viewModel.lastTakeCount
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button { viewModel.openLastTake() } label: {
            Group {
                if let take = viewModel.lastTake {
                    TakeThumbnail(take: take)
                } else {
                    Palette.overlayFill
                }
            }
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
            .overlay(alignment: .bottomTrailing) {
                if count > 0 {
                    Text(count.formatted())
                        .monoFont(size: 10, weight: .heavy)
                        .foregroundStyle(Palette.accInk)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Palette.acc, in: Capsule())
                        .padding(2)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.lastTake == nil || viewModel.isRecording)
        .accessibilityLabel(Text("Last take"))
        .accessibilityValue(count > 0 ? Text("\(count) takes") : Text(""))
        .accessibilityIdentifier("prompter.lastTakeButton")
    }
}
