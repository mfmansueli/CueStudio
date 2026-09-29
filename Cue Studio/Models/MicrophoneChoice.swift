//
//  MicrophoneChoice.swift
//  Cue Studio
//

import Foundation

/// The microphone a take should record from. The name is kept with the input's ID so Cue can say
/// which mic is missing when it isn't connected ("AirPods Pro unavailable").
nonisolated enum MicrophoneChoice: Hashable, Sendable {
    /// The system's pick: the mic connected last, or the iPhone's.
    case automatic
    case input(id: String, name: String)

    /// From the stored settings: no ID means Automatic.
    init(id: String?, name: String?) {
        if let id {
            self = .input(id: id, name: name ?? String(localized: "Microphone"))
        } else {
            self = .automatic
        }
    }

    var id: String? {
        switch self {
        case .automatic: nil
        case .input(let id, _): id
        }
    }

    var name: String? {
        switch self {
        case .automatic: nil
        case .input(_, let name): name
        }
    }

    /// "Automatic", "AirPods Pro".
    var label: String { name ?? String(localized: "Automatic") }
}
