import Foundation
import SwiftData

@Model
final class Outfit {
    var id: UUID
    var name: String
    var createdAt: Date
    var slotsData: Data?
    var canvasData: Data?
    var canvasWidth: Double = 0
    var canvasHeight: Double = 0

    var slots: [OutfitSlot] {
        get {
            guard let data = slotsData else { return [] }
            return (try? JSONDecoder().decode([OutfitSlot].self, from: data)) ?? []
        }
        set {
            slotsData = try? JSONEncoder().encode(newValue)
        }
    }

    var canvasItems: [CanvasPlacement] {
        get {
            guard let data = canvasData else { return [] }
            return (try? JSONDecoder().decode([CanvasPlacement].self, from: data)) ?? []
        }
        set {
            canvasData = try? JSONEncoder().encode(newValue)
        }
    }

    var allClothingItemIds: [UUID] {
        let slotIds = slots.compactMap(\.clothingItemId)
        let canvasIds = canvasItems.map(\.clothingItemId)
        return Array(Set(slotIds + canvasIds))
    }

    init(
        name: String,
        slots: [OutfitSlot] = [],
        canvasItems: [CanvasPlacement] = [],
        canvasSize: CGSize = .zero
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.canvasWidth = canvasSize.width
        self.canvasHeight = canvasSize.height
        self.slotsData = try? JSONEncoder().encode(slots)
        self.canvasData = try? JSONEncoder().encode(canvasItems)
    }
}
