//
//  ActivityView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The system share sheet, for files that only exist after an async export.
struct ActivityView: UIViewControllerRepresentable {
    let items: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
