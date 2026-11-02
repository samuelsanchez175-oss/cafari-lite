import Foundation
import OSLog

private let libraryOSLog = Logger(subsystem: "com.samuelsanchez.ytos27", category: "library")

enum LibraryLog {
  static var isVerbose: Bool {
    Settings.libraryVerboseLogging
  }

  static func write(_ line: String) {
    guard isVerbose else { return }
    libraryOSLog.notice("\(line, privacy: .public)")
    appendToFile(line)
  }

  private static func appendToFile(_ line: String) {
    let stamp = Date().formatted(date: .omitted, time: .standard)
    let url = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("library-status.txt")
    let text = "\(stamp) \(line)\n"
    guard let data = text.data(using: .utf8) else { return }
    if FileManager.default.fileExists(atPath: url.path),
       let handle = try? FileHandle(forWritingTo: url) {
      handle.seekToEndOfFile()
      handle.write(data)
      try? handle.close()
    } else {
      try? data.write(to: url)
    }
  }

  static func readTail(maxLines: Int = 80) -> String {
    let url = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("library-status.txt")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
      return "(No library-status.txt yet — open Library once.)"
    }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    if lines.count <= maxLines { return text }
    return lines.suffix(maxLines).joined(separator: "\n")
  }
}

struct LibraryTraceEvent: Identifiable, Equatable {
  enum Category: String, CaseIterable {
    case load
    case thumbnail
    case scroll
    case ui
    case failure
  }

  let id = UUID()
  let timestamp: Date
  let category: Category
  let message: String
  let detail: String?

  var line: String {
    let extra = detail.map { " \($0)" } ?? ""
    return "[\(category.rawValue)] \(message)\(extra)"
  }
}

@MainActor
final class LibraryTrace {
  static let shared = LibraryTrace()

  private(set) var events: [LibraryTraceEvent] = []
  private let capacity = 200

  private init() {}

  func record(_ category: LibraryTraceEvent.Category, _ message: String, detail: String? = nil) {
    let event = LibraryTraceEvent(timestamp: Date(), category: category, message: message, detail: detail)
    events.insert(event, at: 0)
    if events.count > capacity {
      events.removeLast(events.count - capacity)
    }
    LibraryLog.write(event.line)
  }

  func clear() {
    events.removeAll()
  }
}
