import SwiftUI

struct MainTabView: View {
    init() {
        configureAppearance()
    }

    var body: some View {
        TabView {
            WardrobeView()
                .tabItem {
                    Label("Wardrobe", systemImage: "tshirt.fill")
                }

            OutfitsView()
                .tabItem {
                    Label("Outfits", systemImage: "rectangle.grid.2x2.fill")
                }
        }
        .tint(Theme.accent)
    }

    private func configureAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor.white
        tabAppearance.shadowColor = UIColor.black.withAlphaComponent(0.05)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
