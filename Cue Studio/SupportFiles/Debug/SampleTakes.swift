//
//  SampleTakes.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Takes from the design (Today, Yesterday, Earlier), for previews and UI tests. There are no
/// video files behind them, so thumbnails fall back to the placeholder. Never shipped.
enum SampleTakes {
    static func all(now: Date = .now) -> [Take] {
        let calendar = Calendar.current
        func at(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        // Today's takes sit a few minutes in the past, whatever the time the tests run.
        func today(minutesAgo: Double) -> Date { now.addingTimeInterval(-minutesAgo * 60) }

        let habits = SampleScripts.morningHabits
        let lamp = SampleScripts.lampReview
        let deals = SampleScripts.brandDeals
        let qa = SampleScripts.weeklyQA
        return [
            take(habits, 1, seconds: 64, at: today(minutesAgo: 40)),
            take(habits, 2, seconds: 71, at: today(minutesAgo: 34)),
            take(habits, 3, seconds: 62, at: today(minutesAgo: 27), best: true, edited: true),
            take(nil, 1, seconds: 18, at: today(minutesAgo: 60)),
            take(lamp, 1, seconds: 24, at: at(daysAgo: 1, hour: 18, minute: 40), best: true, exported: true),
            take(deals, 1, seconds: 47, at: at(daysAgo: 1, hour: 11, minute: 2), exported: true),
            take(deals, 2, seconds: 44, at: at(daysAgo: 1, hour: 11, minute: 9), best: true, edited: true, exported: true),
            take(qa, 1, seconds: 182, at: at(daysAgo: 9, hour: 16, minute: 10)),
            take(qa, 2, seconds: 176, at: at(daysAgo: 9, hour: 16, minute: 19)),
            take(qa, 3, seconds: 191, at: at(daysAgo: 9, hour: 16, minute: 31)),
            take(qa, 4, seconds: 174, at: at(daysAgo: 9, hour: 16, minute: 40), best: true, edited: true, exported: true),
            take(qa, 5, seconds: 185, at: at(daysAgo: 9, hour: 16, minute: 52)),
        ]
    }

    private static func take(
        _ script: Script?, _ number: Int, seconds: TimeInterval, at date: Date,
        best: Bool = false, edited: Bool = false, exported: Bool = false
    ) -> Take {
        let platform = script?.platform
        let aspect: AspectRatio = switch platform {
        case .youtube: .landscape
        case .linkedin: .vertical
        default: .portrait
        }
        return Take(
            scriptID: script?.id,
            scriptTitle: script?.displayTitle ?? String(localized: "Freestyle recording"),
            scriptVersion: script?.version,
            number: number,
            duration: seconds,
            recordedAt: date,
            fileName: "sample-\(script?.id.uuidString.prefix(4) ?? "free")-\(number).mov",
            isBest: best,
            resolution: platform == .youtube ? .uhd4K : .hd1080,
            frameRate: platform == .youtube ? .fps24 : .fps30,
            aspect: aspect,
            platform: platform,
            isEdited: edited,
            isExported: exported
        )
    }
}
#endif
