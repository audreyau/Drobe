import SwiftUI

struct ClothingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: ClothingItem
    @State private var showDeleteConfirm = false
    @State private var showCrop = false
    @State private var isEditing = false
    @State private var editName = ""
    @State private var editCategory: ClothingCategory = .other
    @State private var editTags: [String] = []
    @State private var tagInput = ""
    @State private var editColor: Color = .gray

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                imageSection

                Button {
                    showCrop = true
                } label: {
                    Label("Crop Image", systemImage: "crop")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                infoSection
                if isEditing {
                    editSection
                }
                dangerZone
            }
            .padding()
        }
        .background(Theme.bg)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        applyEdits()
                    } else {
                        startEditing()
                    }
                    isEditing.toggle()
                }
                .fontWeight(.semibold)
                .foregroundStyle(Theme.accent)
            }
        }
        .alert("Delete Item?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteItem() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this item from your wardrobe.")
        }
        .fullScreenCover(isPresented: $showCrop) {
            if let img = ImageService.shared.loadImage(relativePath: item.cutoutImagePath) {
                CropView(image: img) { cropped in
                    saveCroppedImage(cropped)
                }
            }
        }
    }

    private var imageSection: some View {
        ZStack {
            checkerboard
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if let img = ImageService.shared.loadImage(relativePath: item.cutoutImagePath) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .padding()
            }
        }
        .card()
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let tileSize: CGFloat = 12
            let cols = Int(ceil(size.width / tileSize))
            let rows = Int(ceil(size.height / tileSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(x: CGFloat(col) * tileSize, y: CGFloat(row) * tileSize, width: tileSize, height: tileSize)
                    context.fill(Path(rect), with: .color(isLight ? Color.white : Color(white: 0.93)))
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(item.category.displayName, systemImage: item.category.iconName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                Spacer()
                if !item.dominantColorHex.isEmpty {
                    Circle()
                        .fill(Color(uiColor: ColorDetector.color(from: item.dominantColorHex)))
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
            }

            if !item.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.tagColor(for: tag), in: Capsule())
                    }
                }
            }

            HStack {
                Text("Added")
                    .foregroundStyle(Theme.subtleText)
                Spacer()
                Text(item.createdAt, style: .date)
                    .foregroundStyle(Theme.accent)
            }
            .font(.caption)
        }
        .padding()
        .card()
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Details")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)

            TextField("Name", text: $editName)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $editCategory) {
                ForEach(ClothingCategory.allCases) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Text("Color")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                Spacer()
                ColorPicker("", selection: $editColor, supportsOpacity: false)
                    .labelsHidden()
            }

            FlowLayout(spacing: 6) {
                ForEach(editTags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag).font(.caption2.weight(.medium))
                        Button { editTags.removeAll { $0 == tag } } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.tagColor(for: tag), in: Capsule())
                }
            }

            HStack {
                TextField("Add tag...", text: $tagInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addEditTag() }
                Button("Add") { addEditTag() }
                    .font(.caption.weight(.semibold))
            }
        }
        .padding()
        .card()
    }

    private var dangerZone: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete Item", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.destructive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.destructive.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func startEditing() {
        editName = item.name
        editCategory = item.category
        editTags = item.tags
        if !item.dominantColorHex.isEmpty {
            editColor = Color(uiColor: ColorDetector.color(from: item.dominantColorHex))
        }
    }

    private func applyEdits() {
        item.name = editName.trimmingCharacters(in: .whitespaces)
        item.category = editCategory
        item.tags = editTags
        item.dominantColorHex = hexFromColor(editColor)
        try? modelContext.save()
    }

    private func hexFromColor(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func addEditTag() {
        let cleaned = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !cleaned.isEmpty, !editTags.contains(cleaned) else { return }
        editTags.append(cleaned)
        tagInput = ""
    }

    private func saveCroppedImage(_ cropped: UIImage) {
        let oldPath = item.cutoutImagePath
        if let newPath = ImageService.shared.saveImage(cropped, prefix: "cut") {
            item.cutoutImagePath = newPath
            item.dominantColorHex = ColorDetector.dominantColorHex(from: cropped)
            try? modelContext.save()
            ImageService.shared.deleteImage(relativePath: oldPath)
        }
    }

    private func deleteItem() {
        ImageService.shared.deleteImage(relativePath: item.originalImagePath)
        ImageService.shared.deleteImage(relativePath: item.cutoutImagePath)
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }
}
