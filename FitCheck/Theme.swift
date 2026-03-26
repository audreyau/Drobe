import SwiftUI

enum Theme {
    static let bg = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let cardBg = Color.white
    static let accent = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let accentSoft = Color(red: 0.35, green: 0.35, blue: 0.38)
    static let subtleText = Color(red: 0.55, green: 0.55, blue: 0.57)
    static let border = Color(red: 0.90, green: 0.90, blue: 0.89)
    static let destructive = Color(red: 0.85, green: 0.28, blue: 0.25)
    static let shadow = Color.black.opacity(0.06)

    static let tagCasual = Color(red: 0.55, green: 0.75, blue: 0.68)
    static let tagWork = Color(red: 0.45, green: 0.55, blue: 0.78)
    static let tagFormal = Color(red: 0.60, green: 0.48, blue: 0.72)
    static let tagSummer = Color(red: 0.92, green: 0.72, blue: 0.38)
    static let tagWinter = Color(red: 0.52, green: 0.68, blue: 0.82)

    static func tagColor(for tag: String) -> Color {
        switch tag.lowercased() {
        case "casual": tagCasual
        case "work": tagWork
        case "formal": tagFormal
        case "summer": tagSummer
        case "winter": tagWinter
        default: accentSoft
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Theme.shadow, radius: 6, x: 0, y: 2)
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
