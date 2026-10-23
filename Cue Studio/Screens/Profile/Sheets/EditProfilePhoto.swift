//
//  EditProfilePhoto.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI
import UIKit

/// The top of Edit Profile (owner's redesign, 21/10/2026): "how you appear", the card of the universe a creator shares, live as they type.
/// Over a starry sky (their own, or Serene when theirs is off), the photo with a yellow camera badge (the photo library at once, or
/// Choose / Remove once there is a photo), and under it the name, the @username and the creator type, each in its place-holder until it is
/// filled. What is picked is cropped to a square and shrunk to 512 px, so the profile keeps a small file.
struct EditProfilePhoto: View {
    @Binding var draft: ProfileDraft
    @Binding var item: PhotosPickerItem?

    @Environment(PersonalizationService.self) private var personalization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPicking = false

    private static let avatar: CGFloat = 92

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        ZStack(alignment: .topLeading) {
            SkyMiniature(density: personalization.sky == .off ? .serene : personalization.sky)
            Text("How you appear")
                .monoFont(size: 10, weight: .semibold)
                .interfaceTracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.ink2)
                .padding(14)
            VStack(spacing: 8) {
                photo
                Text(verbatim: draft.trimmedName.isEmpty ? String(localized: "Your name") : draft.trimmedName)
                    .font(.title2.bold())
                    .foregroundStyle(draft.trimmedName.isEmpty ? Palette.ink2 : Palette.ink)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                HStack(spacing: 8) {
                    Text(verbatim: "@" + (draft.handle.isEmpty ? String(localized: "username") : draft.handle))
                        .foregroundStyle(draft.handle.isEmpty ? Palette.ink2 : Palette.ink)
                        .lineLimit(1)
                    if let type = draft.creatorType {
                        Text(verbatim: type)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.accText)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(Palette.Settings.toolTileTop, in: Capsule())
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 34)
            .padding(.bottom, 20)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.4, dampingFraction: 0.75), value: draft.creatorType)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editProfile.preview")
        // The library is presented from here, not from a `PhotosPicker` inside the badge's menu: there it never opens (owner's report,
        // 21/10/2026).
        .photosPicker(isPresented: $isPicking, selection: $item, matching: .images)
        .onChange(of: item) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { draft.photoData = Self.squared(data) }
                self.item = nil
            }
        }
    }

    /// The photo with its camera badge. It holds still: a badge redrawn every frame (it floated in a `TimelineView`) didn't take taps.
    private var photo: some View {
        ProfileAvatar(draft: draft, size: Self.avatar)
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            .overlay(alignment: .bottomTrailing) { badge }
            .frame(height: Self.avatar + 6)
    }

    /// Without a photo the badge opens the library at once; with one, a menu: Choose Photo or Remove Photo.
    @ViewBuilder
    private var badge: some View {
        if draft.photoData == nil {
            Button {
                Haptics.light()
                isPicking = true
            } label: {
                camera
            }
            .buttonStyle(.cuePress)
            .offset(x: 8, y: 8)
            .accessibilityLabel(Text("Edit Photo"))
            .accessibilityIdentifier("editProfile.photoButton")
        } else {
            Menu {
                Button("Choose Photo", systemImage: "photo.on.rectangle") { isPicking = true }
                    .accessibilityIdentifier("editProfile.choosePhotoButton")
                Button("Remove Photo", systemImage: "trash", role: .destructive) { draft.photoData = nil }
                    .accessibilityIdentifier("editProfile.removePhotoButton")
            } label: {
                camera
            }
            .offset(x: 8, y: 8)
            .accessibilityLabel(Text("Edit Photo"))
            .accessibilityIdentifier("editProfile.photoMenu")
        }
    }

    /// The yellow camera badge, with a 44 pt target round it.
    private var camera: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Palette.accInk)
            .frame(width: 32, height: 32)
            .background(Palette.acc, in: Circle())
            .overlay(Circle().strokeBorder(Palette.sheetNight, lineWidth: 3))
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Circle())
    }

    /// The picked image as a 512 px square JPEG, or nil when it cannot be read.
    static func squared(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side = min(image.size.width, image.size.height)
        let target = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let scale = 512 / side
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (target.width - size.width) / 2, y: (target.height - size.height) / 2, width: size.width, height: size.height))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}
