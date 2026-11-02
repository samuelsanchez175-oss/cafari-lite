import CoreGraphics
import Foundation
import UIKit

enum CarWallpaperPreset: String, CaseIterable, Identifiable {
    case hello
    case neonNight
    case coastalSunrise
    case tunnelExit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hello: return "Hello"
        case .neonNight: return "Neon Night"
        case .coastalSunrise: return "Coastal Sunrise"
        case .tunnelExit: return "Tunnel Exit"
        }
    }

    var resourceName: String {
        switch self {
        case .hello: return "sample-neon-night"
        case .neonNight: return "sample-neon-night"
        case .coastalSunrise: return "sample-coastal-sunrise"
        case .tunnelExit: return "sample-tunnel-exit"
        }
    }

    func image() -> UIImage {
        if let named = UIImage(named: resourceName) { return named }
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg", subdirectory: "Samples"),
           let disk = UIImage(contentsOfFile: url.path) {
            return disk
        }
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg"),
           let disk = UIImage(contentsOfFile: url.path) {
            return disk
        }
        return UIImage()
    }
}

enum CarIdleLook: Equatable, Identifiable, Sendable {
    case wallpaper
    case fireplace
    case rain
    case colorWaves
    case clip(UUID)

    static let builtIn: [CarIdleLook] = [.wallpaper, .fireplace, .rain, .colorWaves]

    var id: String {
        switch self {
        case .wallpaper: return "wallpaper"
        case .fireplace: return "fireplace"
        case .rain: return "rain"
        case .colorWaves: return "colorWaves"
        case .clip(let uuid): return "clip-\(uuid.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .wallpaper: return "Wallpaper"
        case .fireplace: return IdleAmbientScene.fireplace.title
        case .rain: return IdleAmbientScene.rain.title
        case .colorWaves: return IdleAmbientScene.colorWaves.title
        case .clip: return "Video loop"
        }
    }

    var allowsPinchCrop: Bool {
        switch self {
        case .wallpaper, .clip: return true
        case .fireplace, .rain, .colorWaves: return false
        }
    }

    var clipID: UUID? {
        if case .clip(let uuid) = self { return uuid }
        return nil
    }

    var ambientScene: IdleAmbientScene? {
        switch self {
        case .wallpaper, .clip: return nil
        case .fireplace: return .fireplace
        case .rain: return .rain
        case .colorWaves: return .colorWaves
        }
    }

    var persistenceRaw: String {
        switch self {
        case .clip(let uuid): return "clip:\(uuid.uuidString)"
        default: return id
        }
    }

    static func parse(_ raw: String) -> CarIdleLook {
        if raw.hasPrefix("clip:"),
           let uuid = UUID(uuidString: String(raw.dropFirst(5))) {
            return .clip(uuid)
        }
        switch raw {
        case "fireplace": return .fireplace
        case "rain": return .rain
        case "colorWaves": return .colorWaves
        default: return .wallpaper
        }
    }
}

enum IdleAmbientScene: String, CaseIterable, Identifiable, Sendable {
    case fireplace
    case rain
    case colorWaves

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fireplace: return "Fireplace"
        case .rain: return "Rain on glass"
        case .colorWaves: return "Color waves"
        }
    }

    var carPlayLoopResource: String {
        switch self {
        case .fireplace: return "sample-neon-night"
        case .rain: return "sample-coastal-sunrise"
        case .colorWaves: return "sample-tunnel-exit"
        }
    }

    func previewImage() -> UIImage {
        if let img = UIImage(named: carPlayLoopResource) { return img }
        for sub in ["Samples", nil] as [String?] {
            if let url = Bundle.main.url(forResource: carPlayLoopResource, withExtension: "jpg", subdirectory: sub),
               let img = UIImage(contentsOfFile: url.path) {
                return img
            }
        }
        return UIImage()
    }

    func loopURL() -> URL? {
        for sub in ["Samples", nil] as [String?] {
            if let url = Bundle.main.url(forResource: carPlayLoopResource, withExtension: "mp4", subdirectory: sub) {
                return url
            }
        }
        return nil
    }
}

struct CarWallpaperCrop: Equatable {
    var scale: CGFloat
    var offset: CGSize

    static let identity = CarWallpaperCrop(scale: 1, offset: .zero)

    var clamped: CarWallpaperCrop {
        CarWallpaperCrop(scale: min(max(scale, 1), 4), offset: offset)
    }
}

struct AmbientClipCropRecord: Codable, Equatable {
    var scale: Double
    var offsetWidth: Double
    var offsetHeight: Double
    var mediaWidth: Double
    var mediaHeight: Double

