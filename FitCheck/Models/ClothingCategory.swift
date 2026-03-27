import Foundation

enum ClothingCategory: String, Codable, CaseIterable, Identifiable {
    case top, bottom, outerwear, shoes, accessory, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .outerwear: return "Outerwear"
        case .shoes: return "Shoes"
        case .accessory: return "Accessory"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .top: return "tshirt"
        case .bottom: return "figure.walk"
        case .outerwear: return "cloud.sun"
        case .shoes: return "shoe"
        case .accessory: return "eyeglasses"
        case .other: return "square.grid.2x2"
        }
    }
}
