//
//  DockWriterChip.swift
//  Cue Studio
//

import SwiftUI

/// The dock's writer chip (`ScriptsDock`): who writes the next idea, Apple Intelligence (its own symbol, its name given room) or "✦ Ultra AI"
/// in violet once picked, in a menu that says how many Ultra AI scripts are left. It keeps one width whichever writer it shows (the wider
/// look's, `EqualWidthStack`): the system menu closes back onto the same capsule and only what it says changes (on the 18 Pro Max a capsule
/// changing its width as the menu closed broke both, 29/10/2026). Its lights are drawn on the menu, not in its label: the system clips a
/// menu's label to a rectangle, which cut the halo square. A type of its own, so the dock's view type stays shallow enough for the Swift
/// runtime to build (deeper, it overflowed the stack as the dock opened).
struct DockWriterChip: View {
    static let appleIntelligenceSymbol = "apple.intelligence"

    /// Who the next idea goes to (picking asks first where it must, `ScriptsDock.chooseWriter`), and who the chip shows (a step behind,
    /// `ScriptsDock.syncUltra`).
    let writer: Binding<ScriptEngine>
    let showsUltra: Bool
    /// The menu's Ultra AI item ("Ultra AI · 3 of 5 free left").
    let ultraItem: String
    /// The chip as it looks for a writer (`lit`: Ultra AI), lighting (`lights`) or never, stretched to the width it is given (`stretches`).
    let look: (_ lit: Bool, _ lights: Bool, _ stretches: Bool) -> IdeaCardChip
    /// Each change lights the chip: Ultra AI's ring, Cue's light and the ✦'s sparks; Apple Intelligence's light.
    let ultraRing: Int
    let ultraLight: Int
    let appleLight: Int
    /// The dock's row is this high: the lights go round the chip within it.
    let rowHeight: CGFloat
    /// The dock's coordinate space, where `onFrame` tells the chip's frame.
    let space: String
    let onFrame: (CGRect) -> Void
    /// How wide the Ultra AI look is: its ✦ sits 15 pt into it, in the middle of the chip.
    let onUltraLookWidth: (CGFloat) -> Void

    @State private var width: CGFloat = 0
    @State private var ultraWidth: CGFloat = 0

    var body: some View {
        Menu {
            Picker(selection: writer) {
                Text("Apple Intelligence").tag(ScriptEngine.apple)
                Text(verbatim: ultraItem).tag(ScriptEngine.ultra)
            } label: {
                Text("Writes the next script")
            }
        } label: {
            EqualWidthStack {
                look(showsUltra, true, true)
                look(true, false, false)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                        ultraWidth = $0
                        onUltraLookWidth($0)
                    }
                    .hidden()
                look(false, false, false).hidden()
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: {
                width = $0.width
                onFrame($0)
            }
        }
        .overlay { UltraChipRing(trigger: ultraRing) }
        .overlay { light(appleLight, Palette.Scripts.dockGlow) }
        .overlay { light(ultraLight, Palette.Scripts.ultraGlow) }
        // The ✦'s sparks fly from where it sits, 14 pt into Ultra AI's look in the middle of the chip.
        .overlay(alignment: .leading) { UltraChipSparks(trigger: ultraLight).offset(x: (width - ultraWidth) / 2 + 14 - 22) }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Writer, \(writer.wrappedValue == .ultra ? ultraItem : String(localized: "Apple Intelligence"))"))
        .accessibilityShowsLargeContentViewer {
            if showsUltra { Text(verbatim: "✦") } else { Image(systemName: Self.appleIntelligenceSymbol) }
            Text(showsUltra ? String(localized: "Ultra AI") : String(localized: "Apple Intelligence"))
        }
        .accessibilityIdentifier("ideaCard.writerChip")
    }

    /// A light once round the chip, the chip's own height.
    private func light(_ trigger: Int, _ colors: [Color]) -> some View {
        DockChipLight(trigger: trigger, colors: colors).padding(.vertical, (rowHeight - 30) / 2)
    }
}