    static let identity = AmbientClipCropRecord(
        scale: 1, offsetWidth: 0, offsetHeight: 0, mediaWidth: 0, mediaHeight: 0
    )

    var hasMediaSize: Bool { mediaWidth > 1 && mediaHeight > 1 }

    var mediaSize: CGSize { CGSize(width: mediaWidth, height: mediaHeight) }

    static func make(crop: CarWallpaperCrop, box: CGRect, mediaSize: CGSize) -> AmbientClipCropRecord {
        _ = box
        return AmbientClipCropRecord(
            scale: Double(crop.scale),
            offsetWidth: Double(crop.offset.width),
            offsetHeight: Double(crop.offset.height),
            mediaWidth: Double(mediaSize.width),
            mediaHeight: Double(mediaSize.height)
        )
    }

    func previewCrop(in box: CGRect) -> CarWallpaperCrop {
        _ = box
        return CarWallpaperCrop(scale: CGFloat(scale), offset: CGSize(width: offsetWidth, height: offsetHeight)).clamped
    }
}

enum WallpaperPreviewLayout {
    static let defaultCarAspect: CGFloat = 16.0 / 9.0

    static func yellowBox(in size: CGSize, carAspect: CGFloat) -> CGRect {
        let aspect = carAspect > 0.2 ? carAspect : defaultCarAspect
        guard size.width > 1, size.height > 1 else { return .zero }
        var width = size.width
        var height = width / aspect
        if height > size.height {
            height = size.height
            width = height * aspect
        }
        let origin = CGPoint(x: (size.width - width) / 2, y: (size.height - height) / 2)
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    static func baseImageSize(image: CGSize, box: CGRect) -> CGSize {
        guard image.width > 1, image.height > 1, box.width > 1, box.height > 1 else { return box.size }
        let scale = max(box.width / image.width, box.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }

    static func outputSize(forCar size: CGSize) -> CGSize {
        if size.width > 1, size.height > 1 { return size }
        return CGSize(width: 1920, height: 720)
    }

    static func croppedImage(
        from image: UIImage,
        preview: CGSize,
        carAspect: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        outputSize: CGSize
    ) -> UIImage {
        let box = yellowBox(in: preview, carAspect: carAspect)
        let base = baseImageSize(image: image.size, box: box)
        let drawn = CGSize(width: base.width * max(scale, 1), height: base.height * max(scale, 1))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { _ in
            let sx = outputSize.width / max(box.width, 1)
            let sy = outputSize.height / max(box.height, 1)
            let rect = CGRect(
                x: (outputSize.width - drawn.width * sx) / 2 + offset.width * sx,
                y: (outputSize.height - drawn.height * sy) / 2 + offset.height * sy,
                width: drawn.width * sx,
                height: drawn.height * sy
            )
            image.draw(in: rect)
        }
    }

    static func layerFrame(mediaSize: CGSize, container: CGRect, record: AmbientClipCropRecord) -> CGRect {
        let crop = record.previewCrop(in: container)
        let base = baseImageSize(image: mediaSize, box: container)
        let size = CGSize(width: base.width * crop.scale, height: base.height * crop.scale)
        return CGRect(
            x: container.midX - size.width / 2 + crop.offset.width,
            y: container.midY - size.height / 2 + crop.offset.height,
            width: size.width,
            height: size.height
        )
    }
}

enum WallpaperContract {
    static let setupDoneKey = "cafari.car.wallpaperSetupDone"
    static let sourceKey = "source"

    static var setupDone: Bool {
        get { UserDefaults.standard.bool(forKey: setupDoneKey) }
        set { UserDefaults.standard.set(newValue, forKey: setupDoneKey) }
    }

    @MainActor
    static func announceWallpaper(source: String) {
        Log.write("wallpaper changed source=\(source)")
        NotificationCenter.default.post(
            name: .cafariLiteWallpaperDidChange,
            object: nil,
            userInfo: [sourceKey: source]
        )
    }
}

enum WallpaperSetup {
    static func shouldPresent(arguments: [String] = CommandLine.arguments) -> Bool {
        if arguments.contains("-skipWallpaperSetup") { return false }
        return !WallpaperContract.setupDone
    }
}

extension Notification.Name {
    static let cafariLiteWallpaperDidChange = Notification.Name("CafariLiteWallpaperDidChange")
    static let cafariLiteIdleLookChanged = Notification.Name("CafariLiteIdleLookChanged")
}
