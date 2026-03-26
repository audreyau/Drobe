import SwiftUI

struct CropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var cropRect: CGRect = .zero
    @State private var imageFrame: CGRect = .zero
    @State private var dragEdge: Edge?
    @State private var dragStart: CGPoint = .zero
    @State private var startRect: CGRect = .zero

    enum Edge {
        case topLeft, topRight, bottomLeft, bottomRight, body
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .background(GeometryReader { imgGeo in
                            Color.clear.onAppear {
                                imageFrame = imgGeo.frame(in: .named("crop"))
                                resetCrop()
                            }
                            .onChange(of: imgGeo.size) { _, _ in
                                imageFrame = imgGeo.frame(in: .named("crop"))
                                resetCrop()
                            }
                        })

                    cropOverlay
                }
                .coordinateSpace(name: "crop")
            }
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { applyCrop() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Overlay

    @ViewBuilder
    private var cropOverlay: some View {
        if cropRect != .zero {
            // Dimmed area outside crop
            Path { path in
                path.addRect(CGRect(x: 0, y: 0, width: 10000, height: 10000))
                path.addRect(cropRect)
            }
            .fill(.black.opacity(0.5), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            // Border
            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .allowsHitTesting(false)

            // Grid lines (rule of thirds)
            Path { path in
                let thirdW = cropRect.width / 3
                let thirdH = cropRect.height / 3
                for i in 1...2 {
                    let x = cropRect.minX + thirdW * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: cropRect.minY))
                    path.addLine(to: CGPoint(x: x, y: cropRect.maxY))
                    let y = cropRect.minY + thirdH * CGFloat(i)
                    path.move(to: CGPoint(x: cropRect.minX, y: y))
                    path.addLine(to: CGPoint(x: cropRect.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            .allowsHitTesting(false)

            // Corner handles
            cornerHandle(at: CGPoint(x: cropRect.minX, y: cropRect.minY), edge: .topLeft)
            cornerHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.minY), edge: .topRight)
            cornerHandle(at: CGPoint(x: cropRect.minX, y: cropRect.maxY), edge: .bottomLeft)
            cornerHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.maxY), edge: .bottomRight)

            // Drag body
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: max(cropRect.width - 60, 10), height: max(cropRect.height - 60, 10))
                .position(x: cropRect.midX, y: cropRect.midY)
                .gesture(bodyDragGesture)
        }
    }

    private func cornerHandle(at point: CGPoint, edge: Edge) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.3), radius: 2)
            .position(point)
            .gesture(
                DragGesture(coordinateSpace: .named("crop"))
                    .onChanged { value in
                        if dragEdge == nil {
                            dragEdge = edge
                            startRect = cropRect
                            dragStart = value.startLocation
                        }
                        updateCrop(edge: edge, location: value.location)
                    }
                    .onEnded { _ in
                        dragEdge = nil
                    }
            )
    }

    private var bodyDragGesture: some Gesture {
        DragGesture(coordinateSpace: .named("crop"))
            .onChanged { value in
                if dragEdge == nil {
                    dragEdge = .body
                    startRect = cropRect
                }
                let dx = value.translation.width
                let dy = value.translation.height

                var newX = startRect.origin.x + dx
                var newY = startRect.origin.y + dy

                newX = max(imageFrame.minX, min(newX, imageFrame.maxX - cropRect.width))
                newY = max(imageFrame.minY, min(newY, imageFrame.maxY - cropRect.height))

                cropRect.origin = CGPoint(x: newX, y: newY)
            }
            .onEnded { _ in
                dragEdge = nil
            }
    }

    // MARK: - Crop Logic

    private func updateCrop(edge: Edge, location: CGPoint) {
        let minSize: CGFloat = 40
        var r = startRect

        switch edge {
        case .topLeft:
            r.origin.x = min(location.x, r.maxX - minSize)
            r.origin.y = min(location.y, r.maxY - minSize)
            r.size.width = startRect.maxX - r.origin.x
            r.size.height = startRect.maxY - r.origin.y
        case .topRight:
            r.size.width = max(location.x - r.origin.x, minSize)
            r.origin.y = min(location.y, r.maxY - minSize)
            r.size.height = startRect.maxY - r.origin.y
        case .bottomLeft:
            r.origin.x = min(location.x, r.maxX - minSize)
            r.size.width = startRect.maxX - r.origin.x
            r.size.height = max(location.y - r.origin.y, minSize)
        case .bottomRight:
            r.size.width = max(location.x - r.origin.x, minSize)
            r.size.height = max(location.y - r.origin.y, minSize)
        case .body:
            break
        }

        // Clamp to image bounds
        r.origin.x = max(r.origin.x, imageFrame.minX)
        r.origin.y = max(r.origin.y, imageFrame.minY)
        if r.maxX > imageFrame.maxX { r.size.width = imageFrame.maxX - r.origin.x }
        if r.maxY > imageFrame.maxY { r.size.height = imageFrame.maxY - r.origin.y }

        cropRect = r
    }

    private func resetCrop() {
        let inset: CGFloat = 16
        cropRect = imageFrame.insetBy(dx: inset, dy: inset)
    }

    private func applyCrop() {
        guard imageFrame.width > 0, imageFrame.height > 0 else {
            dismiss()
            return
        }

        let scaleX = image.size.width / imageFrame.width
        let scaleY = image.size.height / imageFrame.height

        let pixelRect = CGRect(
            x: (cropRect.minX - imageFrame.minX) * scaleX,
            y: (cropRect.minY - imageFrame.minY) * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        guard let cgImage = image.cgImage?.cropping(to: pixelRect) else {
            dismiss()
            return
        }

        let cropped = UIImage(cgImage: cgImage)
        onCrop(cropped)
        dismiss()
    }
}
