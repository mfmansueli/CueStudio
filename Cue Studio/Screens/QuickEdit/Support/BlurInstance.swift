//
//  BlurInstance.swift
//  Cue Studio
//

import Foundation

/// One showing of a Blur area on its track: an area on a clip shows again on the clip's copies (and on a reversed or frozen
/// clip of it), each a bar of its own that trims the same area.
struct BlurInstance: Equatable {
    /// The bar's own id: the area's for its first showing, one made from it for the others.
    let id: UUID
    let regionID: UUID
    /// Edited seconds.
    let span: TimeSpan
    /// Where it's left unchecked in this showing (edited seconds).
    let warnings: [TimeSpan]
    let label: String

    /// The id of showing `index` of area `region`: the area's own for the first, then one derived from it.
    static func id(_ region: UUID, _ index: Int) -> UUID {
        guard index > 0 else { return region }
        var bytes = region.uuid
        bytes.15 ^= UInt8(truncatingIfNeeded: index)
        bytes.14 ^= UInt8(truncatingIfNeeded: index >> 8) ^ 0x5A
        return UUID(uuid: bytes)
    }
}
