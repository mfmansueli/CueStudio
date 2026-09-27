//
//  PrompterLaunch.swift
//  Cue Studio
//

import Foundation

/// Opens the prompter full screen. A nil script records freestyle.
struct PrompterLaunch: Identifiable, Hashable {
    let id = UUID()
    var scriptID: UUID?
    var mode: PrompterMode
    /// When set, the prompter opens on this take's review instead of the camera.
    var reviewTakeID: UUID?
}
