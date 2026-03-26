import SwiftUI
import PhotosUI

struct AddClothingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var cutoutImage: UIImage?
    @State private var isProcessing = false

    @State private var name = ""
    @State private var category: ClothingCategory = .top
    @State private var tagInput = ""
    @State private var tags: [String] = []

    @State private var showCamera = false
    @State private var rotationDegrees: Double = 0

    private var canSave: Bool {
        cutoutImage != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    imageSection
                    detailsSection
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle("Add Clothing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.subtleText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Theme.accent : Theme.subtleText)
                        .disabled(!canSave)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task { await loadFromPicker(newItem) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    originalImage = image
                    Task { await processImage(image) }
                }
            }
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        VStack(spacing: 16) {
            if isProcessing {
                ProgressView("Removing background...")
                    .frame(height: 220)
            } else if let cutout = cutoutImage {
                Image(uiImage: cutout)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .rotationEffect(.degrees(rotationDegrees))
                    .animation(.easeInOut(duration: 0.25), value: rotationDegrees)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                            .shadow(color: Theme.shadow, radius: 8, x: 0, y: 3)
                    )
                    .clipped()

                HStack(spacing: 20) {
                    Button {
                        rotationDegrees -= 90
                    } label: {
                        Label("Rotate Left", systemImage: "rotate.left.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.border.opacity(0.6), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        rotationDegrees += 90
                    } label: {
                        Label("Rotate Right", systemImage: "rotate.right.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.border.opacity(0.6), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button("Choose Different Photo") {
                    cutoutImage = nil
                    originalImage = nil
                    selectedPhotoItem = nil
                    rotationDegrees = 0
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.subtleText)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.subtleText.opacity(0.5))

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.accent, in: Capsule())
                        }

                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.border, in: Capsule())
                        }
                    }
                }
                .frame(height: 220)
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Item name (optional)", text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $category) {
                ForEach(ClothingCategory.allCases) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.subtleText)

                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption2.weight(.medium))
                            Button { tags.removeAll { $0 == tag } } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
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
                        .onSubmit { addTag() }
                    Button("Add") { addTag() }
                        .font(.caption.weight(.semibold))
                        .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding()
        .card()
    }

    // MARK: - Helpers

    private func addTag() {
        let cleaned = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !cleaned.isEmpty, !tags.contains(cleaned) else { return }
        tags.append(cleaned)
        tagInput = ""
    }

    private func loadFromPicker(_ pickerItem: PhotosPickerItem?) async {
        guard let pickerItem else { return }
        await MainActor.run { isProcessing = true }

        do {
            if let imageData = try await pickerItem.loadTransferable(type: Data.self),
               let loaded = UIImage(data: imageData) {
                await MainActor.run { originalImage = loaded }
                await processImage(loaded)
                return
            }
        } catch {}

        do {
            if let transferable = try await pickerItem.loadTransferable(type: PhotoTransferable.self) {
                let loaded = transferable.image
                await MainActor.run { originalImage = loaded }
                await processImage(loaded)
                return
            }
        } catch {}

        await MainActor.run { isProcessing = false }
    }

    @MainActor
    private func processImage(_ image: UIImage) async {
        isProcessing = true
        let result = await BackgroundRemover.removeBackground(from: image)
        cutoutImage = result ?? image
        isProcessing = false
    }

    private struct PhotoTransferable: Transferable {
        let image: UIImage

        static var transferRepresentation: some TransferRepresentation {
            DataRepresentation(importedContentType: .image) { data in
                guard let img = UIImage(data: data) else {
                    throw TransferError.importFailed
                }
                return PhotoTransferable(image: img)
            }
        }

        enum TransferError: Error { case importFailed }
    }

    // MARK: - Save

    private func save() {
        guard let original = originalImage, let cutout = cutoutImage else { return }

        let finalCutout = rotateImage(cutout, byDegrees: rotationDegrees)

        let origPath = ImageService.shared.saveImage(original, prefix: "orig")
        let cutPath = ImageService.shared.saveImage(finalCutout, prefix: "cut")

        guard let origPath, let cutPath else { return }

        let colorHex = ColorDetector.dominantColorHex(from: finalCutout)
        let itemName = name.trimmingCharacters(in: .whitespaces)

        let item = ClothingItem(
            name: itemName.isEmpty ? "\(category.displayName) Item" : itemName,
            category: category,
            tags: tags,
            dominantColorHex: colorHex,
            originalImagePath: origPath,
            cutoutImagePath: cutPath
        )

        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }

    private func rotateImage(_ image: UIImage, byDegrees degrees: Double) -> UIImage {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        guard normalized != 0 else { return image }

        let radians = normalized * .pi / 180
        let size = image.size
        let rotatedSize: CGSize

        let absDeg = abs(normalized.truncatingRemainder(dividingBy: 360))
        if absDeg == 90 || absDeg == 270 {
            rotatedSize = CGSize(width: size.height, height: size.width)
        } else {
            let rect = CGRect(origin: .zero, size: size)
                .applying(CGAffineTransform(rotationAngle: radians))
            rotatedSize = CGSize(width: abs(rect.width), height: abs(rect.height))
        }

        let renderer = UIGraphicsImageRenderer(size: rotatedSize)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            ctx.cgContext.rotate(by: radians)
            image.draw(in: CGRect(
                x: -size.width / 2,
                y: -size.height / 2,
                width: size.width,
                height: size.height
            ))
        }
    }
}

// MARK: - Camera

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
