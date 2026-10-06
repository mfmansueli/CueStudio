//
//  SpeedSlider.swift
//  Cue Studio
//

import SwiftUI

/// "SPEED  150 wpm": the speed of the prompter's bars, the system's slider, 80–220 words a minute in steps of 5; the value is always
/// written. The stored speed is a multiplier (1.0× is `ReadTime.wordsPerMinuteAtOneX`), so the slider converts.
struct SpeedSlider: View {
    let speed: Double
    let onChange: @MainActor @Sendable (Double) -> Void

    private var spec: CueSliderSpec { .speed }

    var body: some View {
        let wordsPerMinute = Int(PrompterSettings.wordsPerMinute(forSpeed: speed).rounded())
        LabeledSlider(
            label: String(localized: "Speed"),
            valueText: String(localized: "\(wordsPerMinute) wpm"),
            spokenValue: String(localized: "\(wordsPerMinute) words a minute"),
            value: Binding(
                get: { PrompterSettings.wordsPerMinute(forSpeed: speed).rounded() },
                set: { onChange(PrompterSettings.speed(forWordsPerMinute: $0)) }
            ),
            range: spec.range,
            step: spec.step,
            accessibilityIdentifier: "prompter.speedSlider"
        )
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview {
    SpeedSlider(speed: ReadTime.naturalSpeed, onChange: { _ in })
        .padding()
        .background(Color.black)
}
#endif
