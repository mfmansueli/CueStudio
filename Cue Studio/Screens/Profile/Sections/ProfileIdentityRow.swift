//
//  ProfileIdentityRow.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · who the creator is (`ProfileIdentityContent`). A tap (or Edit) opens Edit Profile; a long press (480 ms) lifts the card and shows
/// the menu (`ProfileContextMenu`): Copy @handle · Share profile link · Edit profile.
struct ProfileIdentityRow: View {
    let profile: CreatorProfile
    let onEdit: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ProfileIdentityContent(profile: profile, onEdit: onEdit)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
            .onLongPressGesture(minimumDuration: 0.48) {
                Haptics.medium()
                onMenu()
            }
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: Text("Copy @handle")) { ProfileContextMenu.copyHandle(of: profile) }
            .accessibilityAction(named: Text("Edit profile"), onEdit)
    }
}
