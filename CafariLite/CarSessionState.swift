import Foundation

/// Whether the CarPlay window scene is connected (updated from CarPlaySceneDelegate).
enum CarSessionState {
  private(set) static var isConnected = false

  static func setConnected(_ connected: Bool) {
    isConnected = connected
  }

  static var displayHint: String {
    isConnected ? "Connected" : "Plug in the car"
  }
}
