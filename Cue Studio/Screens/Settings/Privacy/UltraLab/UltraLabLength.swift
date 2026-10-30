//
//  UltraLabLength.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// The lab's length comparison, one idea and one voice under the three conditions: no target, about 90 seconds as a reference, 60–90 seconds
/// required. What the script page asks is the request's own policy (`UltraLength.init(_:)`); this only overrides it in the lab.
enum UltraLabLength: String, CaseIterable, Identifiable {
    case free
    case reference
    case required

    var id: String { rawValue }

    var length: UltraLength {
        switch self {
        case .free: .free
        case .reference: .reference(90)
        case .required: .required(60...90)
        }
    }

    /// The lab is a Debug tool: its words aren't translated.
    var label: String {
        switch self {
        case .free: "Free"
        case .reference: "About 90 s"
        case .required: "60–90 s"
        }
    }
}
#endif
