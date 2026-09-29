//
//  QRCodeView.swift
//  Cue Studio
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// A QR code for `text`, sharp at any size, on the white quiet zone scanners need.
struct QRCodeView: View {
    private let image: UIImage?

    init(text: String) {
        image = Self.makeImage(for: text)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
    }

    private static func makeImage(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        // Each module becomes a 10 pt block, so scaling it up stays crisp.
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#if DEBUG
#Preview {
    QRCodeView(text: "cuestudio://remote?code=ABC234")
        .frame(width: 200, height: 200)
        .padding()
        .background(Palette.bg)
}
#endif
