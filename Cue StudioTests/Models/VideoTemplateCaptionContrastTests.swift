//
//  VideoTemplateCaptionContrastTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Every template's captions read over the brightest and the darkest scene: the words against what is right behind them (the
/// look's fill, the preset's plate over the scene, or the outline) reach 4.5:1, and the color of the word being said, where it
/// is only colored, 3:1 (captions are large text).
@Suite("Video template captions contrast")
struct VideoTemplateCaptionContrastTests {
    private typealias RGB = ColorContrast.RGB

    private static let scenes = [RGB(red: 1, green: 1, blue: 1), RGB(red: 0, green: 0, blue: 0)]

    private static func rgb(_ color: OverlayColor) -> RGB {
        RGB(red: color.components.red, green: color.components.green, blue: color.components.blue)
    }

    private static func rgb(_ color: CaptionStyleSpec.RGB) -> RGB {
        RGB(red: color.red, green: color.green, blue: color.blue)
    }

    /// What is right behind the words over `scene`: the fill, the plate, or the outline; nil when nothing is (only a shadow).
    private static func surface(_ settings: CaptionSettings, over scene: RGB) -> RGB? {
        if let look = settings.customLook {
            if look.background != .none {
                return ColorContrast.composite(rgb(look.backgroundColor), alpha: look.backgroundOpacity, over: scene)
            }
            return look.hasOutline ? RGB(red: 0, green: 0, blue: 0) : nil
        }
        switch settings.spec.plate {
        case let .block(color, _, _, _), let .perLine(color, _, _, _):
            return ColorContrast.composite(rgb(color), alpha: color.alpha, over: scene)
        case .none:
            return settings.spec.outline.map { rgb($0.color) }
        }
    }

    @Test(arguments: VideoTemplate.allCases)
    func theCaptionsReadOnABrightAndADarkScene(_ template: VideoTemplate) throws {
        let settings = template.captionSettings
        let text = settings.customLook.map { Self.rgb($0.color) } ?? Self.rgb(settings.spec.textColor)
        for scene in Self.scenes {
            let behind = try #require(Self.surface(settings, over: scene), "\(template): nothing behind the words but a shadow")
            let words = ColorContrast.ratio(text, behind)
            #expect(words >= ColorContrast.textMinimum, "\(template) words \(words):1")
            if template.captionReveal == .highlight, !settings.spec.highlightsWithBox {
                let lit = settings.highlightColor.components
                let said = ColorContrast.ratio(RGB(red: lit.red, green: lit.green, blue: lit.blue), behind)
                #expect(said >= ColorContrast.largeTextMinimum, "\(template) word being said \(said):1")
            }
        }
    }
}
