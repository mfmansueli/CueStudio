//
//  EditorToolbarScrollMemory.swift
//  Cue Studio
//

import Foundation

/// Where the toolbar's tools were scrolled, by the tool at the leading edge (an id, so it reads the same right to left): the main
/// tools come back where they were left, after an item's tools or a panel (the toolbar is gone while a panel is open); an item's
/// tools come back where they were after one of its panels, and picking another item of the same kind keeps them; another kind,
/// or an item picked again from the main tools, starts at its first tool. Pure, so the rules are tested without a screen.
struct EditorToolbarScrollMemory {
    private struct Place {
        let context: EditorToolbarContext
        var leadingTool: String?
    }

    private var main: String?
    private var item: Place?

    /// The toolbar shows `context`'s tools: the tool to scroll to the leading edge, nil for the first.
    mutating func enter(_ context: EditorToolbarContext) -> String? {
        if context == .main {
            item = nil
            return main
        }
        if item?.context == context { return item?.leadingTool }
        item = Place(context: context, leadingTool: nil)
        return nil
    }

    /// The tools of `context` were scrolled to `tool` at the leading edge.
    mutating func scrolled(to tool: String?, in context: EditorToolbarContext) {
        if context == .main {
            main = tool
        } else if item?.context == context {
            item?.leadingTool = tool
        } else {
            item = Place(context: context, leadingTool: tool)
        }
    }
}
