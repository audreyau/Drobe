import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

enum BackgroundRemover {
    static func removeBackground(from image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                    guard let result = request.results?.first else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                    let ciMask = CIImage(cvPixelBuffer: mask)
                    let originalCI = CIImage(cgImage: cgImage)

                    let filter = CIFilter.blendWithMask()
                    filter.inputImage = originalCI
                    filter.maskImage = ciMask
                    filter.backgroundImage = CIImage.empty()

                    let context = CIContext()
                    if let outputCI = filter.outputImage,
                       let outputCG = context.createCGImage(outputCI, from: outputCI.extent) {
                        continuation.resume(returning: UIImage(cgImage: outputCG))
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
