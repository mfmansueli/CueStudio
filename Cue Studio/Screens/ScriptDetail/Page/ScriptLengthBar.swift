//
//  ScriptLengthBar.swift
//  Cue Studio
//

import SwiftUI

/// How long the script runs, in one line over its track: "113 WORDS · ~0:45" on the left and "IDEAL 0:30–1:30" on the right, then a
/// 5 pt track with the ideal range in green and the script's length. The fill tells where it is: yellow under the ideal, green inside
/// it (it says ✓ and glows once on the way in, with a light tap), orange past it (it says how much to cut, with a firm tap). The fill
/// grows on a spring as the creator types; the taps are only for the creator's own words, not the AI's as they arrive. Past the ideal, a line
/// under the track says so ("Past the TikTok ideal") with the button that fits it, when the page can: "Fit with Ultra AI" on a script Ultra AI
/// wrote (one request to Google), "Fit to time" otherwise.
struct ScriptLengthBar: View {
    let zone: LengthZone
    /// The creator's own typing moves it (not the AI writing): crossing into the ideal range or past it is felt.
    var feelsChanges = true
    /// Named in the line past the ideal; nil leaves the line out.
    var platform: Platform?
    /// Fits the script into the ideal; nil when nothing can (no AI for it, or the AI is writing).
    var onFit: (() -> Void)?
    /// Ultra AI fits it, and the button says so.
    var fitsWithUltra = false
    /// The fit is running: the button waits.
    var isFitting = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The light the ideal range gives once as the script comes into it, 1 → 0.
    @State private var glow: Double = 0

    private enum Band {
        case under, ideal, over
    }

    private var band: Band {
        let ideal = zone.preset.idealRange
        if zone.seconds > ideal.upperBound { return .over }
        return zone.seconds >= ideal.lowerBound ? .ideal : .under
    }

    private var fill: Color {
        switch band {
        case .under: Palette.acc
        case .ideal: Palette.success
        case .over: Palette.warn
        }
    }

    private var ink: Color {
        switch band {
        case .under: Palette.accText
        case .ideal: Palette.successText
        case .over: Palette.warnText
        }
    }

    /// "113 words · ~0:45", with "✓" inside the ideal and "Cut 6s" past it.
    private var length: some View {
        let base = String(localized: "\(zone.words) words · ~\(DurationText.clock(zone.seconds))")
        let note: String? = switch band {
        case .under: nil
        case .ideal: "✓"
        case .over: String(localized: "Cut \(DurationText.remaining(zone.seconds - zone.preset.idealRange.upperBound))")
        }
        return Text(note.map { "\(base) · \($0)" } ?? base)
            .foregroundStyle(ink)
            .contentTransition(.numericText())
    }

    private var ideal: some View {
        Text("Ideal \(DurationText.clock(zone.preset.idealRange.lowerBound)) to \(DurationText.clock(zone.preset.idealRange.upperBound))")
            .foregroundStyle(Palette.ink2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            meter
            if band == .over, let platform {
                pastIdeal(platform)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: band)
    }

    /// "Past the TikTok ideal", and the button that fits it.
    private func pastIdeal(_ platform: Platform) -> some View {
        HStack(spacing: 8) {
            Label {
                Text("Past the \(platform.label) ideal")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .cueFont(.footnote, weight: .semibold)
            .foregroundStyle(Palette.warnText)
            .accessibilityIdentifier("page.lengthBar.past")
            Spacer(minLength: 8)
            if let onFit {
                Button(action: onFit) {
                    HStack(spacing: 6) {
                        if isFitting { ProgressView().controlSize(.mini) } else { Image(systemName: "sparkles") }
                        Text(fitsWithUltra ? "Fit with Ultra AI" : "Fit to time")
                    }
                }
                .buttonStyle(.cueAI(.compact, expands: false))
                .disabled(isFitting)
                .accessibilityIdentifier("page.lengthBar.fit")
            }
        }
    }

    private var meter: some View {
        VStack(spacing: 6) {
            // Side by side while they fit; with large text the ideal range goes under the length.
            ViewThatFits(in: .horizontal) {
                HStack {
                    length
                    Spacer(minLength: 8)
                    ideal
                }
                VStack(alignment: .leading, spacing: 2) {
                    length
                    ideal
                }
            }
            .hudFont()
            .textCase(.uppercase)
            .tracking(0.6)
            .lineLimit(1)
            // Stacked, the two lines start where the track starts.
            .frame(maxWidth: .infinity, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.fill)
                    Rectangle()
                        .fill(Palette.success.opacity(0.32 + 0.3 * glow))
                        .frame(width: proxy.size.width * zone.idealWidthFraction)
                        .offset(x: proxy.size.width * zone.idealStartFraction)
                    Capsule()
                        .fill(fill)
                        .frame(width: max(5, proxy.size.width * zone.fillFraction))
                        .shadow(color: fill.opacity(0.5 + 0.4 * glow), radius: 4 + 8 * glow)
                }
                .clipShape(Capsule())
            }
            .frame(height: 5)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.75), value: zone.seconds)
        .animation(.easeOut(duration: 0.25), value: band)
        .onChange(of: band) { _, now in
            guard feelsChanges else { return }
            switch now {
            case .ideal:
                Haptics.apply()
                guard !reduceMotion else { return }
                glow = 1
                withAnimation(.easeOut(duration: 1.0).delay(0.1)) { glow = 0 }
            case .over:
                Haptics.rigid()
            case .under:
                break
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Length"))
        .accessibilityValue(Text("\(zone.words) words, \(DurationText.clock(zone.seconds)). \(zone.status)"))
        .accessibilityIdentifier("page.lengthBar")
    }
}
