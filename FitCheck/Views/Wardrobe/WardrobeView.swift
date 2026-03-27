import SwiftUI
import SwiftData

struct WardrobeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @State private var showAddSheet = false
    @State private var selectedCategory: ClothingCategory?
    @State private var selectedTag: String?
    @State private var selectedItemId: UUID?

    private var filteredItems: [ClothingItem] {
        items.filter { item in
            if let cat = selectedCategory, item.category != cat { return false }
            if let tag = selectedTag, !item.tags.contains(tag) { return false }
            return true
        }
    }

    private var allTags: [String] {
        Array(Set(items.flatMap(\.tags))).sorted()
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Wardrobe")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    if items.isEmpty {
                        emptyState
                    } else {
                        filters
                        itemGrid
                    }
                }
            }
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddClothingSheet()
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedItemId != nil },
                set: { if !$0 { selectedItemId = nil } }
            )) {
                if let item = items.first(where: { $0.id == selectedItemId }) {
                    ClothingDetailView(item: item)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 48))
                .foregroundStyle(Theme.subtleText.opacity(0.5))
            Text("Your wardrobe is empty")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Text("Tap + to photograph or import your first clothing item")
                .font(.subheadline)
                .foregroundStyle(Theme.subtleText)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Label("Add Item", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
            }
        }
        .padding(.top, 100)
        .padding(.horizontal, 40)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", active: selectedCategory == nil && selectedTag == nil) {
                    selectedCategory = nil
                    selectedTag = nil
                }

                ForEach(ClothingCategory.allCases, id: \.self) { cat in
                    filterChip(cat.displayName, active: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                        selectedTag = nil
                    }
                }

                if !allTags.isEmpty {
                    Divider().frame(height: 20)
                    ForEach(allTags, id: \.self) { tag in
                        filterChip(tag, color: Theme.tagColor(for: tag), active: selectedTag == tag) {
                            selectedTag = selectedTag == tag ? nil : tag
                            selectedCategory = nil
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(_ title: String, color: Color = Theme.accent, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(active ? .white : Theme.accentSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? color : Theme.border.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var itemGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredItems) { item in
                Button {
                    selectedItemId = item.id
                } label: {
                    clothingThumbnail(item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    private func clothingThumbnail(_ item: ClothingItem) -> some View {
        VStack(spacing: 6) {
            if let img = ImageService.shared.loadThumbnail(relativePath: item.cutoutImagePath, maxPixels: 200) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.border)
                    .frame(height: 100)
                    .overlay {
                        Image(systemName: "tshirt")
                            .foregroundStyle(Theme.subtleText)
                    }
            }

            Text(item.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .card()
    }
}
