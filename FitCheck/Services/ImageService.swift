import UIKit

final class ImageService {
    static let shared = ImageService()
    private let fileManager = FileManager.default

    private let fullCache = NSCache<NSString, UIImage>()
    private let thumbCache = NSCache<NSString, UIImage>()

    private init() {
        fullCache.totalCostLimit = 60 * 1024 * 1024
        fullCache.countLimit = 20
        thumbCache.totalCostLimit = 20 * 1024 * 1024
        thumbCache.countLimit = 100
    }

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func ensureImagesDir() {
        let dir = documentsURL.appendingPathComponent("ClothingImages", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Save

    func saveImage(_ image: UIImage, prefix: String = "img") -> String? {
        ensureImagesDir()

        let maxDimension: CGFloat = 2048
        let scaledImage: UIImage
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            scaledImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            scaledImage = image
        }

        let data: Data?
        let ext: String
        if let pngData = scaledImage.pngData() {
            data = pngData
            ext = "png"
        } else if let jpgData = scaledImage.jpegData(compressionQuality: 0.9) {
            data = jpgData
            ext = "jpg"
        } else {
            return nil
        }

        guard let imageData = data else { return nil }

        let filename = "\(prefix)_\(UUID().uuidString).\(ext)"
        let relativePath = "ClothingImages/\(filename)"
        let fullURL = documentsURL.appendingPathComponent(relativePath)

        do {
            try imageData.write(to: fullURL, options: .atomic)
            return relativePath
        } catch {
            return nil
        }
    }

    // MARK: - Load (full resolution, cached)

    func loadImage(relativePath: String) -> UIImage? {
        guard !relativePath.isEmpty else { return nil }
        let key = relativePath as NSString

        if let cached = fullCache.object(forKey: key) {
            return cached
        }

        let url = documentsURL.appendingPathComponent(relativePath)
        guard let image = downsampledImage(at: url, maxPixels: 2048) else { return nil }
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        fullCache.setObject(image, forKey: key, cost: cost)
        return image
    }

    // MARK: - Thumbnail (small, cached separately)

    func loadThumbnail(relativePath: String, maxPixels: CGFloat = 200) -> UIImage? {
        guard !relativePath.isEmpty else { return nil }
        let key = "\(relativePath)_\(Int(maxPixels))" as NSString

        if let cached = thumbCache.object(forKey: key) {
            return cached
        }

        let url = documentsURL.appendingPathComponent(relativePath)
        guard let image = downsampledImage(at: url, maxPixels: maxPixels) else { return nil }
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        thumbCache.setObject(image, forKey: key, cost: cost)
        return image
    }

    // MARK: - Delete

    func deleteImage(relativePath: String) {
        guard !relativePath.isEmpty else { return }
        let url = documentsURL.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: url)
        let key = relativePath as NSString
        fullCache.removeObject(forKey: key)
        thumbCache.removeAllObjects()
    }

    // MARK: - ImageIO downsampling (memory-efficient)

    private func downsampledImage(at url: URL, maxPixels: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
