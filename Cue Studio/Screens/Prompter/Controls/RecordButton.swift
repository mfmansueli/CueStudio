//
//  RecordButton.swift
//  Cue Studio
//

import SwiftUI

/// White ring with a red center that turns into a stop square while recording.
struct RecordButton: View {
    let isRecording: Bool
    let isCountingDown: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(Color.white, lineWidth: 4)
                RoundedRectangle(cornerRadius: isRecording ? 8 : innerSize / 2, style: .continuous)
                    .fill(Palette.record)
                    .frame(width: innerSize, height: innerSize)
            }
            .frame(width: 78, height: 78)
            .contentShape(Circle())
            .animation(.spring(duration: 0.25), value: isRecording)
            .animation(.spring(duration: 0.25), value: isCountingDown)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isRecording ? "Stop recording" : (isCountingDown ? "Cancel countdown" : "Record")))
        .accessibilityIdentifier("prompter.recordButton")
    }

    private var innerSize: CGFloat {
        if isRecording { return 30 }
        return isCountingDown ? 54 : 62
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 30) {
        RecordButton(isRecording: false, isCountingDown: false, action: {})
        RecordButton(isRecording: true, isCountingDown: false, action: {})
    }
    .padding()
    .background(Color.black)
}
#endif
