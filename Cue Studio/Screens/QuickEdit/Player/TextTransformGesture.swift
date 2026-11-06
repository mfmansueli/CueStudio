//
//  TextTransformGesture.swift
//  Cue Studio
//

import SwiftUI

/// `TextTransformRecognizer` on a SwiftUI view: `shouldStart` decides from where the fingers are (their middle, in the
/// coordinate space named `space`) and how many there are, `slop` how far they move first; `onChange` hears it begin, move and
/// end, with where they are.
struct TextTransformGesture: UIGestureRecognizerRepresentable {
    let space: String
    let shouldStart: (_ location: CGPoint, _ fingers: Int) -> Bool
    let slop: (_ location: CGPoint, _ fingers: Int) -> CGFloat
    let onChange: (TextTransformRecognizer, _ location: CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> TextTransformRecognizer {
        let recognizer = TextTransformRecognizer()
        updateUIGestureRecognizer(recognizer, context: context)
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: TextTransformRecognizer, context: Context) {
        let converter = context.converter
        let space = space
        let shouldStart = shouldStart
        let slop = slop
        recognizer.shouldStart = { fingers in shouldStart(converter.location(in: .named(space)), fingers) }
        recognizer.slop = { fingers in slop(converter.location(in: .named(space)), fingers) }
    }

    func handleUIGestureRecognizerAction(_ recognizer: TextTransformRecognizer, context: Context) {
        onChange(recognizer, context.converter.location(in: .named(space)))
    }
}
