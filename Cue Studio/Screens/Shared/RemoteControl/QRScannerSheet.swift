//
//  QRScannerSheet.swift
//  Cue Studio
//

import SwiftUI
import VisionKit

/// "Scan the code": the camera reads the QR code on the teleprompter. Where scanning isn't available (the Simulator, no camera
/// access) it says so and points to the code in letters.
struct QRScannerSheet: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
                    QRScannerView(onScan: onScan)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView(
                        "Can't scan here", systemImage: "qrcode.viewfinder",
                        description: Text("Scan the code with the Camera app, or enter the letters under it.")
                    )
                }
            }
            .navigationTitle("Scan the code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
