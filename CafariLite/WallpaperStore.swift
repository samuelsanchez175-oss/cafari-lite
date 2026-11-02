import Observation
import UIKit

@Observable
@MainActor
final class WallpaperStore {
    static let shared = WallpaperStore()

    private static let presetKey = "cafari.car.wallpaperPreset"
    private static let cropScaleKey = "cafari.car.wallpaperCropScale"
    private static let cropOffsetXKey = "cafari.car.wallpaperCropOffsetX"
    private static let cropOffsetYKey = "cafari.car.wallpaperCropOffsetY"

    private(set) var image: UIImage
    private(set) var sourceImage: UIImage
    private(set) var isCustom: Bool
    private(set) var selectedPreset: CarWallpaperPreset
    private(set) var appliedCrop: CarWallpaperCrop
    private(set) var hasUnappliedSource: Bool

    private let fileURL: URL
    private let sourceFileURL: URL
    private let defaults: UserDefaults

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        let folder = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("car-idle-wallpaper.jpg")
        sourceFileURL = folder.appendingPathComponent("car-idle-wallpaper-source.jpg")
        self.defaults = defaults

        let savedCrop = Self.loadCrop(from: defaults)
        if let applied = UIImage(contentsOfFile: fileURL.path) {
            image = applied
            sourceImage = UIImage(contentsOfFile: sourceFileURL.path) ?? applied
            isCustom = true
            selectedPreset = .hello
            appliedCrop = savedCrop
            hasUnappliedSource = false
        } else {
            let raw = defaults.string(forKey: Self.presetKey) ?? CarWallpaperPreset.hello.rawValue
            let preset = CarWallpaperPreset(rawValue: raw) ?? .hello
            let presetImage = preset.image()
            selectedPreset = preset
            image = presetImage
            if let staged = UIImage(contentsOfFile: sourceFileURL.path) {
                sourceImage = staged
                isCustom = true
                hasUnappliedSource = true
            } else {
                sourceImage = presetImage
                isCustom = false
                hasUnappliedSource = false
            }
            appliedCrop = .identity
        }
    }

    func setCustom(_ newImage: UIImage) {
        sourceImage = newImage
        persistSource(newImage)
        isCustom = true
        hasUnappliedSource = true
    }

    func applyCrop(
        _ crop: CarWallpaperCrop,
        preview: CGSize,
        carAspect: CGFloat,
        outputSize: CGSize
    ) {
        let locked = crop.clamped
        let cropped = WallpaperPreviewLayout.croppedImage(
            from: sourceImage,
            preview: preview,
            carAspect: carAspect,
            scale: locked.scale,
            offset: locked.offset,
            outputSize: outputSize
        )
        image = cropped
        persistApplied(cropped)
        persistCrop(locked)
        appliedCrop = locked
        isCustom = true
        hasUnappliedSource = false
        WallpaperContract.announceWallpaper(source: "photo")
    }

    func selectPreset(_ preset: CarWallpaperPreset) {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: sourceFileURL)
        selectedPreset = preset
        defaults.set(preset.rawValue, forKey: Self.presetKey)
        clearCrop()
        image = preset.image()
        sourceImage = image
        isCustom = false
        hasUnappliedSource = false
        WallpaperContract.announceWallpaper(source: "preset")
    }

    private func persistSource(_ image: UIImage) {
        if let prepared = Self.preparedJPEG(from: image, maxDimension: 3840, quality: 0.92) {
            try? prepared.write(to: sourceFileURL, options: .atomic)
        }
    }

    private func persistApplied(_ image: UIImage) {
        try? image.jpegData(compressionQuality: 0.95)?.write(to: fileURL, options: .atomic)
    }

    private func persistCrop(_ crop: CarWallpaperCrop) {
        defaults.set(Double(crop.scale), forKey: Self.cropScaleKey)
        defaults.set(Double(crop.offset.width), forKey: Self.cropOffsetXKey)
        defaults.set(Double(crop.offset.height), forKey: Self.cropOffsetYKey)
    }

    private func clearCrop() {
        defaults.removeObject(forKey: Self.cropScaleKey)
        defaults.removeObject(forKey: Self.cropOffsetXKey)
        defaults.removeObject(forKey: Self.cropOffsetYKey)
        appliedCrop = .identity
    }

    private static func loadCrop(from defaults: UserDefaults) -> CarWallpaperCrop {
        guard defaults.object(forKey: cropScaleKey) != nil else { return .identity }
        return CarWallpaperCrop(
            scale: CGFloat(defaults.double(forKey: cropScaleKey)),
            offset: CGSize(
                width: defaults.double(forKey: cropOffsetXKey),
                height: defaults.double(forKey: cropOffsetYKey)
            )
        ).clamped
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("CarWallpaper", isDirectory: true)
    }

    static func preparedJPEG(
        from image: UIImage,
        maxDimension: CGFloat = 1920,
        quality: CGFloat = 0.85
    ) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image.jpegData(compressionQuality: quality) }
        let longest = max(size.width, size.height)
        let scale = min(1, maxDimension / longest)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let rendered = renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
