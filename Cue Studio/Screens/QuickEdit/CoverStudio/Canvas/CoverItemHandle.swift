//
//  CoverItemHandle.swift
//  Cue Studio
//

import SwiftUI

/// A graphic on Cover Studio's canvas: a tap picks it, one finger moves it (sticking to the middle and the thirds), two fingers
/// resize and turn it. Picked, its frame turns with it, with ✕ to delete it and a round handle at the corner that resizes and
/// turns it with one finger. VoiceOver can delete it, copy it and move it in front or behind.
struct CoverItemHandle: View {
    let viewModel: CoverStudioViewModel
    let item: CoverItem
    let size: CGSize

    @State private var moveBase: OverlayPoint?
    @State private var transformBase: (scale: Double, rotation: Double)?
    @State private var cornerStart: (distance: Double, angle: Double)?

    var body: some View {
        let frame = viewModel.itemFrame(item, in: size)
        let isSelected = viewModel.selection == .item(item.id)
        let box = CoverStudioViewModel.itemTouchSize(frame.size)
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: box.width, height: box.height)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Palette.acc, lineWidth: 2)
                            .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1)
                            .allowsHitTesting(false)
                    }
                }
                .onTapGesture {
                    Haptics.selection()
                    viewModel.selection = .item(item.id)
                    viewModel.step = .elements
                }
                .gesture(move)
                .simultaneousGesture(pinchAndTurn)
            if isSelected {
                knob("xmark", label: Text("Delete"), id: "cover.itemDelete") { viewModel.deleteItem(item.id) }
                    .offset(x: -box.width / 2, y: -box.height / 2)
                knob("arrow.up.left.and.arrow.down.right", label: Text("Resize and turn"), id: "cover.itemTransform") {}
                    .offset(x: box.width / 2, y: box.height / 2)
                    .gesture(corner(center: frame.center))
            }
        }
        .rotationEffect(.radians(item.rotation))
        .position(frame.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.kind.hasText && !item.text.isEmpty ? "\(item.kind.label): \(item.text)" : item.kind.label))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: Text("Delete")) { viewModel.deleteItem(item.id) }
        .accessibilityAction(named: Text("Duplicate")) { viewModel.duplicateItem(item.id) }
        .accessibilityAction(named: Text("Bring forward")) { viewModel.restackItem(item.id, forward: true) }
        .accessibilityAction(named: Text("Send backward")) { viewModel.restackItem(item.id, forward: false) }
        .accessibilityIdentifier("cover.item.\(item.kind.rawValue)")
    }

    /// White, 24 pt, held from 44 pt.
    private func knob(_ symbol: String, label: Text, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.accInk)
                .frame(width: 24, height: 24)
                .background(Palette.Editor.overlayOutline, in: Circle())
                .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 2, y: 1)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private var move: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(CoverCanvas.space))
            .onChanged { value in
                if moveBase == nil {
                    viewModel.beginGesture()
                    viewModel.selection = .item(item.id)
                    moveBase = item.center
                }
                if let base = moveBase { viewModel.moveItem(item.id, from: base, by: value.translation, in: size) }
            }
            .onEnded { _ in
                moveBase = nil
                viewModel.endGesture()
            }
    }

    private var pinchAndTurn: some Gesture {
        MagnifyGesture().simultaneously(with: RotateGesture())
            .onChanged { value in
                if transformBase == nil {
                    viewModel.beginGesture()
                    viewModel.selection = .item(item.id)
                    transformBase = (item.scale, item.rotation)
                }
                guard let base = transformBase else { return }
                viewModel.transformItem(
                    item.id, from: base, scale: Double(value.first?.magnification ?? 1), rotation: value.second?.rotation.radians ?? 0
                )
            }
            .onEnded { _ in
                transformBase = nil
                viewModel.endGesture()
            }
    }

    /// The corner handle: how far from the center and at what angle the finger is, against where it started.
    private func corner(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(CoverCanvas.space))
            .onChanged { value in
                let dx = Double(value.location.x - center.x), dy = Double(value.location.y - center.y)
                if cornerStart == nil {
                    viewModel.beginGesture()
                    let sx = Double(value.startLocation.x - center.x), sy = Double(value.startLocation.y - center.y)
                    cornerStart = (max(1, (sx * sx + sy * sy).squareRoot()), atan2(sy, sx))
                    transformBase = (item.scale, item.rotation)
                }
                guard let start = cornerStart, let base = transformBase else { return }
                let distance = max(1, (dx * dx + dy * dy).squareRoot())
                viewModel.transformItem(item.id, from: base, scale: distance / start.distance, rotation: atan2(dy, dx) - start.angle)
            }
            .onEnded { _ in
                cornerStart = nil
                transformBase = nil
                viewModel.endGesture()
            }
    }
}
