//
//  CreatorTypePicker.swift
//  Cue Studio
//

import SwiftUI

/// Edit Profile › What you make: the long list of kinds of creator with a search (`CreatorKindPicker`, the same My Cue Voice shows), one
/// chosen at a time (tapped again, none), and, for whoever none of them describes, "+ Add your own" (owner's ask, 21/10/2026): the chip opens
/// into a field in place, and what is typed becomes their own type, chosen, the one My Cue Voice keeps too (`CreatorProfile.customRole`).
/// Their own chip has × to take it away.
struct CreatorTypePicker: View {
    @Binding var draft: ProfileDraft

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isTyping: Bool
    @State private var isAdding = false
    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CreatorKindPicker(
                selected: draft.customRole == nil ? draft.creatorKind : nil, onPick: pick, identifier: "editProfile.role", bleed: 16
            )
            FlowLayout(spacing: 8, lineSpacing: 8) {
                if let custom = draft.customRole {
                    ownChip(custom)
                }
                if isAdding {
                    field
                } else {
                    addChip
                }
            }
        }
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.35, dampingFraction: 0.8), value: draft.creatorKind)
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.35, dampingFraction: 0.8), value: draft.customRole)
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.35, dampingFraction: 0.8), value: isAdding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editProfile.rolePicker")
    }

    /// A kind tapped is chosen in place of their own; the one chosen, tapped again, is let go.
    private func pick(_ kind: CreatorKind) {
        draft.customRole = nil
        if draft.creatorKind == kind.id {
            draft.creatorKind = nil
            draft.role = nil
        } else {
            draft.creatorKind = kind.id
            draft.role = kind.role
        }
    }

    /// Their own type, chosen, with × to take it away.
    private func ownChip(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: title).cueFont(.subheadline).foregroundStyle(Palette.accText).lineLimit(1)
            Button {
                Haptics.light()
                draft.customRole = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.fixed(10, weight: .bold))
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
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .frame(minHeight: 36)
                .overlay(Capsule().strokeBorder(Palette.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Capsule())
        }
        .buttonStyle(.cuePress)
        .accessibilityIdentifier("editProfile.role.add")
    }

    /// The chip opened into a field: Return keeps what is typed as their own type; empty, or focus lost with nothing typed, closes it.
    private var field: some View {
        TextField("Podcaster, chef, gamer…", text: $typed)
            .cueFont(.subheadline)
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
        draft.creatorKind = nil
    }
}
