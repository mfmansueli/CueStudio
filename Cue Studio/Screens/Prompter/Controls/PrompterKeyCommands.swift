//
//  PrompterKeyCommands.swift
//  Cue Studio
//

import SwiftUI

/// A hardware keyboard, a Bluetooth foot pedal or a presentation clicker drives the text, like the remote (`RemoteCommand`): pedals and
/// clickers send these keys. Space plays or pauses, ↓ / Page Down go three lines forward, ↑ / Page Up three back, → / ← change the speed, Home
/// goes back to the top. Recording stays on the red button, as with the remote. Invisible buttons: their shortcuts work without focus, and
/// ⌘ held on an iPad lists them.
struct PrompterKeyCommands: View {
    let perform: (RemoteCommand) -> Void

    private static let keys: [(KeyEquivalent, RemoteCommand)] = [
        (.space, .togglePlay),
        (.downArrow, .forward), (.pageDown, .forward),
        (.upArrow, .backward), (.pageUp, .backward),
        (.rightArrow, .faster), (.leftArrow, .slower),
        (.home, .restart),
    ]

    var body: some View {
        ZStack {
            ForEach(Self.keys.indices, id: \.self) { index in
                let (key, command) = Self.keys[index]
                Button(command.label) { perform(command) }
                    .keyboardShortcut(key, modifiers: [])
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
