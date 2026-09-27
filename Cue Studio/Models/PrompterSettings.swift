//
//  PrompterSettings.swift
//  Cue Studio
//

import Foundation

/// How the prompter looks and scrolls. Shared by Selfie and Studio mode.
nonisolated struct PrompterSettings: Codable, Hashable, Sendable {
    static let speedRange: ClosedRange<Double> = 0.3...3
    static let sizeRange: ClosedRange<Double> = 16...56
    static let lineSpacingRange: ClosedRange<Double> = 1...2
    static let marginRange: ClosedRange<Double> = 0...32
    static let backgroundOpacityRange: ClosedRange<Double> = 0...1
    static let cameraBlurRange: ClosedRange<Double> = 0...20
    static let guideRange: ClosedRange<Double> = 0.1...0.7
    /// Studio mode is read from further away, so its text is bigger than the selfie panel's.
    static let studioScale: Double = 1.35

    var speed: Double = 1
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

    init() {}

    var speedLabel: String {
        speed.formatted(.number.precision(.fractionLength(1))) + "×"
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

    /// Every field is optional so settings saved by older builds keep what they can: a new field
    /// never resets the creator's font, size or speed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PrompterSettings()
        speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? defaults.speed
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
