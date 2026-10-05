//
//  ActivityView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The system share sheet, for items that can't go through `ShareLink`: files that only exist after
/// an async export, or text shared from a confirmation dialog. `onFinish` hears how it ended (`ActivityResult`), once,
/// whether the sheet closed itself or was dismissed.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: (ActivityResult) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let onFinish = onFinish
        controller.completionWithItemsHandler = { activityType, completed, _, error in
            onFinish(ActivityResult(activityType: activityType?.rawValue, completed: completed, error: error))
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
