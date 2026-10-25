//
//  MediaLayoutDiagram.swift
//  Cue Studio
//

import SwiftUI

/// A small drawing of where media goes, so the choice reads before its name: a frame with two areas (the split screen, or one
/// of its layouts), a window inside it, all of it covered, or a clip joining a row of clips.
struct MediaLayoutDiagram: View {
    enum Shape: Equatable {
        case mode(MediaInsertMode)
        case split(SplitLayout)
    }

    let shape: Shape
    var isOn = false
    var size = CGSize(width: 22, height: 38)

    private var ink: Color { isOn ? Palette.accText : Palette.ink }

    var body: some View {
        ZStack {
            switch shape {
            case .mode(.sequence): sequence
            case .mode(let mode): frame(for: mode)
            case .split(let layout): splitFrame(layout)
            }
        }
        .frame(width: shape == .mode(.sequence) ? size.height : size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private var outline: some View {
        RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous).strokeBorder(ink, lineWidth: 1.5)
    }

    @ViewBuilder
    private func frame(for mode: MediaInsertMode) -> some View {
        switch mode {
        case .split: splitFrame(SplitLayout())
        case .window:
            ZStack(alignment: .bottomTrailing) {
                outline
                RoundedRectangle(cornerRadius: Metrics.themeRailRadius, style: .continuous).fill(ink)
                    .frame(width: size.width * 0.5, height: size.height * 0.32)
                    .padding(4)
            }
        default:
            ZStack {
                RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous).fill(ink.opacity(0.85))
                outline
            }
        }
    }

    /// The two areas: the support filled, the main video outlined, where the layout puts them.
    private func splitFrame(_ layout: SplitLayout) -> some View {
        let areas = SplitPlacement.areas(layout, in: size)
        return ZStack(alignment: .topLeading) {
            outline
            Rectangle().fill(ink)
                .frame(width: areas.support.width, height: areas.support.height)
                .offset(x: areas.support.minX, y: areas.support.minY)
            Rectangle().fill(ink.opacity(0.25))
                .frame(width: areas.main.width, height: areas.main.height)
                .offset(x: areas.main.minX, y: areas.main.minY)
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous))
        .overlay(outline)
    }

    /// Clips in a row with one more joining them.
    private var sequence: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: Metrics.themeRailRadius).fill(ink.opacity(0.25))
            RoundedRectangle(cornerRadius: Metrics.themeRailRadius).fill(ink)
            RoundedRectangle(cornerRadius: Metrics.themeRailRadius).fill(ink.opacity(0.25))
        }
        .frame(height: size.height * 0.45)
    }
}
