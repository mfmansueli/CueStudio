//
//  PrompterTextOverlays.swift
//  Cue Studio
//

import SwiftUI

/// What sits on the text window besides the words: the section rail on its right edge, "✦ FOLLOWING YOUR VOICE"
/// at the bottom left and the section label at the bottom right.
struct PrompterTextOverlays: View {
    let viewModel: PrompterViewModel

    @State private var sections = PrompterSections(markers: [])

    var body: some View {
        let isMeaningful = sections.isMeaningful
        let current = isMeaningful ? sections.index(atParagraph: viewModel.readingParagraph) : 0
        ZStack {
            if isMeaningful {
                SectionRail(sections: sections, current: current, progress: viewModel.engine.progress)
                    .padding(.vertical, 18)
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            HStack(alignment: .bottom) {
                if viewModel.followsSpeech && viewModel.isPlaying { FollowingVoiceChip().transition(.opacity) }
                Spacer(minLength: 8)
                if isMeaningful {
                    SectionLabel(title: sections.title(at: current))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.black.opacity(0.4), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.isPlaying)
        .task(id: viewModel.script?.text) { sections = viewModel.makeSections() }
        .allowsHitTesting(false)
    }
}
