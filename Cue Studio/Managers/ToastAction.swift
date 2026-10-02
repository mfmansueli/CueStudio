//
//  ToastAction.swift
//  Cue Studio
//

import Foundation

/// The one button a toast can carry ("Undo"): shown beside the message for as long as the toast
/// stays, and the toast goes with a tap on it.
struct ToastAction {
    let title: String
    let perform: @MainActor () -> Void
}
