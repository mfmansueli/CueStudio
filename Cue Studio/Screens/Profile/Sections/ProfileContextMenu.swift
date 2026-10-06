//
//  ProfileContextMenu.swift
//  Cue Studio
//

import SwiftUI

/// The long press on the identity (9.1): the row lifts over a dimmed Profile and the menu opens under it, in dark glass, 250 pt wide, with the words on the
/// left and the icons on the right: **Copy @handle · Share profile link · Edit profile**. The system's `contextMenu` puts the icons first and can't draw
/// the lifted row like this, so it is Cue's own.
struct ProfileContextMenu: View {
    let profile: CreatorProfile
    /// Where the identity row is, in the space of the screen.
    let frame: CGRect
    let onEdit: () -> Void
    let onClose: () -> Void

    @Environment(ToastService.self) private var toast
    @State private var isShown = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.4).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("profile.menuDismiss")
            ProfileIdentityContent(profile: profile)
                .frame(width: frame.width)
                .scaleEffect(isShown ? 1.02 : 1)
                .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
                .offset(x: frame.minX, y: frame.minY)
                .allowsHitTesting(false)
            menu
                .offset(x: frame.minX, y: frame.maxY + 10)
                .scaleEffect(isShown ? 1 : 0.92, anchor: .topLeading)
                .opacity(isShown ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(duration: 0.28, bounce: 0.2)) { isShown = true } }
        .accessibilityAddTraits(.isModal)
    }

    private var menu: some View {
        VStack(spacing: 0) {
            if !profile.handle.isEmpty {
                item("Copy @handle", systemImage: "doc.on.doc", id: "profile.menu.copy") {
                    Self.copyHandle(of: profile)
                    toast.show(String(localized: "Copied @\(profile.handle)"))
                    onClose()
                }
                separator
                ShareLink(item: ProfileShareText.text(for: profile)) { row("Share profile link", systemImage: "square.and.arrow.up") }
                    .simultaneousGesture(TapGesture().onEnded { onClose() })
                    .accessibilityIdentifier("profile.menu.share")
                separator
            }
            item("Edit profile", systemImage: "pencil", id: "profile.menu.edit") {
                onClose()
                onEdit()
            }
        }
        .frame(width: 250)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var separator: some View { Rectangle().fill(Palette.separator).frame(height: 0.5) }

    private func item(_ title: LocalizedStringKey, systemImage: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { row(title, systemImage: systemImage) }
            .buttonStyle(.plain)
            .accessibilityIdentifier(id)
    }

    private func row(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack {
            Text(title).font(.system(size: 17)).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Image(systemName: systemImage).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    static func copyHandle(of profile: CreatorProfile) {
        UIPasteboard.general.string = "@\(profile.handle)"
    }
}
