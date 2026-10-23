//
//  EditorCard.swift
//  Cue Studio
//

import SwiftUI

/// How an editor card stands (`editorCard`): the panels' card; picked (the accent tile and its ring: a choice that is on);
/// marked (the accent card and its ring: what Clean Up takes out); or a fill of its own (a line being written, a suggestion).
enum EditorCardState: Equatable {
    case plain, picked, marked
    case filled(Color)

    var fill: Color {
        switch self {
        case .plain: Palette.Editor.panelCard
        case .picked: Palette.Editor.accTile
        case .marked: Palette.Editor.accCard
        case .filled(let color): color
        }
    }

    var hasRing: Bool { self == .picked || self == .marked }
}

extension Shape where Self == RoundedRectangle {
    /// The editor card's shape, for its touch area (`contentShape(.editorCard)`).
    static var editorCard: RoundedRectangle { RoundedRectangle(cornerRadius: Metrics.editorCardRadius, style: .continuous) }
}

extension View {
    /// The one card of the editor's panels and sheets: its fill on `Metrics.editorCardRadius`, with the accent ring when it is
    /// picked or marked (always drawn, clear when off, so it fades in and out). `clips` cuts what's inside to its corners
    /// (a list of rows). Padding stays with the content.
    func editorCard(_ state: EditorCardState = .plain, clips: Bool = false) -> some View {
        modifier(EditorCard(state: state, clips: clips))
    }
}

/// `editorCard(_:clips:)`.
private struct EditorCard: ViewModifier {
    let state: EditorCardState
    let clips: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.editorCardRadius, style: .continuous)
        let card = content
            .background(state.fill, in: shape)
            .overlay(shape.strokeBorder(state.hasRing ? Palette.acc : .clear, lineWidth: Metrics.editorCardRing))
        if clips {
            card.clipShape(shape)
        } else {
            card
        }
    }
}
