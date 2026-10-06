//
//  ProfileIdentityRow.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · who the creator is: avatar (60 pt), name, "@handle · Creator type" and a chevron. A tap (or Edit) opens Edit Profile; a long press (480 ms) lifts
/// the row and shows the menu (`ProfileContextMenu`): Copy @handle · Share profile link · Edit profile.
struct ProfileIdentityRow: View {
    let profile: CreatorProfile
    let onEdit: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ProfileIdentityContent(profile: profile)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
            .onLongPressGesture(minimumDuration: 0.48) {
                Haptics.medium()
                onMenu()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Edits your name and username"))
            .accessibilityAction(named: Text("Copy @handle")) { ProfileContextMenu.copyHandle(of: profile) }
            .accessibilityAction(named: Text("Edit profile"), onEdit)
    }
}
