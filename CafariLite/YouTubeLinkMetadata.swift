// Resolves title, thumbnail, and duration when a YouTube URL is saved on Links.

import Foundation

enum YouTubeLinkMetadata {
  struct Resolved: Sendable {
    var title: String
    var thumbImageURL: URL
    var durationLabel: String?
  }

  static func thumbnailURL(forVideoID id: String) -> URL {
    URL(string: "https://img.youtube.com/vi/\(id)/mqdefault.jpg")!
  }

  static func resolve(url: URL) async -> Resolved? {
    guard let videoID = BrowserViewController.youtubeID(for: url) else { return nil }
    let fallbackThumb = thumbnailURL(forVideoID: videoID)
    let fallbackTitle = "YouTube · \(videoID)"

    async let oEmbed = fetchOEmbed(pageURL: url)
    async let duration = fetchDurationSeconds(videoID: videoID)

    let embed = await oEmbed
    let seconds = await duration
    let title = embed?.title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? fallbackTitle
    let thumb = embed?.thumbnailURL ?? fallbackThumb
    let durationLabel = seconds.map(formatDuration(seconds:))
    return Resolved(title: title, thumbImageURL: thumb, durationLabel: durationLabel)
  }

  private struct OEmbedPayload: Decodable {
    var title: String
    var thumbnail_url: String

    var thumbnailURL: URL? { URL(string: thumbnail_url) }
  }

  private static func fetchOEmbed(pageURL: URL) async -> OEmbedPayload? {
    var components = URLComponents(string: "https://www.youtube.com/oembed")!
    components.queryItems = [
      URLQueryItem(name: "url", value: pageURL.absoluteString),
      URLQueryItem(name: "format", value: "json"),
    ]
    guard let url = components.url else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 12
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return nil
      }
      return try JSONDecoder().decode(OEmbedPayload.self, from: data)
    } catch {
      Log.write("youtube oembed fail \(pageURL.absoluteString) \(error.localizedDescription)")
      return nil
    }
  }

  private static func fetchDurationSeconds(videoID: String) async -> Int? {
    guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 12
    request.setValue(
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
      forHTTPHeaderField: "User-Agent")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
            let html = String(data: data, encoding: .utf8) else {
        return nil
      }
      if let match = html.firstMatch(in: #"\"lengthSeconds\"\s*:\s*\"(\d+)\""#) {
        return Int(match)
      }
      if let match = html.firstMatch(in: #"\"approxDurationMs\"\s*:\s*\"(\d+)\""#),
         let ms = Int(match) {
        return ms / 1000
      }
      return nil
    } catch {
      Log.write("youtube duration fail \(videoID) \(error.localizedDescription)")
      return nil
    }
  }

  static func formatDuration(seconds: Int) -> String {
    let safe = max(0, seconds)
    let hours = safe / 3600
    let minutes = (safe % 3600) / 60
    let secs = safe % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
  }
}

private extension String {
  var nonEmpty: String? { isEmpty ? nil : self }

  func firstMatch(in pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(startIndex..., in: self)
    guard let match = regex.firstMatch(in: self, range: range),
          match.numberOfRanges > 1,
          let capture = Range(match.range(at: 1), in: self) else {
      return nil
    }
    return String(self[capture])
  }
}
