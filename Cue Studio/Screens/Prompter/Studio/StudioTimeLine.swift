//
//  StudioTimeLine.swift
//  Cue Studio
//

import SwiftUI

/// "0:42 LEFT" and "1:12 · IDEAL 1:00–1:30": how long the rest of the script takes at the set speed, for training the text. It reads the
/// scroll progress on its own, so only this line redraws while the text moves.
struct StudioTimeLine: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        let total = ReadTime.seconds(for: viewModel.script?.text ?? "", speed: session.prompter.speed)
        let left = total * (1 - viewModel.engine.progress)
        HStack(spacing: 8) {
            Text("\(DurationText.clock(left)) LEFT")
                .foregroundStyle(Palette.accText)
                .accessibilityIdentifier("studio.timeLeft")
            Spacer(minLength: 6)
            Text(totalText(total))
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("studio.timeTotal")
        }
        .font(CueStudioFont.hud)
        .monospacedDigit()
        .tracking(0.6)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }

    /// "1:12" and, when the script has a platform, "1:12 · IDEAL 1:00–1:30".
    private func totalText(_ total: TimeInterval) -> String {
        guard let ideal = viewModel.preset?.idealRange else { return DurationText.clock(total) }
        let range = DurationText.clock(ideal.lowerBound) + "–" + DurationText.clock(ideal.upperBound)
        return String(localized: "\(DurationText.clock(total)) · IDEAL \(range)")
    }
}
