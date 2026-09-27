//
//  DocumentScannerView.swift
//  Cue Studio
//

import SwiftUI
import VisionKit

/// The system document scanner, for photographing a printed brief or script. Hands back one image
/// per scanned page.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onScanned: ([CGImage]) -> Void
    let onCancel: () -> Void

    /// False in the Simulator and on devices without a suitable camera.
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onScanned: ([CGImage]) -> Void
        private let onCancel: () -> Void

        init(onScanned: @escaping ([CGImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScanned = onScanned
            self.onCancel = onCancel
        }

        nonisolated func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage }
            MainActor.assumeIsolated { onScanned(images) }
        }

        nonisolated func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            MainActor.assumeIsolated { onCancel() }
        }

        nonisolated func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            MainActor.assumeIsolated { onCancel() }
        }
    }
}
