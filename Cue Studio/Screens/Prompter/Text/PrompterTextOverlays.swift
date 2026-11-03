//
//  PrompterTextOverlays.swift
//  Cue Studio
//

import SwiftUI

/// What sits on the text window besides the words: the section rail on its right edge. That the text follows the voice is said by the
/// controls (`VoiceIndicator`), never over the words (owner, 02/11/2026: the violet chip on the text was hard to read).
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
        }
        .task(id: viewModel.script?.text) { sections = viewModel.makeSections() }
        .allowsHitTesting(false)
    }
}
