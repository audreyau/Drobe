import Foundation

enum ClothingCategory: String, Codable, CaseIterable, Identifiable {
    case top, bottom, outerwear, shoes, accessory, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .outerwear: "Outerwear"
        case .shoes: "Shoes"
        case .accessory: "Accessory"
        case .other: "Other"
        }
    }

    var iconName: String {
        switch self {
        case .top: "tshirt"
        case .bottom: "figure.walk"
        case .outerwear: "cloud.sun"
        case .shoes: "shoe"
        case .accessory: "eyeglasses"
        case .other: "square.grid.2x2"
        }
    }
}
