//
//  CaptionTranslationRunner.swift
//  Cue Studio
//

import SwiftUI
import Translation

/// Runs the captions' translations for the whole editor (picked in Captions or in the Translate
/// sheet): the system's translation task gets a new configuration for each request, so the same
/// pair can be asked again, and asks before downloading a language.
struct CaptionTranslationRunner: ViewModifier {
    let viewModel: QuickEditViewModel

    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                guard let request = viewModel.translationRequest else { return }
                await viewModel.performTranslation(request, with: AppleTranslationSession(session))
            }
            .onChange(of: viewModel.translationRequest) { _, request in
                guard let request else { return }
                configuration = TranslationSession.Configuration(source: request.source, target: request.target.locale.language)
            }
    }
}
