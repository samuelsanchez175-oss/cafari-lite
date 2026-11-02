import Foundation
import Observation
import WebKit

/// YouTube sign-in state via the shared persistent WKWebsiteDataStore (same as car browser).
@Observable
@MainActor
final class YouTubeAccountManager {
    static let shared = YouTubeAccountManager()

    private(set) var isSignedIn = false

    static let signInURL = URL(
        string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fm.youtube.com%2F"
    )!

    init() {
        checkStatus()
    }

    func checkStatus() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let loggedIn = cookies.contains { cookie in
                (cookie.domain.contains("youtube.com") || cookie.domain.contains("google.com"))
                    && (cookie.name == "LOGIN_INFO" || cookie.name == "SID" || cookie.name == "SSID" || cookie.name == "APISID")
            }
            Task { @MainActor in
                let changed = self.isSignedIn != loggedIn
                self.isSignedIn = loggedIn
                if changed {
                    Log.write("youtube account signedIn=\(loggedIn)")
                }
            }
        }
    }

    func signOut() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let group = DispatchGroup()
            for cookie in cookies where cookie.domain.contains("youtube.com") || cookie.domain.contains("google.com") {
                group.enter()
                WKWebsiteDataStore.default().httpCookieStore.delete(cookie) {
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                Task { @MainActor in
                    self.isSignedIn = false
                    Log.write("youtube account signed out")
                    NotificationCenter.default.post(name: .cafariLiteAccountChanged, object: nil)
                }
            }
        }
    }
}
