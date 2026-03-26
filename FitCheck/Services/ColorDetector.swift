import UIKit
import CoreImage

enum ColorDetector {
    static func dominantColorHex(from image: UIImage) -> String {
        guard let ciImage = CIImage(image: image) else { return "" }

        let extent = ciImage.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(
                x: extent.origin.x,
                y: extent.origin.y,
                z: extent.size.width,
                w: extent.size.height
            )
        ])

        guard let output = filter?.outputImage else { return "" }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return String(format: "#%02X%02X%02X", bitmap[0], bitmap[1], bitmap[2])
    }

    static func color(from hex: String) -> UIColor {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let val = UInt64(cleaned, radix: 16) else {
            return .gray
        }
        return UIColor(
            red: CGFloat((val >> 16) & 0xFF) / 255,
            green: CGFloat((val >> 8) & 0xFF) / 255,
            blue: CGFloat(val & 0xFF) / 255,
            alpha: 1
        )
    }
}
