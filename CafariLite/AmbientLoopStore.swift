import Foundation
import Observation

struct AmbientLoop: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var fileName: String?

    var isCustom: Bool { fileName != nil }
}

@Observable
@MainActor
final class AmbientLoopStore {
    static let shared = AmbientLoopStore()

    private static let storageKey = "cafari.ambientLoops.v1"

    private(set) var loops: [AmbientLoop] = []
    var customLoops: [AmbientLoop] { loops.filter(\.isCustom) }
    private(set) var clipCrops: [UUID: AmbientClipCropRecord] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let payload = try? JSONDecoder().decode(StoragePayload.self, from: data) {
            loops = payload.loops
            clipCrops = payload.clipCrops
        } else {
            loops = []
        }
    }

    func crop(forID id: UUID) -> AmbientClipCropRecord {
        clipCrops[id] ?? .identity
    }

    func mediaSize(forID id: UUID) -> CGSize {
        let record = crop(forID: id)
        if record.hasMediaSize { return record.mediaSize }
        return CGSize(width: 1920, height: 1080)
    }

    func applyCrop(_ crop: CarWallpaperCrop, box: CGRect, mediaSize: CGSize, forID id: UUID) {
        clipCrops[id] = AmbientClipCropRecord.make(crop: crop, box: box, mediaSize: mediaSize)
        persist()
        WallpaperContract.announceWallpaper(source: "clip")
    }

    func url(forID id: UUID) -> URL? {
        guard let loop = loops.first(where: { $0.id == id }),
              let fileName = loop.fileName else { return nil }
        let url = Self.loopsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func importLoop(from sourceURL: URL, title: String? = nil) throws -> AmbientLoop {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        try FileManager.default.createDirectory(at: Self.loopsDirectory, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(ext)"
        let destination = Self.loopsDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let loop = AmbientLoop(
            id: UUID(),
            title: title ?? sourceURL.deletingPathExtension().lastPathComponent,
            fileName: fileName
        )
        loops.append(loop)
        persist()
        Log.write("ambient imported \(loop.title)")
        return loop
    }

    func delete(_ loop: AmbientLoop) {
        guard let fileName = loop.fileName else { return }
        let url = Self.loopsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
        loops.removeAll { $0.id == loop.id }
        clipCrops.removeValue(forKey: loop.id)
        persist()
    }

    private struct StoragePayload: Codable {
        var loops: [AmbientLoop]
        var clipCrops: [UUID: AmbientClipCropRecord]
    }

    private func persist() {
        let payload = StoragePayload(loops: loops, clipCrops: clipCrops)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static var loopsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AmbientLoops", isDirectory: true)
    }
}
