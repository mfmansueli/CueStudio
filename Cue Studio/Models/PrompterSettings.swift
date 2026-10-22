//
//  PrompterSettings.swift
//  Cue Studio
//

import Foundation

/// How the prompter looks and scrolls. Shared by Selfie and Studio mode.
nonisolated struct PrompterSettings: Codable, Hashable, Sendable {
    /// The speeds of the slider's ends, 0.2× and 2× (`SpeedScale`): 30 to 300 words a minute, 0.14 to 1.4 of the stored scale. Taken from the
    /// scale so the range and the stops never disagree.
    static let speedRange: ClosedRange<Double> = SpeedScale.slowestSpeed...SpeedScale.fastestSpeed
    /// Selfie text in points, 12 (a long script in a small window) to 56; Studio reads it 1.35× bigger.
    static let sizeRange: ClosedRange<Double> = 12...56
    static let lineSpacingRange: ClosedRange<Double> = 1...2
    static let marginRange: ClosedRange<Double> = 8...40
    static let backgroundOpacityRange: ClosedRange<Double> = 0...1
    static let cameraBlurRange: ClosedRange<Double> = 0...20
    static let guideRange: ClosedRange<Double> = 0.1...0.7
    static let readingWidthRange: ClosedRange<Double> = 0.5...0.93
    static let textWindowHeightRange: ClosedRange<Double> = 160...380
    /// Original window defaults when the creator has not saved another size. New sessions keep
    /// the saved dimensions, and layout clamps them to the space on the current device.
    static let defaultReadingWidth: Double = 0.93
    static let defaultTextWindowHeight: Double = 380
    /// Studio mode is read from further away, so its text is bigger than the selfie panel's.
    static let studioScale: Double = 1.35

    /// Stored as a multiple of `ReadTime.wordsPerMinuteAtOneX` (215 words a minute at 1.0); the default, a natural 150 words a minute (0.698
    /// stored), reads 1× (`SpeedScale`).
    var speed: Double = ReadTime.naturalSpeed
    var font: PrompterFont = .lexend
    var size: Double = 36
    var lineSpacing: Double = 1.35
    var alignment: LineAlignment = .center
    var textColor: PrompterTextColor = .white
    var margin: Double = 20
    /// Selfie text window width as a fraction of the screen, 50% to 93%. Narrowing it keeps the
    /// eyes stiller. The same fraction fits other screen sizes.
    var readingWidth: Double = PrompterSettings.defaultReadingWidth
    /// Selfie text window height in points.
    var textWindowHeight: Double = PrompterSettings.defaultTextWindowHeight
    /// Where the Selfie reading line sits, as its distance below the front camera in points. Nil
    /// keeps the recommended spot (just under the lens, or 36% down the frame with the rear camera).
    /// Kept as a distance from the lens so the line lands in the same place on any iPhone.
    var readingLineOffset: Double?
    /// How dark the Selfie panel is behind the text. Preview only, never recorded.
    var backgroundOpacity: Double = 0.25
    /// Blur of the camera behind the Selfie panel, 0 (off) to 20 (see `CameraBlurLevel`). Preview
    /// only, never recorded.
    var cameraBlur: Double = 0
    var showsGuide: Bool = true
    /// Studio reading line position, as a fraction of the text area height.
    var guidePosition: Double = 0.3
    var isMirrored: Bool = false
    /// Turns the text upside down, for rigs that reflect it from below (Settings › Prompter › Rigs).
    var isFlippedVertically: Bool = false
    /// The safe zone the Selfie camera starts with (`SafeZoneChoice.key`: a platform's raw value or "custom"); nil follows the
    /// script's platform (Settings › Prompter › Social safe zone).
    var safeZoneKey: String?
    var scrollMode: ScrollMode = .steady
    var studioBackground: StudioBackground = .black
    /// AI Coach: performance cues like PAUSE or SMILE in the prompter. Off until the creator turns
    /// it on.
    var showsCues: Bool = false
    /// "Custom" safe zone margins.
    var customSafeZone = SafeZoneMargins()
    // MARK: - The text box and the reading line (v29 · L8)

    /// The recorder's text box, as the v29 handle (⌟) resizes it. The box is the Selfie text window: these are the
    /// same stored values as `readingWidth` and `textWindowHeight`, so nothing is saved twice and settings saved by v27
    /// open at today's size. The width is a fraction of the screen (0.5–0.93), not points, so one value fits every iPhone.
    var boxWidth: Double {
        get { readingWidth }
        set { readingWidth = min(Self.readingWidthRange.upperBound, max(Self.readingWidthRange.lowerBound, newValue)) }
    }

    /// The box's height in points (160–380).
    var boxHeight: Double {
        get { textWindowHeight }
        set { textWindowHeight = min(Self.textWindowHeightRange.upperBound, max(Self.textWindowHeightRange.lowerBound, newValue)) }
    }

    /// The reading line as a fraction of the screen's height, 0.10 (by the camera) to 0.50 (the middle). Stored, like
    /// before, as points below the lens (`readingLineOffset`), so it follows the screen it is read on; nil keeps the
    /// recommended spot (0.22 of a typical iPhone).
    static let readingLineRange: ClosedRange<Double> = 0.10...0.50
    static let defaultReadingLine: Double = 0.22

    func readingLine(on screen: ReadingLinePercent) -> Double {
        screen.percent(for: ReadingLinePlacement(offset: readingLineOffset)) / 100
    }

    mutating func setReadingLine(_ fraction: Double, on screen: ReadingLinePercent) {
        let clamped = min(Self.readingLineRange.upperBound, max(Self.readingLineRange.lowerBound, fraction))
        readingLineOffset = screen.placement(forPercent: clamped * 100).offset
    }

    /// Words a minute that 1.0× meant when `speed` was saved. Builds before v7 read 150 at 1.0×;
    /// a saved speed is converted on load so the creator keeps the pace they chose.
    private(set) var speedCalibration: Double = ReadTime.wordsPerMinuteAtOneX

    init() {}

    /// "1×": how many times the natural reading pace (`SpeedScale`).
    var speedLabel: String {
        SpeedScale.label(forSpeed: speed)
    }

    /// A speed on the slider: on a step of 5 words a minute, within the range.
    static func clampedSpeed(_ value: Double) -> Double {
        let snapped = (value * ReadTime.wordsPerMinuteAtOneX / wordsPerMinuteStep).rounded() * wordsPerMinuteStep / ReadTime.wordsPerMinuteAtOneX
        return min(speedRange.upperBound, max(speedRange.lowerBound, snapped))
    }

    /// The speed slider moves in steps of this many words a minute.
    static let wordsPerMinuteStep: Double = 5

    /// The same reading pace, expressed on the current stored scale: 1.0 saved at 150 words a minute
    /// becomes 0.698 at 215. A speed past today's range (the 3×, 4× and 5× the slider had before 20/10/2026) opens on the nearest end, 2×.
    static func recalibrated(_ speed: Double, savedAt wordsPerMinute: Double) -> Double {
        // Saved on the current scale: kept exactly as it was (only held to the range).
        guard wordsPerMinute != ReadTime.wordsPerMinuteAtOneX else {
            return min(speedRange.upperBound, max(speedRange.lowerBound, speed))
        }
        return clampedSpeed(speed * wordsPerMinute / ReadTime.wordsPerMinuteAtOneX)
    }

    /// "Off", "Subtle", "Soft", "Medium".
    var cameraBlurLabel: String { CameraBlurLevel(amount: cameraBlur).label }

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
        let storedSize = try container.decodeIfPresent(Double.self, forKey: .size) ?? defaults.size
        size = min(Self.sizeRange.upperBound, max(Self.sizeRange.lowerBound, storedSize))
        lineSpacing = try container.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? defaults.lineSpacing
        alignment = (try? container.decodeIfPresent(LineAlignment.self, forKey: .alignment)) ?? defaults.alignment
        textColor = (try? container.decodeIfPresent(PrompterTextColor.self, forKey: .textColor)) ?? defaults.textColor
        let storedMargin = try container.decodeIfPresent(Double.self, forKey: .margin) ?? defaults.margin
        margin = min(Self.marginRange.upperBound, max(Self.marginRange.lowerBound, storedMargin))
        readingWidth = try container.decodeIfPresent(Double.self, forKey: .readingWidth) ?? defaults.readingWidth
        textWindowHeight = try container.decodeIfPresent(Double.self, forKey: .textWindowHeight) ?? defaults.textWindowHeight
        readingLineOffset = try container.decodeIfPresent(Double.self, forKey: .readingLineOffset)
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? defaults.backgroundOpacity
        cameraBlur = try container.decodeIfPresent(Double.self, forKey: .cameraBlur) ?? defaults.cameraBlur
        showsGuide = try container.decodeIfPresent(Bool.self, forKey: .showsGuide) ?? defaults.showsGuide
        guidePosition = try container.decodeIfPresent(Double.self, forKey: .guidePosition) ?? defaults.guidePosition
        isMirrored = try container.decodeIfPresent(Bool.self, forKey: .isMirrored) ?? defaults.isMirrored
        isFlippedVertically = try container.decodeIfPresent(Bool.self, forKey: .isFlippedVertically) ?? defaults.isFlippedVertically
        safeZoneKey = try container.decodeIfPresent(String.self, forKey: .safeZoneKey)
        scrollMode = (try? container.decodeIfPresent(ScrollMode.self, forKey: .scrollMode)) ?? defaults.scrollMode
        studioBackground = (try? container.decodeIfPresent(StudioBackground.self, forKey: .studioBackground)) ?? defaults.studioBackground
        showsCues = try container.decodeIfPresent(Bool.self, forKey: .showsCues) ?? defaults.showsCues
        customSafeZone = (try? container.decodeIfPresent(SafeZoneMargins.self, forKey: .customSafeZone)) ?? defaults.customSafeZone
    }
}
