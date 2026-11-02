// Saved rows on the Links page, and the mode the three mode buttons share.
// The car window is still the web view. A send posts cafariLiteSendToCar.

import Observation
import UIKit

enum PlayMode: String {
  case stream
  case webOnCar
  case mirror
}

struct SavedLink: Codable, Equatable {
  var id: UUID
  var title: String
  var urlString: String
  var starred: Bool
  var thumbStyle: String? = nil
  var durationLabel: String? = nil
  var thumbImageURLString: String? = nil

  var url: URL? { URL(string: urlString) }
  var thumbImageURL: URL? {
    guard let thumbImageURLString, !thumbImageURLString.isEmpty else { return nil }
    return URL(string: thumbImageURLString)
  }

  /// The five rows on the Stitch Links screen.
  static let stitchRows: [SavedLink] = [
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000001")!,
      title: "How to use my CarPlay Video app",
      urlString: "https://www.youtube.com/watch?v=gI3Tj2KP290",
      starred: true, thumbStyle: "video", durationLabel: "9:04"),
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0002-4000-8000-000000000002")!,
      title: "KT #789 - TIM BUTTERLY + KIRK FOX",
      urlString: "https://www.youtube.com/watch?v=ntTShp2YNlo",
      starred: true, thumbStyle: "kt789", durationLabel: "2:04:06"),
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0003-4000-8000-000000000003")!,
      title: "KT #780 - FLUFFY - HARLAND WILLIAMS",
      urlString: "https://www.youtube.com/watch?v=pTWRjXX6pc4",
      starred: true, thumbStyle: "kt780", durationLabel: "2:41:17"),
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0004-4000-8000-000000000004")!,
      title: "Test stream (Apple HLS sample)",
      urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
      starred: true, thumbStyle: "hls", durationLabel: nil),
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0005-4000-8000-000000000005")!,
      title: "YouTube Web Dashboard",
      urlString: "https://m.youtube.com",
      starred: true, thumbStyle: "web", durationLabel: nil),
  ]
}

extension Notification.Name {
  static let cafariLiteLinksChanged = Notification.Name("CafariLiteLinksChanged")
  static let cafariLitePlayModeChanged = Notification.Name("CafariLitePlayModeChanged")
}

@Observable
final class SavedLinkStore {
  static let shared = SavedLinkStore()
  private(set) var links: [SavedLink] = []
  @ObservationIgnored private let fileURL: URL

  private init() {
    let dir = URL.applicationSupportDirectory
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    fileURL = dir.appending(path: "saved-links.json")
    if let data = try? Data(contentsOf: fileURL),
       let decoded = try? JSONDecoder().decode([SavedLink].self, from: data) {
      links = decoded
    }
    let previousStarterIDs = Set(SavedLink.stitchRows.map(\.id))
    if links.isEmpty || links.contains(where: { previousStarterIDs.contains($0.id) }) {
      links = SavedLink.stitchRows
      if let data = try? JSONEncoder().encode(links) {
        try? data.write(to: fileURL, options: .atomic)
      }
    }
  }

  func add(url: URL, title: String? = nil) {
    let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
    let id = UUID()
    var link = SavedLink(
      id: id,
      title: placeholderTitle(url: url, override: trimmed),
      urlString: url.absoluteString,
      starred: false)
    if let videoID = BrowserViewController.youtubeID(for: url) {
      link.thumbStyle = "youtube"
      link.thumbImageURLString = YouTubeLinkMetadata.thumbnailURL(forVideoID: videoID).absoluteString
    }
    links.insert(link, at: 0)
    save()
    if BrowserViewController.youtubeID(for: url) != nil {
      Task { await enrichYouTubeLink(id: id, url: url) }
    }
  }

  @MainActor
  private func enrichYouTubeLink(id: UUID, url: URL) async {
    guard let resolved = await YouTubeLinkMetadata.resolve(url: url),
          let index = links.firstIndex(where: { $0.id == id }) else {
      return
    }
    links[index].title = resolved.title
    links[index].thumbImageURLString = resolved.thumbImageURL.absoluteString
    links[index].durationLabel = resolved.durationLabel
    links[index].thumbStyle = "youtube"
    save()
  }

  private func placeholderTitle(url: URL, override: String?) -> String {
    if let override, !override.isEmpty { return override }
    if let videoID = BrowserViewController.youtubeID(for: url) {
      return "YouTube · \(videoID)"
    }
    let host = url.host() ?? ""
    if !host.isEmpty { return host }
    let text = url.absoluteString
    if text.count > 48 { return String(text.prefix(45)) + "…" }
    return text
  }

