//
//  ProfileAvatar.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The creator's picture (9.1): their photo when they chose one, otherwise the initial on a violet-to-indigo disc (an astronaut while there is no name).
struct ProfileAvatar: View {
    let profile: CreatorProfile
    var photoData: Data?
    let size: CGFloat

    init(profile: CreatorProfile, size: CGFloat) {
        self.profile = profile
        photoData = profile.photoData
        self.size = size
    }

    /// The avatar of an unsaved draft: its photo and its name.
    init(draft: ProfileDraft, size: CGFloat) {
        profile = CreatorProfile(name: draft.name)
        photoData = draft.photoData
        self.size = size
    }

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Palette.Universe.avatarLight, Palette.Universe.avatarDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let initial {
                        Text(initial)
                            .font(.system(size: size * 0.47, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        // No name yet: an astronaut, the creator-to-be of an empty universe.
                        AstronautMark().padding(size * 0.1)
                    }
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// The first letter of the name (the board's "M"); nil without a name.
    private var initial: String? {
        profile.name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() }
    }
}
