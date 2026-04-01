import SwiftUI
import SwiftData

struct CanvasBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allClothing: [ClothingItem]

    var existingOutfit: Outfit?

    @State private var outfitName = ""
    @State private var placements: [CanvasPlacement] = []
    @State private var selectedId: UUID?
    @State private var showPicker = false

    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var dragOffset: CGSize = .zero
    @State private var activeGestureId: UUID?
    @State private var baseScale: CGFloat = 1.0
    @State private var baseRotation: CGFloat = 0.0
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvas
                toolbar
            }
            .background(Theme.bg)
            .navigationTitle(existingOutfit != nil ? "Edit Outfit" : "Creative Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.subtleText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(!placements.isEmpty ? Theme.accent : Theme.subtleText)
                        .disabled(placements.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                CanvasItemPicker(items: allClothing) { itemId in
                    addItem(itemId)
                    showPicker = false
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let outfit = existingOutfit, outfitName.isEmpty, placements.isEmpty else { return }
        outfitName = outfit.name
        placements = outfit.canvasItems
        tags = outfit.tags
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                gridBackground(in: geo.size)

                ForEach(placements) { placement in
                    canvasSticker(placement: placement, canvasSize: geo.size)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedId = nil }
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
        }
    }

    private func gridBackground(in size: CGSize) -> some View {
        Canvas { context, cs in
            let step: CGFloat = 24
            for x in stride(from: 0, through: cs.width, by: step) {
                for y in stride(from: 0, through: cs.height, by: step) {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(Theme.border)
                    )
                }
            }
        }
    }

    private func placementIndex(for id: UUID) -> Int? {
        placements.firstIndex(where: { $0.id == id })
    }

    private func canvasSticker(placement: CanvasPlacement, canvasSize: CGSize) -> some View {
        let clothing = allClothing.first(where: { $0.id == placement.clothingItemId })
        let isSelected = selectedId == placement.id
        let isDragging = activeGestureId == placement.id

        let effectiveX = isDragging ? placement.x + dragOffset.width : placement.x
        let effectiveY = isDragging ? placement.y + dragOffset.height : placement.y

        return Group {
            if let clothing, let img = ImageService.shared.loadImage(relativePath: clothing.cutoutImagePath) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120 * placement.scale, height: 120 * placement.scale)
                    .rotationEffect(.radians(placement.rotation))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Theme.accent, lineWidth: 2, antialiased: true)
                        }
                    }
                    .position(x: effectiveX, y: effectiveY)
                    .zIndex(Double(placement.zIndex))
                    .onTapGesture { selectedId = placement.id }
                    .gesture(dragGesture(for: placement.id, canvasSize: canvasSize))
                    .gesture(magnifyGesture(for: placement.id))
                    .gesture(rotateGesture(for: placement.id))
            }
        }
    }

    private func dragGesture(for id: UUID, canvasSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                activeGestureId = id
                selectedId = id
                dragOffset = value.translation
            }
            .onEnded { value in
                if let idx = placementIndex(for: id) {
                    placements[idx].x = min(max(placements[idx].x + value.translation.width, 0), canvasSize.width)
                    placements[idx].y = min(max(placements[idx].y + value.translation.height, 0), canvasSize.height)
                }
                dragOffset = .zero
                activeGestureId = nil
            }
    }

    private func magnifyGesture(for id: UUID) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if activeGestureId != id {
                    if let idx = placementIndex(for: id) {
                        baseScale = placements[idx].scale
                    }
                    activeGestureId = id
                    selectedId = id
                }
                if let idx = placementIndex(for: id) {
                    placements[idx].scale = min(max(baseScale * value.magnification, 0.3), 3.0)
                }
            }
            .onEnded { _ in
                activeGestureId = nil
            }
    }

    private func rotateGesture(for id: UUID) -> some Gesture {
        RotateGesture()
            .onChanged { value in
                if activeGestureId != id {
                    if let idx = placementIndex(for: id) {
                        baseRotation = placements[idx].rotation
                    }
                    activeGestureId = id
                    selectedId = id
                }
                if let idx = placementIndex(for: id) {
                    placements[idx].rotation = baseRotation + value.rotation.radians
                }
            }
            .onEnded { _ in
                activeGestureId = nil
            }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button { showPicker = true } label: {
                    Label("Add Item", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                }

                Spacer()

                Button { bringToFront() } label: {
                    Image(systemName: "square.3.layers.3d.top.filled")
                        .font(.title3)
                }
                .opacity(selectedId != nil ? 1 : 0)
                .disabled(selectedId == nil)

                Button { removeSelected() } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(Theme.destructive)
                }
                .opacity(selectedId != nil ? 1 : 0)
                .disabled(selectedId == nil)

                TextField("Name", text: $outfitName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
            }

            tagRow
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.cardBg)
        .overlay(alignment: .top) {
            Divider()
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var tagRow: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag).font(.caption2.weight(.medium))
                            Button { tags.removeAll { $0 == tag } } label: {
                                Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.tagColor(for: tag), in: Capsule())
                    }
                }
            }

            TextField("Tag...", text: $tagInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
                .onSubmit { addTag() }

            Button("Add") { addTag() }
                .font(.caption.weight(.semibold))
                .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addTag() {
        let cleaned = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !cleaned.isEmpty, !tags.contains(cleaned) else { return }
        tags.append(cleaned)
        tagInput = ""
    }

    // MARK: - Actions

    private func addItem(_ clothingId: UUID) {
        let placement = CanvasPlacement(
            clothingItemId: clothingId,
            x: canvasSize.width > 0 ? canvasSize.width / 2 : 180,
            y: canvasSize.height > 0 ? canvasSize.height / 2 : 300,
            scale: 1.0,
            rotation: 0,
            zIndex: placements.count
        )
        placements.append(placement)
    }

    private func bringToFront() {
        guard let idx = placements.firstIndex(where: { $0.id == selectedId }) else { return }
        let maxZ = (placements.map(\.zIndex).max() ?? 0) + 1
        placements[idx].zIndex = maxZ
    }

    private func removeSelected() {
        placements.removeAll { $0.id == selectedId }
        selectedId = nil
    }

    private func save() {
        let name = outfitName.trimmingCharacters(in: .whitespaces)
        let finalName = name.isEmpty ? "Outfit" : name

        if let existing = existingOutfit {
            existing.name = finalName
            existing.canvasItems = placements
            existing.canvasWidth = canvasSize.width
            existing.canvasHeight = canvasSize.height
            existing.tags = tags
        } else {
            let outfit = Outfit(
                name: finalName,
                canvasItems: placements,
                canvasSize: canvasSize
            )
            outfit.tags = tags
            modelContext.insert(outfit)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Canvas Item Picker

struct CanvasItemPicker: View {
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
                        Image(systemName: "tshirt")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.subtleText.opacity(0.5))
                        Text("Add items to your wardrobe first")
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
            .navigationTitle("Add to Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.subtleText)
                }
            }
        }
    }
}
