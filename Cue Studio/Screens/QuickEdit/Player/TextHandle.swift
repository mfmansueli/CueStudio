//
//  TextHandle.swift
//  Cue Studio
//

import SwiftUI

/// A text on the preview, in its place and turned as it is. Tapped, it's picked (again: Text style opens); picked, its box
/// shows in yellow, turned with it, with ✕ at one corner, the handle that resizes and turns it at the opposite one and a tab
/// on each side that makes its lines longer or shorter. Moving it with one or two fingers is the preview's gesture
/// (`OverlayEditingLayer`); while any gesture has it, its picture follows (`TextManipulation`). Locked, it keeps ✕ and shows a
/// lock where the resize handle was, and no side tabs: a tap on the lock says how to unlock it.
struct TextHandle: View {
    let viewModel: QuickEditViewModel
    let text: TextOverlay
    let size: CGSize
    let manipulation: TextManipulation?
    /// A handle of `grip` moved (nil: let go).
    let onGrip: (TextGrip, DragGesture.Value?) -> Void
    /// The coordinate space the handles' drags are measured in: the preview's.
    let space: String

    /// Narrower than this, a text shows no side tabs (they'd crowd its corners).
    private static let shortestWithTabs: CGFloat = 56

    var body: some View {
        let frame = viewModel.overlays.frame(ofText: text, in: size)
        let center = manipulation?.currentCenter ?? CGPoint(x: frame.midX, y: frame.midY)
        let box = manipulation?.currentBox ?? frame.size
        let turn = manipulation?.currentRotation ?? viewModel.overlays.rotation(ofText: text)
        let isSelected = viewModel.selection == .text(text.id)
        ZStack {
            if let manipulation, manipulation.drawing != nil, let image = manipulation.drawing?.image {
                // The video leaves the text out while a gesture has it: this is the only copy.
                Image(uiImage: image)
                    .resizable()
                    .frame(width: manipulation.pictureSize.width, height: manipulation.pictureSize.height)
                    .opacity(manipulation.opacity)
                    .allowsHitTesting(false)
            }
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: max(box.width, Metrics.hitTarget), height: max(box.height, Metrics.hitTarget))
                .onTapGesture { viewModel.overlays.tapText(text.id) }
                // VoiceOver: the text itself, activated like a tap, placed with its actions; Delete and Resize stay apart.
                .accessibilityElement()
                .accessibilityLabel(Text(text.isEmpty ? text.role.label : text.displayText))
                .accessibilityValue(viewModel.overlays.isLocked(text.id) ? Text("Locked") : Text(verbatim: ""))
                .accessibilityHint(isSelected ? Text("Tap to style") : Text("Tap to select"))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { viewModel.overlays.tapText(text.id) }
                .accessibilityActions { placingActions }
                .accessibilityIdentifier("edit.textHandle")
            if isSelected { selectionBox(box) }
        }
        .rotationEffect(.radians(turn))
        .position(center)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Picked

    @ViewBuilder
    private func selectionBox(_ box: CGSize) -> some View {
        RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous)
            .strokeBorder(Palette.acc, lineWidth: 2)
            .frame(width: box.width + 10, height: box.height + 10)
            .allowsHitTesting(false)
        cornerButton("xmark", label: Text("Delete text"), id: "edit.textDelete") {
            viewModel.overlays.deleteText(text.id)
        }
        .offset(x: -(box.width / 2 + 5), y: -(box.height / 2 + 5))
        if viewModel.overlays.isLocked(text.id) {
            cornerButton("lock.fill", label: Text("Locked"), id: "edit.textLocked") {
                viewModel.overlays.sayLocked(text.id)
            }
            .accessibilityHint(Text("Unlock it to move, resize or turn it"))
            .offset(x: box.width / 2 + 5, y: box.height / 2 + 5)
        } else {
            cornerGrip
                .offset(x: box.width / 2 + 5, y: box.height / 2 + 5)
        }
        if text.graphic == nil, box.width >= Self.shortestWithTabs, !viewModel.overlays.isLocked(text.id) {
            sideTab(.leading).offset(x: -(box.width / 2 + 5))
            sideTab(.trailing).offset(x: box.width / 2 + 5)
        }
    }

    /// The corner opposite ✕: dragged away from the text's middle or toward it, the text grows or shrinks; dragged round it,
    /// it turns. Not a button (a button keeps the drag to itself): a mark with a drag, read by VoiceOver as what it does.
    private var cornerGrip: some View {
        glyph("arrow.up.left.and.arrow.down.right")
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .gesture(grip(.corner))
            .accessibilityElement()
            .accessibilityLabel(Text("Resize or turn text"))
            .accessibilityHint(Text("Drag away or round the text. Or use the text's actions."))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("edit.textScale")
    }

    /// A white tab on a side: pulled out, the text's lines get longer; pushed in, shorter. The other side stays.
    private func sideTab(_ side: TextGrip) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: 6, height: 20)
            .shadow(color: Palette.textShadow, radius: 2, y: 1)
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .gesture(grip(side))
            .accessibilityHidden(true)
            .accessibilityIdentifier(side == .leading ? "edit.textWidth.leading" : "edit.textWidth.trailing")
    }

    private func grip(_ grip: TextGrip) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(space))
            .onChanged { onGrip(grip, $0) }
            .onEnded { _ in onGrip(grip, nil) }
    }

    /// A white 24 pt disc with a black symbol: the handles' look.
    private func glyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.editorGlyph(EditorGlyph.small, weight: .bold))
            .foregroundStyle(Color.black)
            .frame(width: 24, height: 24)
            .background(Color.white, in: Circle())
            .shadow(color: Palette.textShadow, radius: 2, y: 1)
    }

    /// White, 24 pt, held from 44 pt.
    private func cornerButton(_ symbol: String, label: Text, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            glyph(symbol)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    // MARK: - VoiceOver

    /// VoiceOver's drag, pinch and turn: a step up, down, left or right, bigger or smaller, a turn either way
    /// (`OverlaysViewModel+Accessibility`).
    @ViewBuilder
    private var placingActions: some View {
        let step = OverlaysViewModel.overlayStep
        let item = OverlaysViewModel.MotionItem.text(text.id)
        Button("Move up") { viewModel.overlays.nudgeOverlay(item, x: 0, y: -step) }
        Button("Move down") { viewModel.overlays.nudgeOverlay(item, x: 0, y: step) }
        Button("Move left") { viewModel.overlays.nudgeOverlay(item, x: -step, y: 0) }
        Button("Move right") { viewModel.overlays.nudgeOverlay(item, x: step, y: 0) }
        Button("Bigger") { viewModel.overlays.resizeOverlay(item, bigger: true) }
        Button("Smaller") { viewModel.overlays.resizeOverlay(item, bigger: false) }
        Button("Turn right") { viewModel.overlays.turnText(text.id, clockwise: true) }
        Button("Turn left") { viewModel.overlays.turnText(text.id, clockwise: false) }
    }
}
