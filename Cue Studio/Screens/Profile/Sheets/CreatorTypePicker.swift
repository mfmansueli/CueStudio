//
//  CreatorTypePicker.swift
//  Cue Studio
//

import SwiftUI

/// Edit Profile › What you make: the creator types as chips to tap, one chosen at a time (tapped again, none), and, for whoever none of
/// them describes, "+ Add your own" (owner's ask, 21/10/2026): the chip opens into a field in place, and what is typed becomes their own
/// type, chosen, the one My Cue Voice keeps too (`CreatorProfile.customRole`). Their own chip has × to take it away.
struct CreatorTypePicker: View {
    @Binding var draft: ProfileDraft

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isTyping: Bool
    @State private var isAdding = false
    @State private var typed = ""

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(CreatorRole.allCases) { role in
                chip(role.creatorLabel, isOn: draft.customRole == nil && draft.role == role) {
                    draft.customRole = nil
                    draft.role = draft.role == role ? nil : role
                }
                .accessibilityIdentifier("editProfile.role.\(role.rawValue)")
            }
            if let custom = draft.customRole {
                ownChip(custom)
            }
            if isAdding {
                field
            } else {
                addChip
            }
        }
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.35, dampingFraction: 0.8), value: draft.role)
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.35, dampingFraction: 0.8), value: draft.customRole)
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.35, dampingFraction: 0.8), value: isAdding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editProfile.rolePicker")
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(verbatim: title)
                .font(.subheadline)
                .foregroundStyle(isOn ? Palette.accText : Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(isOn ? Palette.Settings.toolTileTop : Palette.surface2, in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? Palette.acc : Palette.separator, lineWidth: isOn ? 1.5 : 0.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.cuePress)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// Their own type, chosen, with × to take it away.
    private func ownChip(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: title).font(.subheadline).foregroundStyle(Palette.accText).lineLimit(1)
            Button {
                Haptics.light()
                draft.customRole = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.accText)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .accessibilityLabel(Text("Remove \(title)"))
            .accessibilityIdentifier("editProfile.role.removeOwn")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 36)
        .background(Palette.Settings.toolTileTop, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.acc, lineWidth: 1.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editProfile.role.own")
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var addChip: some View {
        Button {
            Haptics.light()
            typed = ""
            isAdding = true
            isTyping = true
        } label: {
            Label("Add your own", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .overlay(Capsule().strokeBorder(Palette.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Capsule())
        }
        .buttonStyle(.cuePress)
        .accessibilityIdentifier("editProfile.role.add")
    }

    /// The chip opened into a field: Return keeps what is typed as their own type; empty, or focus lost with nothing typed, closes it.
    private var field: some View {
        TextField("Podcaster, chef, gamer…", text: $typed)
            .font(.subheadline)
            .foregroundStyle(Palette.ink)
            .focused($isTyping)
            .submitLabel(.done)
            .onSubmit(add)
            .onChange(of: typed) { _, text in
                if text.count > ProfileDraft.customRoleLimit { typed = String(text.prefix(ProfileDraft.customRoleLimit)) }
            }
            .onChange(of: isTyping) { _, focused in
                if !focused { add() }
            }
            .padding(.horizontal, 14)
            .frame(width: 210, height: 36)
            .background(Palette.surface2, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.acc, lineWidth: 1.5))
            .accessibilityIdentifier("editProfile.role.field")
            .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func add() {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        isAdding = false
        guard !text.isEmpty else { return }
        Haptics.selection()
        draft.customRole = text
    }
}
