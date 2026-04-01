import SwiftUI
import SwiftData
import PhotosUI

struct WearPhotoGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var outfit: Outfit

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isProcessing = false
    @State private var selectedPhoto: WearPhoto?
    @State private var showDeleteConfirm = false
    @State private var photoToDelete: WearPhoto?

    private var sortedPhotos: [WearPhoto] {
        outfit.wearPhotos.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    addPhotoSection
                    if sortedPhotos.isEmpty {
                        emptyState
                    } else {
                        photoGrid
                    }
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle("Wear Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task { await loadFromPicker(newItem) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    saveWearPhoto(image)
                }
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                WearPhotoDetailView(photo: photo, outfit: outfit)
            }
            .alert("Delete Photo?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let photo = photoToDelete {
                        deletePhoto(photo)
                    }
                }
                Button("Cancel", role: .cancel) { photoToDelete = nil }
            } message: {
                Text("This photo will be permanently removed.")
            }
        }
    }

    private var addPhotoSection: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Photo Library", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
            }

            Button {
                showCamera = true
            } label: {
                Label("Camera", systemImage: "camera.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .overlay {
            if isProcessing {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(ProgressView())
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.subtleText.opacity(0.4))

            Text("No wear photos yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.subtleText)

            Text("Add photos to remember when you wore this outfit")
                .font(.caption)
                .foregroundStyle(Theme.subtleText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(sortedPhotos) { photo in
                if let img = ImageService.shared.loadThumbnail(relativePath: photo.imagePath, maxPixels: 400) {
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(minHeight: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(photo.date, style: .date)
                                .font(.caption2.weight(.semibold))
                            if !photo.caption.isEmpty {
                                Text(photo.caption)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(
                            LinearGradient(
                                colors: [.black.opacity(0.6), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .clipShape(
                                UnevenRoundedRectangle(
                                    bottomLeadingRadius: 12,
                                    bottomTrailingRadius: 12
                                )
                            )
                        )
                    }
                    .card()
                    .onTapGesture {
                        selectedPhoto = photo
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            photoToDelete = photo
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadFromPicker(_ pickerItem: PhotosPickerItem?) async {
        guard let pickerItem else { return }
        await MainActor.run { isProcessing = true }

        if let imageData = try? await pickerItem.loadTransferable(type: Data.self),
           let loaded = UIImage(data: imageData) {
            await MainActor.run {
                saveWearPhoto(loaded)
                isProcessing = false
                selectedPhotoItem = nil
            }
            return
        }

        await MainActor.run {
            isProcessing = false
            selectedPhotoItem = nil
        }
    }

    private func saveWearPhoto(_ image: UIImage) {
        guard let path = ImageService.shared.saveImage(image, prefix: "wear", subdirectory: "OutfitImages") else { return }
        let photo = WearPhoto(imagePath: path, date: Date())
        var photos = outfit.wearPhotos
        photos.append(photo)
        outfit.wearPhotos = photos
        try? modelContext.save()
    }

    private func deletePhoto(_ photo: WearPhoto) {
        ImageService.shared.deleteImage(relativePath: photo.imagePath)
        var photos = outfit.wearPhotos
        photos.removeAll { $0.id == photo.id }
        outfit.wearPhotos = photos
        try? modelContext.save()
        photoToDelete = nil
    }
}

// MARK: - Full-screen photo detail

struct WearPhotoDetailView: View {
    let photo: WearPhoto
    @Bindable var outfit: Outfit
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var caption: String

    init(photo: WearPhoto, outfit: Outfit) {
        self.photo = photo
        self.outfit = outfit
        self._caption = State(initialValue: photo.caption)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if let img = ImageService.shared.loadImage(relativePath: photo.imagePath) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding()
                    }

                    VStack(spacing: 8) {
                        Text(photo.date, style: .date)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))

                        TextField("Add a caption...", text: $caption)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                            .onSubmit { saveCaption() }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveCaption()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func saveCaption() {
        let trimmed = caption.trimmingCharacters(in: .whitespaces)
        guard trimmed != photo.caption else { return }
        var photos = outfit.wearPhotos
        if let idx = photos.firstIndex(where: { $0.id == photo.id }) {
            photos[idx].caption = trimmed
            outfit.wearPhotos = photos
            try? modelContext.save()
        }
    }
}
