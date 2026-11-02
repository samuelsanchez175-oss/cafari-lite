import Foundation

enum SavedLinksPlayback {
  static func playAllOnCar() {
    let store = SavedLinkStore.shared
    guard let first = store.links.first, let url = first.url else {
      Log.write("settings play all on car empty")
      return
    }
    Log.write("settings play all on car \(first.title)")
    PhonePlayback.shared.setQueue(store.links, index: 0)
    PhonePlayback.shared.remember(title: first.title, url: url)
    NotificationCenter.default.post(
      name: .cafariLiteOpenController,
      object: nil,
      userInfo: [
        "clips": PhonePlayback.shared.clipQueue(),
        "index": PhonePlayback.shared.queueIndex,
        "onCar": true,
        "tracksQueue": true,
        "send": false,
      ])
    if PhonePlayback.shared.mode == .stream {
      CarSender.sendDirect(url)
    } else {
      CarSender.sendPage(url)
    }
  }

  static func playAllDetail() -> String {
    if SavedLinkStore.shared.links.isEmpty { return "No saved links" }
    if !CarSessionState.isConnected { return "Connect CarPlay" }
    return "\(SavedLinkStore.shared.links.count) links"
  }
}
