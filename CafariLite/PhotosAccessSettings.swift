import Photos
import UIKit

enum PhotosAccessSettings {
  static func statusLabel(for status: PHAuthorizationStatus) -> String {
    switch status {
    case .authorized: "Full Access"
    case .limited: "Limited"
    case .denied: "Off"
    case .restricted: "Restricted"
    case .notDetermined: "Not Asked"
    @unknown default: "Unknown"
    }
  }

  static func handle(from viewController: UIViewController) {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    switch status {
    case .notDetermined:
      Task { @MainActor in
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
      }
    case .limited:
      PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    case .denied, .restricted:
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
    case .authorized:
      break
    @unknown default:
      break
    }
  }
}
