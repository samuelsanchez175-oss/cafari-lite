import SafariServices
import UIKit

/// In-app Google / YouTube sign-in using the shared cookie jar.
final class YouTubeSignInController: UIViewController, SFSafariViewControllerDelegate {
    private var safari: SFSafariViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        presentSafari()
    }

    private func presentSafari() {
        let controller = SFSafariViewController(url: YouTubeAccountManager.signInURL)
        controller.delegate = self
        controller.modalPresentationStyle = .pageSheet
        safari = controller
        present(controller, animated: true)
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        YouTubeAccountManager.shared.checkStatus()
        NotificationCenter.default.post(name: .cafariLiteAccountChanged, object: nil)
        dismiss(animated: true)
    }
}
