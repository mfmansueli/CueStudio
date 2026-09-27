//
//  ActivityView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The system share sheet, for items that can't go through `ShareLink`: files that only exist after
/// an async export, or text shared from a confirmation dialog.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
