//
//  VoiceEffectSetting.swift
//  Cue Studio
//

import Foundation

/// A voice effect and how much of it (Voice effects' "Amount"), on a clip (`EditSegment.voiceEffect`) or a voice-over
/// (`VoiceOverClip.voiceEffect`). Kept in steps of 5%, so a slider's small moves don't each make a new file.
nonisolated struct VoiceEffectSetting: Codable, Hashable, Sendable {
    static let amountRange: ClosedRange<Double> = 0.1...1
    /// What a newly picked effect starts at: clearly heard, not all the way.
    static let defaultAmount = 0.7

    var effect: VoiceEffect
    /// 0.1 to 1.
    var amount: Double {
        didSet { amount = Self.stepped(amount) }
    }

    init(effect: VoiceEffect, amount: Double = VoiceEffectSetting.defaultAmount) {
        self.effect = effect
        self.amount = Self.stepped(amount)
    }

    private static func stepped(_ amount: Double) -> Double {
        let clamped = min(max(amount, amountRange.lowerBound), amountRange.upperBound)
        return (clamped * 20).rounded() / 20
    }

    private enum CodingKeys: String, CodingKey { case effect, amount }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        effect = try container.decode(VoiceEffect.self, forKey: .effect)
        amount = Self.stepped((try? container.decodeIfPresent(Double.self, forKey: .amount)) ?? Self.defaultAmount)
    }
}
