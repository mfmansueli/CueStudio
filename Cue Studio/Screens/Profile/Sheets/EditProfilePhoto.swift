//
//  EditProfilePhoto.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI
import UIKit

/// The photo at the top of Edit Profile: 96 pt, with "Edit Photo" under it (the system's photo picker; with a photo it also offers Remove).
/// What is picked is cropped to a square and shrunk to 512 px, so the profile keeps a small file.
struct EditProfilePhoto: View {
    @Binding var draft: ProfileDraft
    @Binding var item: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 10) {
            ProfileAvatar(draft: draft, size: 96)
            HStack(spacing: 16) {
                PhotosPicker(selection: $item, matching: .images) {
                    Text("Edit Photo").font(.subheadline)
                }
                .accessibilityIdentifier("editProfile.photoButton")
                if draft.photoData != nil {
                    Button("Remove", role: .destructive) { draft.photoData = nil }
                        .font(.subheadline)
                        .accessibilityIdentifier("editProfile.removePhotoButton")
                }
            }
            .foregroundStyle(Palette.aiText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onChange(of: item) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { draft.photoData = Self.squared(data) }
                self.item = nil
            }
        }
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
