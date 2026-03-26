import SwiftUI
import SwiftData

struct SlotBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allClothing: [ClothingItem]

    var existingOutfit: Outfit?

    @State private var outfitName = ""
    @State private var slots: [OutfitSlot] = ClothingCategory.allCases.map { OutfitSlot(category: $0, clothingItemId: nil) }
    @State private var pickingSlotIndex: Int?

    private var filledSlots: Int {
        slots.filter { $0.clothingItemId != nil }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    nameField
                    silhouette
                    slotList
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle(existingOutfit != nil ? "Edit Outfit" : "Quick Build")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadExisting() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.subtleText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(filledSlots > 0 ? Theme.accent : Theme.subtleText)
                        .disabled(filledSlots == 0)
                }
            }
            .sheet(item: $pickingSlotIndex) { index in
                SlotPickerSheet(
                    category: slots[index].category,
                    items: allClothing.filter { $0.category == slots[index].category },
                    onSelect: { itemId in
                        slots[index].clothingItemId = itemId
                        pickingSlotIndex = nil
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var nameField: some View {
        TextField("Outfit name", text: $outfitName)
            .textFieldStyle(.roundedBorder)
    }

    private var silhouette: some View {
        VStack(spacing: 4) {
            slotPreview(.accessory, label: "Acc")
            slotPreview(.top, label: "Top")
            slotPreview(.outerwear, label: "Layer")
            slotPreview(.bottom, label: "Bottom")
            slotPreview(.shoes, label: "Shoes")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Theme.shadow, radius: 8, x: 0, y: 3)
        )
    }

    private func slotPreview(_ category: ClothingCategory, label: String) -> some View {
        let slotIdx = slots.firstIndex(where: { $0.category == category })
        let itemId = slotIdx.flatMap { slots[$0].clothingItemId }
        let clothing = itemId.flatMap { id in allClothing.first(where: { $0.id == id }) }

        return Button {
            if let idx = slotIdx { pickingSlotIndex = idx }
        } label: {
            HStack(spacing: 12) {
                if let clothing,
                   let img = ImageService.shared.loadThumbnail(relativePath: clothing.cutoutImagePath, maxPixels: 100) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundStyle(Theme.border)
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.caption)
                                .foregroundStyle(Theme.subtleText)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(clothing?.name ?? "Tap to pick")
                        .font(.caption2)
                        .foregroundStyle(clothing != nil ? Theme.accentSoft : Theme.subtleText)
                }

                Spacer()

                if clothing != nil {
                    Button {
                        if let idx = slotIdx { slots[idx].clothingItemId = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.subtleText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var slotList: some View {
        EmptyView()
    }

    private func loadExisting() {
        guard let outfit = existingOutfit, outfitName.isEmpty else { return }
        outfitName = outfit.name
        let saved = outfit.slots
        if !saved.isEmpty {
            for savedSlot in saved {
                if let idx = slots.firstIndex(where: { $0.category == savedSlot.category }) {
                    slots[idx].clothingItemId = savedSlot.clothingItemId
                }
            }
        }
    }

    private func save() {
        let name = outfitName.trimmingCharacters(in: .whitespaces)
        let finalName = name.isEmpty ? "Outfit" : name

        if let existing = existingOutfit {
            existing.name = finalName
            existing.slots = slots
        } else {
            let outfit = Outfit(name: finalName, slots: slots)
            modelContext.insert(outfit)
        }
        try? modelContext.save()
        dismiss()
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Slot Picker

struct SlotPickerSheet: View {
    let category: ClothingCategory
    let items: [ClothingItem]
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: category.iconName)
                            .font(.largeTitle)
                            .foregroundStyle(Theme.subtleText.opacity(0.5))
                        Text("No \(category.displayName.lowercased()) in your wardrobe")
                            .font(.subheadline)
                            .foregroundStyle(Theme.subtleText)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { item in
                            Button { onSelect(item.id) } label: {
                                VStack(spacing: 4) {
                                    if let img = ImageService.shared.loadThumbnail(relativePath: item.cutoutImagePath, maxPixels: 160) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 80)
                                    }
                                    Text(item.name)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.accent)
                                        .lineLimit(1)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .card()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .background(Theme.bg)
            .navigationTitle("Pick \(category.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.subtleText)
                }
            }
        }
    }
}
