import Foundation

/// Whether the CarPlay window scene is connected (updated from CarPlaySceneDelegate).
enum CarSessionState {
  private(set) static var isConnected = false
  /// Point size of the car window when last connected.
  private(set) static var carWindowSize: CGSize = .zero
  /// Native pixel size of the car panel (landscape width × height).
  private(set) static var carNativeSize: CGSize = .zero

  static func setConnected(_ connected: Bool, windowSize: CGSize = .zero) {
    isConnected = connected
    if connected, windowSize.width > 0, windowSize.height > 0 {
      carWindowSize = windowSize
    } else if !connected {
      carWindowSize = .zero
      carNativeSize = .zero
    }
  }

  static func noteCarNativeSize(_ size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    carNativeSize = size
  }

  /// Landscape aspect from the live car panel when connected.
  static var liveCarAspect: CGFloat? {
    guard isConnected else { return nil }
    let basis = carNativeSize.width > 1 ? carNativeSize : carWindowSize
    guard basis.width > 1, basis.height > 1 else { return nil }
    let width = max(basis.width, basis.height)
    let height = min(basis.width, basis.height)
    return width / height
  }

  static var carSizeHint: String {
    guard isConnected else { return "Car not connected" }
    if carNativeSize.width > 1 {
      return "\(Int(carNativeSize.width))×\(Int(carNativeSize.height)) px"
    }
    if carWindowSize.width > 1 {
      return "\(Int(carWindowSize.width))×\(Int(carWindowSize.height)) pt"
    }
    return "Connected (size pending)"
  }

  static var displayHint: String {
    isConnected ? "Connected" : "Plug in the car"
  }
}
