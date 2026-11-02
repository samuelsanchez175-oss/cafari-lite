import Foundation
import OSLog

private typealias SecTaskRef = OpaquePointer

@_silgen_name("SecTaskCreateFromSelf")
private func secTaskCreateFromSelf(_ allocator: CFAllocator?) -> SecTaskRef?

@_silgen_name("SecTaskCopyValueForEntitlement")
private func secTaskCopyValueForEntitlement(
  _ task: SecTaskRef,
  _ entitlement: CFString,
  _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?
) -> CFTypeRef?

private let doctorLog = Logger(subsystem: "com.samuelsanchez.ytos27", category: "carplay-signing")

enum CarStatusLog {
  static func write(_ line: String) {
    let url = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("car-status.txt")
    let text = line + "\n"
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

  static func tail(maxLines: Int = 24) -> String {
    let url = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("car-status.txt")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
      return "(No car-status.txt yet.)"
    }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    if lines.count <= maxLines { return text }
    return lines.suffix(maxLines).joined(separator: "\n")
  }
}

/// Runtime audit: whether this installed build can appear on the CarPlay home screen.
@MainActor
final class CarPlayEntitlementDoctor {
  static let shared = CarPlayEntitlementDoctor()

  private(set) var lastReport: CarPlayEntitlementReport?

  private init() {}

  @discardableResult
  func audit(reason: String) -> CarPlayEntitlementReport {
    let report = CarPlayEntitlementReport.inspect(reason: reason)
    lastReport = report
    CarStatusLog.write(report.logLine)
    Log.write(report.logLine)
    doctorLog.notice("\(report.logLine, privacy: .public)")
    return report
  }
}

struct CarPlayEntitlementReport: Equatable {
  let reason: String
  let bundleID: String
  let teamIdentifier: String?
  let hasCarPlayVideo: Bool
  let hasCarPlayAudio: Bool
  let applicationIdentifier: String?

  var carPlayReady: Bool { hasCarPlayVideo && hasCarPlayAudio }

  var summary: String {
    "video=\(hasCarPlayVideo) audio=\(hasCarPlayAudio) team=\(teamIdentifier ?? "none") bundle=\(bundleID)"
  }

  var logLine: String {
    "carplay entitlement doctor reason=\(reason) carplay_ready=\(carPlayReady) \(summary)"
  }

  var userMessage: String {
    if carPlayReady {
      return "This build is CarPlay-entitled. If the app still does not appear on the car home screen, connect CarPlay and check the car log for scene connect lines."
    }
    var parts = [
      "This build is not CarPlay-entitled. Reinstall with a profile that embeds both carplay-video and carplay-audio for \(bundleID).",
    ]
    if !hasCarPlayVideo { parts.append("Missing: com.apple.developer.carplay-video") }
    if !hasCarPlayAudio { parts.append("Missing: com.apple.developer.carplay-audio") }
    if teamIdentifier == nil || teamIdentifier?.isEmpty == true {
      parts.append("No team identifier in runtime entitlements — signing may be ad-hoc or stripped.")
    }
    return parts.joined(separator: " ")
  }

  static func inspect(reason: String) -> CarPlayEntitlementReport {
    let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
    guard let task = secTaskCreateFromSelf(nil) else {
      return CarPlayEntitlementReport(
        reason: reason,
        bundleID: bundleID,
        teamIdentifier: nil,
        hasCarPlayVideo: false,
        hasCarPlayAudio: false,
        applicationIdentifier: nil
      )
    }
    let video = entitlementBool(task, "com.apple.developer.carplay-video")
    let audio = entitlementBool(task, "com.apple.developer.carplay-audio")
    let team = entitlementString(task, "com.apple.developer.team-identifier")
    let appID = entitlementString(task, "application-identifier")
    return CarPlayEntitlementReport(
      reason: reason,
      bundleID: bundleID,
      teamIdentifier: team,
      hasCarPlayVideo: video,
      hasCarPlayAudio: audio,
      applicationIdentifier: appID
    )
  }

  private static func entitlementBool(_ task: SecTaskRef, _ key: String) -> Bool {
    guard let value = secTaskCopyValueForEntitlement(task, key as CFString, nil) else { return false }
    if let b = value as? Bool { return b }
    if let n = value as? NSNumber { return n.boolValue }
    return true
  }

  private static func entitlementString(_ task: SecTaskRef, _ key: String) -> String? {
    guard let value = secTaskCopyValueForEntitlement(task, key as CFString, nil) else { return nil }
    return value as? String
  }
}
