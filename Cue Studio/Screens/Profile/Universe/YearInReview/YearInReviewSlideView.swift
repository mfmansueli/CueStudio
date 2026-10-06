//
//  YearInReviewSlideView.swift
//  Cue Studio
//

import SwiftUI

/// One slide of the story (9.2): a mono label in yellow, the picture, a headline and a quiet line. The five: the total, the main planet, the best
/// month, the longest streak and the strongest theme.
struct YearInReviewSlideView: View {
    let slide: YearStats.Slide
    let stats: YearStats
    let isSealed: Bool

    var body: some View {
        VStack(spacing: 14) {
            Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Palette.acc)
            picture
            // The total reads as a number with a small caption; the others name the thing in large type.
            Text(headline)
                .font(.system(size: slide == .total ? 21 : 30, weight: slide == .total ? .semibold : .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(line)
                .font(.system(size: slide == .total ? 13 : 14))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("yearInReview.slide")
    }

    private var label: String {
        switch slide {
        case .total: String(localized: "YOUR \(String(stats.year))")
        case .planet: String(localized: "MAIN PLANET")
        case .month: String(localized: "BEST MONTH")
        case .streak: String(localized: "LONGEST STREAK")
        case .theme: String(localized: "STRONGEST THEME")
        }
    }

    @ViewBuilder
    private var picture: some View {
        switch slide {
        case .total:
            Text("\(stats.total)").font(.system(size: 64, weight: .heavy)).foregroundStyle(.white).monospacedDigit()
        case .planet:
            if let main = stats.mainPlatform {
                Canvas { canvas, size in
                    var layer = canvas
                    let diameter = PlanetSize.diameter(videos: main.count) * 2.4
                    PlanetPainter.draw(
                        in: &layer, center: CGPoint(x: size.width / 2, y: size.height / 2), diameter: diameter,
                        detail: PlanetSize.detail(videos: main.count), tint: main.platform.tint
                    )
                }
                .frame(width: 160, height: 120)
            }
        case .month:
            YearInReviewMonthChart(months: stats.months, best: stats.bestMonth)
        case .streak:
            Text("\(stats.longestStreakWeeks)").font(.system(size: 64, weight: .heavy)).foregroundStyle(.white).monospacedDigit()
        case .theme:
            if let theme = stats.strongestTheme {
                let color = OnboardingTopic.color(at: theme.topicIndex)
                Capsule().fill(color).frame(width: 6, height: 90)
                    .shadow(color: color.opacity(0.8), radius: 14)
                    .padding(.vertical, 6)
            }
        }
    }

    private var headline: String {
        switch slide {
        case .total: String(localized: "videos shared")
        case .planet: stats.mainPlatform?.platform.label ?? ""
        case .month: stats.bestMonth.flatMap { UniverseContent.monthName($0, calendar: .current) } ?? ""
        case .streak: weeksInARow
        case .theme: stats.strongestTheme?.topic.label ?? ""
        }
    }

    private var line: String {
        switch slide {
        case .total: totalLine
        case .planet: String(localized: "\(stats.mainPlatform?.count ?? 0) videos · where you land most")
        case .month: String(localized: "\(stats.months.max() ?? 0) videos · your busiest month")
        case .streak: String(localized: "weeks with at least one video")
        case .theme: String(localized: "\(stats.strongestTheme?.count ?? 0) videos · the world you return to")
        }
    }

    private var weeksInARow: String {
        if stats.longestStreakWeeks == 1 { return String(localized: "1 week in a row") }
        return String(localized: "\(stats.longestStreakWeeks) weeks in a row")
    }

    private var totalLine: String {
        if isSealed { return String(localized: "in the whole year") }
        return String(localized: "so far this year")
    }
}
