//
//  PrompterSettings.swift
//  Cue Studio
//

import Foundation

/// How the prompter looks and scrolls. Shared by Selfie and Studio mode.
nonisolated struct PrompterSettings: Codable, Hashable, Sendable {
    static let speedRange: ClosedRange<Double> = 0.3...2
    static let sizeRange: ClosedRange<Double> = 16...56
    static let lineSpacingRange: ClosedRange<Double> = 1...2
    static let marginRange: ClosedRange<Double> = 0...32
    static let backgroundOpacityRange: ClosedRange<Double> = 0...1
    static let cameraBlurRange: ClosedRange<Double> = 0...20
    static let guideRange: ClosedRange<Double> = 0.1...0.7
    /// Studio mode is read from further away, so its text is bigger than the selfie panel's.
    static let studioScale: Double = 1.35

    /// 1.0× is 215 words a minute (`ReadTime`); the default 0.7× is a natural ~150.
    var speed: Double = ReadTime.naturalSpeed
    var font: PrompterFont = .lexend
    var size: Double = 28
    var lineSpacing: Double = 1.35
    var alignment: PrompterAlignment = .center
    var textColor: PrompterTextColor = .white
    var margin: Double = 8
    /// Selfie panel width as a fraction of the screen. Each platform's preset sets it when a script
    /// opens; the creator can fine-tune it between 50% and 75%.
    var readingWidth: Double = 0.6
    /// How dark the Selfie panel is behind the text. Preview only, never recorded.
    var backgroundOpacity: Double = 0.25
    /// Blur of the camera behind the Selfie panel, 0 (off) to 20. Preview only, never recorded.
    var cameraBlur: Double = 0
    var showsGuide: Bool = true
    /// Reading line position, as a fraction of the text area height.
    var guidePosition: Double = 0.3
    var isMirrored: Bool = false
    var scrollMode: ScrollMode = .steady
    var studioBackground: StudioBackground = .black
    /// AI Coach: performance cues like PAUSE or SMILE in the prompter.
    var showsCues: Bool = true
    /// Words a minute that 1.0× meant when `speed` was saved. Builds before v7 read 150 at 1.0×;
    /// a saved speed is converted on load so the creator keeps the pace they chose.
    private(set) var speedCalibration: Double = ReadTime.wordsPerMinuteAtOneX

    init() {}

    var speedLabel: String {
        speed.formatted(.number.precision(.fractionLength(1))) + "×"
    }

    /// A speed on the slider: in tenths, within the range.
    static func clampedSpeed(_ value: Double) -> Double {
        let tenths = (value * 10).rounded() / 10
        return min(speedRange.upperBound, max(speedRange.lowerBound, tenths))
    }

    /// The same reading pace, expressed on the current scale: 1.0× saved at 150 words a minute
    /// becomes 0.7× at 215.
    static func recalibrated(_ speed: Double, savedAt wordsPerMinute: Double) -> Double {
        clampedSpeed(speed * wordsPerMinute / ReadTime.wordsPerMinuteAtOneX)
    }

    /// "Off", "Low", "Medium", "High".
    var cameraBlurLabel: String {
        switch cameraBlur {
        case ...0: String(localized: "Off")
        case ...6: String(localized: "Low")
        case ...13: String(localized: "Medium")
        default: String(localized: "High")
        }
    }

    // MARK: - Coding

    /// What 1.0× read before the calibration was saved with the settings.
    private static let legacyWordsPerMinute: Double = 150

    /// Every field is optional so settings saved by older builds keep what they can: a new field
    /// never resets the creator's font, size or speed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PrompterSettings()
        let savedAt = try container.decodeIfPresent(Double.self, forKey: .speedCalibration) ?? Self.legacyWordsPerMinute
        speed = try container.decodeIfPresent(Double.self, forKey: .speed).map { Self.recalibrated($0, savedAt: savedAt) } ?? defaults.speed
        font = (try? container.decodeIfPresent(PrompterFont.self, forKey: .font)) ?? defaults.font
        size = try container.decodeIfPresent(Double.self, forKey: .size) ?? defaults.size
        lineSpacing = try container.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? defaults.lineSpacing
        alignment = (try? container.decodeIfPresent(PrompterAlignment.self, forKey: .alignment)) ?? defaults.alignment
        textColor = (try? container.decodeIfPresent(PrompterTextColor.self, forKey: .textColor)) ?? defaults.textColor
        let storedMargin = try container.decodeIfPresent(Double.self, forKey: .margin) ?? defaults.margin
        margin = min(Self.marginRange.upperBound, max(Self.marginRange.lowerBound, storedMargin))
        readingWidth = try container.decodeIfPresent(Double.self, forKey: .readingWidth) ?? defaults.readingWidth
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? defaults.backgroundOpacity
        cameraBlur = try container.decodeIfPresent(Double.self, forKey: .cameraBlur) ?? defaults.cameraBlur
        showsGuide = try container.decodeIfPresent(Bool.self, forKey: .showsGuide) ?? defaults.showsGuide
        guidePosition = try container.decodeIfPresent(Double.self, forKey: .guidePosition) ?? defaults.guidePosition
        isMirrored = try container.decodeIfPresent(Bool.self, forKey: .isMirrored) ?? defaults.isMirrored
        scrollMode = (try? container.decodeIfPresent(ScrollMode.self, forKey: .scrollMode)) ?? defaults.scrollMode
        studioBackground = (try? container.decodeIfPresent(StudioBackground.self, forKey: .studioBackground)) ?? defaults.studioBackground
        showsCues = try container.decodeIfPresent(Bool.self, forKey: .showsCues) ?? defaults.showsCues
    }
}
