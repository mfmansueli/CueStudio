//
//  CaptionLineSizes.swift
//  Cue Studio
//

import CoreGraphics
import Synchronization

/// The size each caption line was laid out at, kept across builds: laying a line out (TextKit, balanced over two lines, the
/// type shrunk until it fits) is most of what a captioned preview costs to build, and most builds change no line (a look, a
/// cut, a sound). A long take's hundreds of lines are laid out once; a corrected line, a new size or another preset is laid
/// out again. Shared by every build, on any thread.
nonisolated enum CaptionLineSizes {
    struct Key: Hashable {
        let text: String
        let settings: CaptionSettings
        let frame: CGSize

        func hash(into hasher: inout Hasher) {
            hasher.combine(text)
            hasher.combine(settings)
            hasher.combine(frame.width)
            hasher.combine(frame.height)
        }

        static func == (lhs: Key, rhs: Key) -> Bool {
            lhs.text == rhs.text && lhs.settings == rhs.settings && lhs.frame == rhs.frame
        }
    }

    /// More than a long take's lines in two or three looks; past it, everything is laid out again as it is asked for.
    static let limit = 4000

    private static let sizes = Mutex<[Key: CGSize]>([:])

    /// Every line laid out again from now on (tests compare a layout with the one kept).
    static func forget() {
        sizes.withLock { $0.removeAll() }
    }

    /// Whether the line was laid out already.
    static func isKnown(_ key: Key) -> Bool {
        sizes.withLock { $0[key] != nil }
    }

    /// The size `text` is laid out at with `settings` on `frame`, laid out by `layout` the first time; nil (never kept) when
    /// there is nothing to lay out.
    static func size(_ text: String, settings: CaptionSettings, frame: CGSize, layout: () -> CGSize?) -> CGSize? {
        let key = Key(text: text, settings: settings, frame: frame)
        if let known = sizes.withLock({ $0[key] }) { return known }
        guard let size = layout() else { return nil }
        sizes.withLock { sizes in
            if sizes.count >= limit { sizes.removeAll(keepingCapacity: true) }
            sizes[key] = size
        }
        return size
    }
}
