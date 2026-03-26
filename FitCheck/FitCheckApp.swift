import SwiftUI
import SwiftData

@main
struct FitCheckApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([ClothingItem.self, Outfit.self])
        let config = ModelConfiguration(schema: schema)

        // Try to create container; if schema is incompatible, wipe and recreate
        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            container = c
        } else {
            Self.deleteStore(at: config.url)
            container = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(container)
    }

    private static func deleteStore(at url: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: url)
        let base = url.deletingPathExtension()
        try? fm.removeItem(at: base.appendingPathExtension("store-shm"))
        try? fm.removeItem(at: base.appendingPathExtension("store-wal"))
    }
}
