//
//  UltraStudyJob+Request.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// The request a case makes, built by the factory the app uses (`ScriptRequestFactory`) with the creator's profile, as the dock and Find
/// inspiration send it: a card's idea arrives as the composer's text with its brief, on Auto length (`FindInspirationSheet.writeNow`). Ultra's
/// jobs (`UltraStudyTests`) and Apple Intelligence's (`AppleStudyDeviceTests`) ask the same.
nonisolated extension UltraStudyJob.Case {
    struct Invalid: Error, CustomStringConvertible {
        let field: String
        var description: String { "The job's \(field) is not one the app knows" }
    }

    var cueLanguage: CueLanguage {
        get throws {
            guard let cueLanguage = CueLanguage(rawValue: language) else { throw Invalid(field: "language") }
            return cueLanguage
        }
    }

    var formatChoice: FormatChoice {
        get throws {
            guard let choice = FormatChoice(id: format) else { throw Invalid(field: "format") }
            return choice
        }
    }

    /// The card's idea, as the library makes it (`IdeaLibrary.ideas`); a creator's own topic ("Cerámica artesanal") is its own name.
    var ideaBrief: IdeaBrief? {
        get throws {
            guard let brief else { return nil }
            return IdeaBrief(
                subject: brief.subject, angle: brief.angle, openingLine: brief.openingLine,
                language: Locale.Language(identifier: try cueLanguage.rawValue).minimalIdentifier, angleKind: brief.angleKind,
                topicKey: brief.topicKey, topic: Niche(rawValue: brief.topicKey)?.promptName ?? brief.topicKey
            ).fitted(to: IdeaBriefReader.cardLimit)
        }
    }

    @MainActor
    func request(engine: ScriptEngine) throws -> ScriptRequest {
        let language = try cueLanguage
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile = try UltraStudyCreators.profile(creator, voice)
        let factory = ScriptRequestFactory(
            profile: profile, scriptLanguage: nil, interfaceLanguage: language,
            preferredLanguages: [language.rawValue]
        )
        guard let platform = Platform(rawValue: self.platform) else { throw Invalid(field: "platform") }
        guard let length = ScriptLength(rawValue: self.length) else { throw Invalid(field: "length") }
        let brief = try ideaBrief
        let text = try brief.map { try UltraStudyComposer.text(of: $0, in: language) } ?? self.idea ?? ""
        let brand = self.brand.map {
            BrandBrief(name: $0.name, product: $0.product, mustSay: $0.mustSay, neverSay: $0.neverSay, link: $0.link, code: $0.code)
        }
        return factory.request(
            idea: text, platform: platform, format: nil, length: brief == nil ? length : .auto, brand: brand, brief: brief,
            formatChoice: try formatChoice, engine: engine
        )
    }
}

nonisolated extension UltraStudyJob {
    var language: CueLanguage { get throws { try item.cueLanguage } }

    var formatChoice: FormatChoice { get throws { try item.formatChoice } }

    var ideaBrief: IdeaBrief? { get throws { try item.ideaBrief } }

    /// The length policy the job asks for in place of the request's own; nil keeps the app's.
    var lengthOverride: UltraLength? {
        guard let length else { return nil }
        let range = (length.low ?? 0)...(length.high ?? 0)
        switch length.kind {
        case "ideal": return .ideal(range)
        case "required": return .required(range)
        case "free": return .free
        default: return nil
        }
    }

    @MainActor
    func request() throws -> ScriptRequest { try item.request(engine: .ultra) }
}
