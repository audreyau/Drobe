import Foundation

struct OutfitSlot: Codable, Hashable {
    var category: ClothingCategory
    var clothingItemId: UUID?
}

struct CanvasPlacement: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var clothingItemId: UUID
    var x: Double
    var y: Double
    var scale: Double = 1.0
    var rotation: Double = 0.0
    var zIndex: Int = 0
}
