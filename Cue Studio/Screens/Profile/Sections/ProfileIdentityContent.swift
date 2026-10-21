//
//  ProfileIdentityContent.swift
//  Cue Studio
//

import SwiftUI

/// The Profile's first card (9.1; owner's redesign, 21/10/2026, kept short: "too much written"), on the solid surface of the others: the
/// photo in a ring of their universe's light, breathing; the name; "@handle · what you make", or, when there is neither, one yellow
/// invitation ("+ Add a username"). Edit sits in the card. An empty profile (no name, username, photo or type) is the photo, "Your name"
/// and "Set up your profile". The long-press menu shows the same card.
struct ProfileIdentityContent: View {
    let profile: CreatorProfile
    var onEdit: () -> Void = {}

    @Environment(PersonalizationService.self) private var personalization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let avatar: CGFloat = 72

    private var isEmpty: Bool {
        profile.name.trimmingCharacters(in: .whitespaces).isEmpty && profile.handle.isEmpty && profile.photoData == nil
            && profile.role == nil && profile.customRole == nil
    }

    private var creatorType: String? { profile.customRole ?? profile.role?.creatorLabel }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                avatar
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: profile.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(isEmpty ? Palette.ink2 : Palette.ink)
                        .lineLimit(1)
                    if !isEmpty {
                        if let subtitle {
                            Text(verbatim: subtitle).font(.subheadline).foregroundStyle(Palette.ink2).lineLimit(1)
                        } else if let invite {
                            Button(action: onEdit) {
                                Label(invite, systemImage: "plus").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accText)
                            }
                            .buttonStyle(.cuePress)
                            .padding(.top, 1)
                            .accessibilityIdentifier("profile.invite")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, isEmpty ? 18 : 20)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            // Who this is, read as one: a tap anywhere here edits it.
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Edits your name and username"))
            .accessibilityIdentifier("profile.creatorCard")
            .overlay(alignment: .topTrailing) { if !isEmpty { editPill } }
            if isEmpty {
                Button(action: onEdit) {
                    Label("Set up your profile", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.accText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Palette.Settings.toolTileTop, in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.acc.opacity(0.45), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.cuePress)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .accessibilityIdentifier("profile.setUpButton")
            }
            Spacer().frame(height: 18)
        }
        .profileBlock()
    }

    // MARK: - Parts

    /// The photo in a ring of their universe's light, breathing slowly.
    private var avatar: some View {
        let glow = Color(hex: personalization.coreColor.glow.hex)
        return AmbientTimeline { ambient in
            let breath = reduceMotion ? 0.5 : (1 + sin(ambient.seconds / 3.6 * 2 * .pi)) / 2
            ProfileAvatar(profile: profile, size: Self.avatar)
                .padding(3)
                .overlay(Circle().strokeBorder(isEmpty ? Palette.separator : glow, lineWidth: 2))
                .shadow(color: isEmpty ? .clear : glow.opacity(0.25 + 0.25 * breath), radius: 10 + 8 * breath)
        }
        .frame(width: Self.avatar + 6, height: Self.avatar + 6)
        .accessibilityHidden(true)
    }

    private var editPill: some View {
        Button(action: onEdit) {
            Label("Edit", systemImage: "pencil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Palette.surface2, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.cuePress)
        .padding(12)
        .accessibilityIdentifier("profile.editButton")
    }

    // MARK: - Words

    /// "@mayacooks · Lifestyle creator", what of the two there is.
    private var subtitle: String? {
        let parts = [profile.handle.isEmpty ? nil : "@\(profile.handle)", creatorType].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// With no "@handle · type" to show, an invitation to the username.
    private var invite: LocalizedStringKey? {
        profile.handle.isEmpty ? "Add a username" : nil
    }
}
