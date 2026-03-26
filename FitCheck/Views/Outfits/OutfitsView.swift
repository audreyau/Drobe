import SwiftUI
import SwiftData

struct OutfitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Outfit.createdAt, order: .reverse) private var outfits: [Outfit]
    @Query private var clothing: [ClothingItem]
    @State private var showNewOutfitChoice = false
    @State private var showSlotBuilder = false
    @State private var showCanvasBuilder = false
    @State private var selectedOutfitId: UUID?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if outfits.isEmpty {
                    emptyState
                } else {
                    outfitGrid
                }
            }
            .background(Theme.bg)
            .navigationTitle("Outfits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewOutfitChoice = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .confirmationDialog("New Outfit", isPresented: $showNewOutfitChoice) {
                Button("Quick Build (Slots)") { showSlotBuilder = true }
                Button("Creative (Canvas)") { showCanvasBuilder = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showSlotBuilder) {
                SlotBuilderView()
            }
            .fullScreenCover(isPresented: $showCanvasBuilder) {
                CanvasBuilderView()
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedOutfitId != nil },
                set: { if !$0 { selectedOutfitId = nil } }
            )) {
                if let outfit = outfits.first(where: { $0.id == selectedOutfitId }) {
                    OutfitDetailView(outfit: outfit)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(Theme.subtleText.opacity(0.5))
            Text("No outfits yet")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Text("Create your first outfit from your wardrobe items")
                .font(.subheadline)
                .foregroundStyle(Theme.subtleText)
                .multilineTextAlignment(.center)
            Button {
                showNewOutfitChoice = true
            } label: {
                Label("Create Outfit", systemImage: "plus")
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

    private var outfitGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(outfits) { outfit in
                Button {
                    selectedOutfitId = outfit.id
                } label: {
                    outfitCard(outfit)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private func outfitCard(_ outfit: Outfit) -> some View {
        VStack(spacing: 8) {
            outfitThumbnail(outfit)
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .clipped()

            Text(outfit.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)

            Text(outfit.createdAt, style: .date)
                .font(.caption2)
                .foregroundStyle(Theme.subtleText)
        }
        .padding(10)
        .card()
    }

    @ViewBuilder
    private func outfitThumbnail(_ outfit: Outfit) -> some View {
        let itemIds = outfit.allClothingItemIds
        if itemIds.isEmpty {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.border.opacity(0.5))
                .overlay {
                    Image(systemName: "hanger")
                        .foregroundStyle(Theme.subtleText)
                }
        } else if !outfit.canvasItems.isEmpty {
            canvasThumbnail(outfit)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(itemIds.prefix(3)), id: \.self) { id in
                    if let item = clothing.first(where: { $0.id == id }),
                       let img = ImageService.shared.loadThumbnail(relativePath: item.cutoutImagePath, maxPixels: 160) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    }
                }
            }
            .padding(8)
        }
    }

    private func canvasThumbnail(_ outfit: Outfit) -> some View {
        let origW = outfit.canvasWidth > 0 ? outfit.canvasWidth : 390
        let origH = outfit.canvasHeight > 0 ? outfit.canvasHeight : 600

        return GeometryReader { geo in
            let scaleX = geo.size.width / origW
            let scaleY = geo.size.height / origH
            let scale = min(scaleX, scaleY)

            ZStack {
                ForEach(outfit.canvasItems) { placement in
                    if let item = clothing.first(where: { $0.id == placement.clothingItemId }),
                       let img = ImageService.shared.loadThumbnail(relativePath: item.cutoutImagePath, maxPixels: 120) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120 * placement.scale * scale,
                                   height: 120 * placement.scale * scale)
                            .rotationEffect(.radians(placement.rotation))
                            .position(
                                x: placement.x * scale,
                                y: placement.y * scale
                            )
                    }
                }
            }
        }
    }
}
