//
//  MicrophoneListing.swift
//  Cue Studio
//

import Foundation

/// The microphones connected now, for Creator Setup's picker and for noticing that the preferred
/// one isn't there when a take starts. Tests use a fake.
protocol MicrophoneListing: AnyObject {
    var inputs: [MicrophoneOption] { get }
    /// The input the audio comes from (or will, once the session reports it).
    var inputInUse: MicrophoneOption? { get }
    func refreshInputs()
}
