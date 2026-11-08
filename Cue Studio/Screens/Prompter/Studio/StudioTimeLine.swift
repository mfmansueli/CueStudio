//
//  StudioTimeLine.swift
//  Cue Studio
//

import SwiftUI

/// "0:42 LEFT" and "1:12 · IDEAL 1:00 to 1:30": how long the rest of the script takes at the set speed, for training the text. Only "LEFT"
/// reads the scroll progress (`StudioTimeLeft`), so while the text moves the script's words aren't counted again each frame.
struct StudioTimeLine: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        let total = ReadTime.seconds(for: viewModel.script?.text ?? "", speed: session.prompter.speed)
        HStack(spacing: 8) {
            StudioTimeLeft(viewModel: viewModel, total: total)
            Spacer(minLength: 6)
            Text(totalText(total))
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("studio.timeTotal")
        }
        .hudFont()
        .monospacedDigit()
        .tracking(0.6)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }

    /// "1:12" and, when the script has a platform, "1:12 · IDEAL 1:00 to 1:30".
    private func totalText(_ total: TimeInterval) -> String {
        guard let ideal = viewModel.preset?.idealRange else { return DurationText.clock(total) }
        let range = DurationText.range(ideal)
        return String(localized: "\(DurationText.clock(total)) · IDEAL \(range)")
    }
}
