import Foundation
import SwiftData

@Model
final class ClothingItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var tags: [String]
    var dominantColorHex: String
    var originalImagePath: String
    var cutoutImagePath: String
    var createdAt: Date

    @Transient
    var category: ClothingCategory {
        get { ClothingCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        name: String,
        category: ClothingCategory,
        tags: [String] = [],
        dominantColorHex: String = "",
        originalImagePath: String,
        cutoutImagePath: String
    ) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.tags = tags
        self.dominantColorHex = dominantColorHex
        self.originalImagePath = originalImagePath
        self.cutoutImagePath = cutoutImagePath
        self.createdAt = Date()
    }
}
