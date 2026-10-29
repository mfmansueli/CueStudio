//
//  AnyTransition+UltraFold.swift
//  Cue Studio
//

import SwiftUI

extension AnyTransition {
    /// An Ultra AI invitation folding away (closed, or taken; `UltraMotion.fold`): it fades and sinks a little towards its top.
    static var ultraFold: AnyTransition { .opacity.combined(with: .scale(scale: 0.94, anchor: .top)) }
}
