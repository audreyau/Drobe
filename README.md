# Drobe

An iOS outfit planner app that lets you photograph your clothes, automatically remove backgrounds to create stickers, and plan outfits visually.

## Features

- **Wardrobe Management** -- Import photos from your camera or photo library. Backgrounds are automatically removed using Apple's Vision framework to create clean cutouts.
- **Rotation Controls** -- Fix the orientation of cutouts before saving.
- **Dominant Color Detection** -- Each item's primary color is automatically detected and displayed.
- **Tags & Categories** -- Organize items by category (top, bottom, outerwear, shoes, accessory) and custom tags (casual, formal, summer, etc.).
- **Slot-Based Outfits** -- Quickly assemble outfits by picking one item per clothing category.
- **Freeform Canvas Outfits** -- Drag, resize, rotate, and layer clothing stickers on a creative canvas for full control.
- **Edit & Rename** -- Modify saved outfits anytime.
- **Memory Efficient** -- Images are cached with two-tier thumbnailing (ImageIO downsampling) to keep memory usage low.


## Tech Stack

- **SwiftUI** -- All UI
- **SwiftData** -- Local data persistence
- **Vision** (`VNGenerateForegroundInstanceMaskRequest`) -- Background removal
- **Core Image** (`CIAreaAverage`) -- Dominant color detection
- **ImageIO** (`CGImageSourceCreateThumbnailAtIndex`) -- Memory-efficient image thumbnailing

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Project Structure

```
FitCheck/
├── FitCheckApp.swift          # App entry point, SwiftData container setup
├── Theme.swift                # Colors, card modifier, styling constants
├── Models/
│   ├── ClothingCategory.swift # Enum: top, bottom, outerwear, shoes, accessory, other
│   ├── ClothingItem.swift     # SwiftData model for a wardrobe item
│   ├── Outfit.swift           # SwiftData model for a saved outfit
│   └── CanvasPlacement.swift  # Structs for outfit slot/canvas position data
├── Services/
│   ├── ImageService.swift     # Save/load/delete images with NSCache + ImageIO thumbnails
│   ├── BackgroundRemover.swift# Vision framework background removal
│   └── ColorDetector.swift    # Core Image dominant color extraction
├── Views/
│   ├── MainTabView.swift      # Tab bar (Wardrobe / Outfits)
│   ├── FlowLayout.swift       # Custom wrapping layout for tags
│   ├── Wardrobe/
│   │   ├── WardrobeView.swift       # Grid of clothing items with filters
│   │   ├── AddClothingSheet.swift   # Photo import, BG removal, rotation, save
│   │   └── ClothingDetailView.swift # Item detail, edit, delete
│   └── Outfits/
│       ├── OutfitsView.swift        # Grid of saved outfits
│       ├── SlotBuilderView.swift    # Category-based outfit builder
│       ├── CanvasBuilderView.swift  # Freeform drag/rotate/scale builder
│       └── OutfitDetailView.swift   # Outfit detail, rename, edit, delete
└── Resources/
    └── Assets.xcassets        # App icon
```

## Getting Started

1. Clone the repo
2. Open `FitCheck.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run on a device or simulator (iOS 17+)

> **Note:** Background removal works best on a real device. The Vision API may produce lower quality results or fail on the simulator.

## License

This project is for personal use.
