//
//  VoiceEffectRendererTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// Voice effects made on the device (`VoiceEffectRenderer`): every one changes the voice, keeps its length to the sample (so it
/// stays on the lips), is as loud as the voice was (comparing with the original never lies) and never goes over the ceiling;
/// Deep voice and Chipmunk move the pitch the right way; "Amount" changes how much; the same setting is made once; a cancel
/// stops it.
@Suite("Voice effect renderer", .serialized)
struct VoiceEffectRendererTests {
    @Test(arguments: VoiceEffect.allCases)
    func changesTheVoiceAndKeepsItsLengthAndLoudness(_ effect: VoiceEffect) async throws {
        let voice = try TestVoice.make(seconds: 3, loud: [0.3...1.2, 1.5...2.6])
        defer { try? FileManager.default.removeItem(at: voice) }
        let rendered = try await VoiceEffectRenderer.render(file: voice, setting: VoiceEffectSetting(effect: effect), clip: "test-\(effect)")
        let dry = try TestVoice.samples(of: voice), wet = try TestVoice.samples(of: rendered)
        #expect(wet.samples.count == dry.samples.count)
        #expect(wet.samples.allSatisfy { $0.isFinite })
        #expect((wet.samples.map(abs).max() ?? 0) <= AudioCeiling.ceiling + 0.000_1)
        let dryLevel = try #require(try SpeechLoudness.level(ofAudio: voice))
        let wetLevel = try #require(try SpeechLoudness.level(ofAudio: rendered))
        #expect(abs(dryLevel - wetLevel) < 1.5)
        // Clearly another sound: what changed is at least a tenth of the voice.
        let difference = zip(dry.samples, wet.samples).reduce(Float(0)) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
        let power = dry.samples.reduce(Float(0)) { $0 + $1 * $1 }
        #expect(difference / power > 0.01)
    }

    @Test func deepGoesDownAndChipmunkGoesUp() async throws {
        let tone = try TestTone.make(seconds: 2, amplitude: 0.3)
        defer { try? FileManager.default.removeItem(at: tone) }
        let source = try TestVoice.samples(of: tone)
        let base = TestVoice.crossingsPerSecond(Array(source.samples[9600..<86_400]), rate: source.rate)
        let deep = try TestVoice.samples(of: try await VoiceEffectRenderer.render(file: tone, setting: .init(effect: .deep), clip: "pitch-deep"))
        let high = try TestVoice.samples(of: try await VoiceEffectRenderer.render(file: tone, setting: .init(effect: .chipmunk), clip: "pitch-high"))
        // Deep voice at 70%: 5.8 semitones down (×0.72); Chipmunk at 70%: 7.5 up (×1.54).
        let down = TestVoice.crossingsPerSecond(Array(deep.samples[9600..<86_400]), rate: deep.rate) / base
        let up = TestVoice.crossingsPerSecond(Array(high.samples[9600..<86_400]), rate: high.rate) / base
        #expect(abs(down - 0.716) < 0.05)
        #expect(abs(up - 1.542) < 0.08)
    }

    @Test func amountChangesHowMuch() async throws {
        let voice = try TestVoice.make(seconds: 2)
        defer { try? FileManager.default.removeItem(at: voice) }
        let dry = try TestVoice.samples(of: voice).samples
        func change(_ amount: Double) async throws -> Float {
            let url = try await VoiceEffectRenderer.render(file: voice, setting: .init(effect: .echo, amount: amount), clip: "amount-\(amount)")
            let wet = try TestVoice.samples(of: url).samples
            return zip(dry, wet).reduce(Float(0)) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
        }
        #expect(try await change(1) > 1.5 * (try await change(0.2)))
    }

    @Test func theSameSettingIsMadeOnce() async throws {
        let voice = try TestVoice.make(seconds: 1)
        defer { try? FileManager.default.removeItem(at: voice) }
        let setting = VoiceEffectSetting(effect: .radio, amount: 0.5)
        let first = try await VoiceEffectRenderer.render(file: voice, setting: setting, clip: "once")
        let date = try #require(try FileManager.default.attributesOfItem(atPath: first.path(percentEncoded: false))[.modificationDate] as? Date)
        let second = try await VoiceEffectRenderer.render(file: voice, setting: setting, clip: "once")
        #expect(first == second)
        #expect(try FileManager.default.attributesOfItem(atPath: second.path(percentEncoded: false))[.modificationDate] as? Date == date)
        // Another amount is another file.
        #expect(try await VoiceEffectRenderer.render(file: voice, setting: .init(effect: .radio, amount: 0.9), clip: "once") != first)
    }

    @Test func aCancelStopsIt() async throws {
        let voice = try TestVoice.make(seconds: 40)
        defer { try? FileManager.default.removeItem(at: voice) }
        let work = Task { try await VoiceEffectRenderer.render(file: voice, setting: .init(effect: .hall), clip: "cancelled") }
        work.cancel()
        await #expect(throws: CancellationError.self) { try await work.value }
    }

    @Test func settingsStepByFivePercentAndReadBack() throws {
        var setting = VoiceEffectSetting(effect: .robot, amount: 0.33)
        #expect(setting.amount == 0.35)
        setting.amount = 2
        #expect(setting.amount == 1)
        setting.amount = 0
        #expect(setting.amount == VoiceEffectSetting.amountRange.lowerBound)
        let saved = try JSONEncoder().encode(VoiceEffectSetting(effect: .megaphone, amount: 0.4))
        #expect(try JSONDecoder().decode(VoiceEffectSetting.self, from: saved) == VoiceEffectSetting(effect: .megaphone, amount: 0.4))
        // An effect this version doesn't know: the clip plays as recorded.
        #expect((try? JSONDecoder().decode(VoiceEffectSetting.self, from: Data(#"{"effect":"alien","amount":0.5}"#.utf8))) == nil)
    }
}
