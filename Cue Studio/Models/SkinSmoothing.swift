//
//  SkinSmoothing.swift
//  Cue Studio
//

import Foundation

/// Skin's smoothing as one set the engine reads together: how much (`amount`), how much of the skin's fine texture stays
/// (`texture`) and which engine reads the two (`engine`, `ReadingVersion.skin`). A clip that sets its own smoothing sets all
/// three, so one engine's amount is never read with another's texture.
///
/// Engine 1 is the first smoothing (`SkinSmoothingCalibration`), a short dial that always kept most of the texture: an edit
/// made with it keeps it, so it opens, saves and exports as it looked, until the creator updates it (`updated`). It has no
/// texture of its own; `texture` waits there for the update. Engine 2 is the beauty engine (`SkinBeautyCalibration`).
nonisolated struct SkinSmoothing: Codable, Hashable, Sendable {
    /// 0 (off) to 100.
    var amount: Double
    /// 0 to 100: how much of the skin's fine texture (pores, fine lines) stays under the smoothing. Engine 2 only.
    var texture: Double
    var engine: Int

    init(amount: Double = 0, texture: Double = SkinBeautyCalibration.defaultTexture, engine: Int = ReadingVersion.skin.current) {
        self.amount = SkinBeautyCalibration.clamped(amount)
        self.texture = SkinBeautyCalibration.clamped(texture)
        self.engine = engine
    }

    /// Off, on today's engine: what a new edit has.
    static let off = SkinSmoothing()

    /// The first smoothing's dial (`TakeEdit`'s and `ClipLook`'s old `skinSmoothing` number), read by the engine it was made with.
    /// Off when it was 0: nothing in the edit depended on the first engine, so it gets today's.
    static func firstEngine(_ value: Double) -> SkinSmoothing {
        let amount = SkinSmoothingCalibration.clamped(value)
        return amount > 0 ? SkinSmoothing(amount: amount, engine: ReadingVersion.skin.first) : .off
    }

    /// The smoothing changes the picture: above 0, read by an engine this version knows (a newer one's numbers may mean
    /// something else, so they are left out rather than drawn wrong, and kept as they are).
    var isOn: Bool { amount > 0 && ReadingVersion.skin.knows(engine) }

    /// Made with the first engine: drawn as it was, until updated.
    var usesFirstEngine: Bool { engine < ReadingVersion.skin.current }

    /// The first engine's smoothing on today's: an amount that looks about as strong (`SkinBeautyCalibration.updatedAmount`), with
    /// today's texture, so updating changes little until the creator moves it. Today's smoothing stays as it is.
    var updated: SkinSmoothing {
        guard usesFirstEngine else { return self }
        return SkinSmoothing(amount: SkinBeautyCalibration.updatedAmount(fromFirstEngine: amount), texture: texture)
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case amount, texture, engine
    }

    /// Numbers out of range are brought into it, and one that isn't a number is 0 (texture: its default); a set saved without
    /// its engine was made by the first.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = SkinBeautyCalibration.clamped((try? container.decodeIfPresent(Double.self, forKey: .amount)) ?? 0)
        texture = (try? container.decodeIfPresent(Double.self, forKey: .texture)).map(SkinBeautyCalibration.clamped)
            ?? SkinBeautyCalibration.defaultTexture
        engine = ReadingVersion.skin.read(try? container.decodeIfPresent(Int.self, forKey: .engine))
    }
}