  func toggleStar(_ id: UUID) {
    guard let index = links.firstIndex(where: { $0.id == id }) else { return }
    links[index].starred.toggle()
    save()
  }

  func delete(id: UUID) {
    links.removeAll { $0.id == id }
    save()
  }

  func rename(id: UUID, title: String) {
    guard let index = links.firstIndex(where: { $0.id == id }) else { return }
    links[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    save()
  }

  func move(id: UUID, to destination: Int) {
    guard let source = links.firstIndex(where: { $0.id == id }),
          links.indices.contains(destination) else { return }
    let link = links.remove(at: source)
    links.insert(link, at: destination)
    save()
  }

  private func save() {
    if let data = try? JSONEncoder().encode(links) {
      try? data.write(to: fileURL, options: .atomic)
    }
    NotificationCenter.default.post(name: .cafariLiteLinksChanged, object: nil)
  }
}

/// The item the CarPlay pill sends, and the mode the three Links buttons share.
@Observable
final class PhonePlayback {
  static let shared = PhonePlayback()

  private enum SessionKeys {
    static let lastLinkID = "cafariLastPlaybackLinkID"
    static let queueIndex = "cafariLastPlaybackQueueIndex"
  }

  var mode: PlayMode = .webOnCar {
    didSet { NotificationCenter.default.post(name: .cafariLitePlayModeChanged, object: nil) }
  }

  private(set) var currentTitle: String?
  private(set) var currentURL: URL?
  private(set) var queue: [SavedLink] = []
  private(set) var queueIndex: Int = 0

  func remember(title: String, url: URL?) {
    currentTitle = title
    currentURL = url
    if url != nil { persistSession() }
  }

  func setQueue(_ links: [SavedLink], index: Int) {
    queue = links
    queueIndex = links.indices.contains(index) ? index : 0
    persistSession()
  }

  func noteIndex(_ index: Int) {
    guard queue.indices.contains(index) else { return }
    queueIndex = index
    let link = queue[index]
    remember(title: link.title, url: link.url)
  }

  func move(by delta: Int) -> SavedLink? {
    let next = queueIndex + delta
    guard queue.indices.contains(next) else { return nil }
    queueIndex = next
    let link = queue[next]
    remember(title: link.title, url: link.url)
    return link
  }

  /// Restores the last watched link from disk when the in-memory session is empty.
  func restoreSavedSession(from links: [SavedLink]) {
    guard currentURL == nil,
          let idString = UserDefaults.standard.string(forKey: SessionKeys.lastLinkID),
          let id = UUID(uuidString: idString),
          let linkIndex = links.firstIndex(where: { $0.id == id }) else {
      return
    }
    let savedIndex = UserDefaults.standard.integer(forKey: SessionKeys.queueIndex)
    let index = links.indices.contains(savedIndex) ? savedIndex : linkIndex
    setQueue(links, index: index)
    let link = links[index]
    remember(title: link.title, url: link.url)
  }

  private func persistSession() {
    guard queue.indices.contains(queueIndex) else { return }
    let link = queue[queueIndex]
    UserDefaults.standard.set(link.id.uuidString, forKey: SessionKeys.lastLinkID)
    UserDefaults.standard.set(queueIndex, forKey: SessionKeys.queueIndex)
  }

  func clipQueue() -> [ControllerClip] {
    queue.map { ControllerClip(link: $0) }
  }
}

enum LinkURL {
  static func normalize(_ raw: String) -> URL? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed), url.scheme != nil { return url }
    return URL(string: "https://\(trimmed)")
  }
}

enum CarSender {
  static var carIsConnected: Bool {
    UIApplication.shared.connectedScenes.contains { scene in
      scene.session.role == cafariLiteCarPlayRole
    }
  }

  /// Web on car and Mirror hand the page across.
  static func sendPage(_ url: URL) {
    SessionCounts.carAction()
    Log.write("sendPage \(url.absoluteString)")
    NotificationCenter.default.post(
      name: .cafariLiteSendToCar, object: nil, userInfo: ["url": url])
  }

  /// Stream hands the bare player when the link is a YouTube video.
  static func sendDirect(_ url: URL) {
    SessionCounts.carAction()
    let destination = BrowserViewController.playerURL(for: url) ?? url
    Log.write("sendDirect \(url.absoluteString) -> \(destination.absoluteString)")
    NotificationCenter.default.post(
      name: .cafariLiteSendToCar, object: nil, userInfo: ["url": destination])
  }

  @discardableResult
  static func sendCurrentItem() -> Bool {
    guard let url = PhonePlayback.shared.currentURL else { return false }
    if PhonePlayback.shared.mode == .stream {
      sendDirect(url)
    } else {
      sendPage(url)
    }
    return true
  }
}
