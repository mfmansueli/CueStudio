//
//  LastTakeButton.swift
//  Cue Studio
//

import SwiftUI

/// The newest take of this script at the start of the capture row, with how many there are on a
/// small yellow badge. Opens its review.
struct LastTakeButton: View {
    let viewModel: PrompterViewModel

    @Environment(TakeLibraryService.self) private var takes

    var body: some View {
        let count = takes.takes.filter { $0.scriptID == viewModel.scriptID }.count
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
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
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
