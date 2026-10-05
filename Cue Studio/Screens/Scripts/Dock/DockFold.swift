//
//  DockFold.swift
//  Cue Studio
//

import CoreGraphics
import os

/// When the dock's first row folds away (09 §6): the list scrolls down past 40 pt (moving more than 2 pt, small moves adding up), and
/// it comes back on any upward movement of more than 2 pt, or when the list is back within 40 pt of the top. Never while the field has
/// the focus. A short list (it scrolls less than 80 pt) folds past half of how far it scrolls, so it can rest folded at its end; one
/// that hardly scrolls (`minimumScroll`) never folds.
///
/// At its end the list moves by itself (it bounces back after being pulled past it): there only going further down counts. The list
/// doesn't move when the row folds: `ScriptsView` keeps the room under it the same, so a fold can't feed back into the next one.
///
/// It reads every frame of a scroll, so the view keeps it as a reference it doesn't observe: only the answer, folded or not, redraws.
/// Each change is written down (Console: subsystem `studio.cue`, category `DockFold`) with where the list was and the scroll's phase,
/// and so is a jump of the list between two readings.
final class DockFold {
    /// Where the list is: how far it is scrolled (0 at the top, growing downwards) and the farthest it can scroll now.
    nonisolated struct Position: Equatable, Sendable {
        var offset: CGFloat
        var end: CGFloat
    }

    /// How far the list has to be scrolled before the row may fold (less on a short list: `threshold(for:)`).
    static let threshold: CGFloat = 40
    /// A list that scrolls less than this never folds the row: there is nothing under the dock to make room for.
    static let minimumScroll: CGFloat = 16
    /// How much the list has to move one way to count as a direction.
    static let slop: CGFloat = 2
    /// A move between two readings this big is worth a line in the log (a finger moves less in a frame).
    static let jump: CGFloat = 120

    private(set) var isFolded = false
    /// The scroll's phase ("interacting", "decelerating", "idle"…), for the log.
    var phase = "idle"
    /// Where the direction is measured from: small moves add up until they are more than the slop.
    private var anchor: CGFloat = 0
    private var last: CGFloat = 0
    /// Why the last reading past the threshold couldn't fold, for the log.
    private var lastBlock: String?
    private static let logger = Logger(subsystem: "studio.cue", category: "DockFold")

    /// Reads where the list is now and says whether the row is folded.
    @discardableResult
    func update(_ position: Position, isEditing: Bool) -> Bool {
        let offset = position.offset
        if abs(offset - last) > Self.jump {
            Self.logger.notice("""
                jump: the list moved \(Double(offset - self.last), format: .fixed(precision: 1)) pt between two readings \
                (offset \(Double(offset), format: .fixed(precision: 1)), end \(Double(position.end), format: .fixed(precision: 1)), \
                phase \(self.phase, privacy: .public))
                """)
        }
        last = offset
        let threshold = Self.threshold(for: position.end)
        if isEditing || position.end < Self.minimumScroll || offset <= threshold {
            let why = isEditing ? "editing" : position.end < Self.minimumScroll ? "list too short" : "near the top"
            set(false, because: why, at: position)
            anchor = offset
            // Why a scroll past the threshold doesn't fold (said once, not every frame).
            let blocked = offset > threshold ? why : nil
            if blocked != lastBlock, let blocked {
                Self.logger.notice("""
                    can't fold: \(blocked, privacy: .public) (offset \(Double(offset), format: .fixed(precision: 1)), \
                    end \(Double(position.end), format: .fixed(precision: 1)), phase \(self.phase, privacy: .public))
                    """)
            }
            lastBlock = blocked
        } else {
            lastBlock = nil
            follow(position)
        }
        return isFolded
    }

    /// Past the threshold, on a list long enough: the direction folds or unfolds the row.
    private func follow(_ position: Position) {
        let offset = position.offset
        if offset >= position.end - Self.slop {
            // At the end only going further down counts: coming back up there is the list settling, not the creator.
            if offset > anchor + Self.slop { set(true, because: "scrolled down into the end", at: position) }
            anchor = offset
        } else if offset > anchor + Self.slop {
            set(true, because: "scrolled down \(Int(offset - anchor)) pt", at: position)
            anchor = offset
        } else if offset < anchor - Self.slop {
            set(false, because: "scrolled up \(Int(anchor - offset)) pt", at: position)
            anchor = offset
        }
    }

    /// How far a list that scrolls to `end` has to be scrolled before the row may fold: 40 pt, or half of a short list, which then
    /// rests folded at its end instead of always being "near the top".
    static func threshold(for end: CGFloat) -> CGFloat {
        min(threshold, end / 2)
    }

    /// The field took the focus: the row comes back.
    @discardableResult
    func unfold() -> Bool {
        if isFolded {
            isFolded = false
            Self.logger.notice("unfolded: the field took the focus")
        }
        return isFolded
    }

    private func set(_ folded: Bool, because reason: String, at position: Position) {
        guard folded != isFolded else { return }
        isFolded = folded
        Self.logger.notice("""
            \(folded ? "folded" : "unfolded", privacy: .public): \(reason, privacy: .public) \
            (offset \(Double(position.offset), format: .fixed(precision: 1)), end \(Double(position.end), format: .fixed(precision: 1)), \
            from \(Double(self.anchor), format: .fixed(precision: 1)), phase \(self.phase, privacy: .public))
            """)
    }
}
