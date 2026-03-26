import SwiftUI
import SwiftData

struct OutfitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allClothing: [ClothingItem]
    @Bindable var outfit: Outfit
    @State private var showDeleteConfirm = false
    @State private var showCanvasEditor = false
    @State private var showSlotEditor = false
    @State private var isRenaming = false
    @State private var editName = ""

    private var clothingItems: [ClothingItem] {
        let ids = outfit.allClothingItemIds
        return allClothing.filter { ids.contains($0.id) }
    }

    private var isCanvasOutfit: Bool {
        !outfit.canvasItems.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                actionButtons
                if !outfit.slots.isEmpty {
                    slotsSection
                }
                if !outfit.canvasItems.isEmpty {
                    canvasPreview
                }
                itemsGrid
                dangerZone
            }
            .padding()
        }
        .background(Theme.bg)
        .navigationTitle(outfit.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Outfit?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(outfit)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Outfit", isPresented: $isRenaming) {
            TextField("Name", text: $editName)
            Button("Save") {
                let trimmed = editName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    outfit.name = trimmed
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCanvasEditor) {
            CanvasBuilderView(existingOutfit: outfit)
        }
        .fullScreenCover(isPresented: $showSlotEditor) {
            SlotBuilderView(existingOutfit: outfit)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: -12) {
                ForEach(Array(clothingItems.prefix(4).enumerated()), id: \.element.id) { index, item in
                    if let img = ImageService.shared.loadThumbnail(relativePath: item.cutoutImagePath, maxPixels: 140) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .background(Circle().fill(Color.white))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.bg, lineWidth: 3))
                            .zIndex(Double(4 - index))
                    }
                }
            }

            Text(outfit.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.accent)

            Text("Created \(outfit.createdAt, style: .date)")
                .font(.caption)
                .foregroundStyle(Theme.subtleText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .card()
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                editName = outfit.name
                isRenaming = true
            } label: {
                Label("Rename", systemImage: "pencil")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {
                if isCanvasOutfit {
                    showCanvasEditor = true
                } else {
                    showSlotEditor = true
                }
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var slotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Outfit Slots")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)

            ForEach(outfit.slots.filter({ $0.clothingItemId != nil }), id: \.category) { slot in
                if let itemId = slot.clothingItemId,
                   let item = allClothing.first(where: { $0.id == itemId }) {
                    HStack(spacing: 12) {
                        if let img = ImageService.shared.loadThumbnail(relativePath: item.cutoutImagePath, maxPixels: 88) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.category.displayName)
                                .font(.caption2)
                                .foregroundStyle(Theme.subtleText)
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.accent)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .card()
                }
            }
        }
    }

    private var canvasPreview: some View {
        let origW = outfit.canvasWidth > 0 ? outfit.canvasWidth : 390
        let origH = outfit.canvasHeight > 0 ? outfit.canvasHeight : 600
        let aspect = origW / origH

        return VStack(alignment: .leading, spacing: 10) {
            Text("Canvas Layout")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)

            GeometryReader { geo in
                let previewW = geo.size.width
                let previewH = geo.size.height
                let scaleX = previewW / origW
                let scaleY = previewH / origH
                let scale = min(scaleX, scaleY)

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)

                    ForEach(outfit.canvasItems) { placement in
                        if let item = allClothing.first(where: { $0.id == placement.clothingItemId }),
                           let img = ImageService.shared.loadThumbnail(relativePath: item.cutoutImagePath, maxPixels: 400) {
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
            .aspectRatio(aspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .card()
        }
    }

    private var itemsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(clothingItems.count) Items")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(clothingItems) { item in
                    VStack(spacing: 4) {
                        if let img = ImageService.shared.loadThumbnail(relativePath: item.cutoutImagePath, maxPixels: 120) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                        }
                        Text(item.name)
                            .font(.caption2)
                            .foregroundStyle(Theme.accentSoft)
                            .lineLimit(1)
                    }
                    .padding(6)
                    .card()
                }
            }
        }
    }

    private var dangerZone: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete Outfit", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.destructive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.destructive.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
