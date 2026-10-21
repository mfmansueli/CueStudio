//
//  PracticeChapter.swift
//  Cue Studio
//

import SwiftUI

/// What is under the prompter while the creator practices.
struct PracticeChapter: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView().tint(Palette.accText)
            Spacer()
        }
        .accessibilityHidden(true)
    }
}
