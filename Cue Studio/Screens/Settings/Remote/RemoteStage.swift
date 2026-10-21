//
//  RemoteStage.swift
//  Cue Studio
//

import Foundation

/// What Settings › Remote's scene shows (`RemoteHero`): the two devices apart (no remote, or this iPhone looking for a teleprompter),
/// the teleprompter showing its code while it waits for the other device, or the two linked.
enum RemoteStage: Equatable {
    case apart
    case pairing
    case linked

    init(role: RemoteControlService.Role?, state: RemoteConnectionState) {
        switch (role, state) {
        case (_, .connected): self = .linked
        case (.teleprompter?, .waiting): self = .pairing
        default: self = .apart
        }
    }
}
