//
//  InteractivePopEnabler.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// A screen with no navigation bar (the board's "Your universe" has no back button) still goes back with a swipe from the edge: hiding the bar turns the
/// gesture off, and this turns it on again.
struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
