import UIKit

enum ShortcutsSupport {
  static var shortcutBuilderPrompt: String {
    """
    Create a shortcut named Paste and play. When it runs, take the video link from the clipboard and open it in Cafari Lite on the Links tab so it can play on CarPlay.
    """
  }

  static var shortcutsAppURL: URL {
    URL(string: "shortcuts://")!
  }

  static var actionButtonSettingsURL: URL {
    URL(string: "App-prefs:root=ACTION_BUTTON")!
  }

  static func copyPromptAndOpenShortcuts(completion: ((String) -> Void)? = nil) {
    UIPasteboard.general.string = shortcutBuilderPrompt
    UIApplication.shared.open(shortcutsAppURL) { ok in
      let message = ok
        ? "Prompt copied. In Shortcuts, paste it under Describe a shortcut."
        : "Prompt copied. Open Shortcuts and paste it under Describe a shortcut."
      completion?(message)
    }
  }

  static func openActionButtonSettings() {
    UIApplication.shared.open(actionButtonSettingsURL) { ok in
      if ok { return }
      if let settings = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settings)
      }
    }
  }
}

final class ActionButtonHelpViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Action Button"
    view.backgroundColor = .systemGroupedBackground
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .done,
      primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
    )

    let text = UILabel()
    text.numberOfLines = 0
    text.font = .systemFont(ofSize: 15)
    text.textColor = .label
    text.text = """
    Assign your Paste and play shortcut to the Action Button:

    1. Tap Create Shortcut first and paste the prompt in Shortcuts.
    2. Open Action Button settings and pick Shortcuts → Paste and play.

    Share a video from Safari or YouTube into Cafari Lite — Links opens with it ready to send to the car.
    """
    text.translatesAutoresizingMaskIntoConstraints = false

    let shortcutButton = UIButton(type: .system)
    shortcutButton.setTitle("Create Shortcut first", for: .normal)
    shortcutButton.addAction(UIAction { _ in ShortcutsSupport.copyPromptAndOpenShortcuts() }, for: .touchUpInside)

    let actionButton = UIButton(type: .system)
    actionButton.setTitle("Open Action Button settings", for: .normal)
    actionButton.addAction(UIAction { _ in ShortcutsSupport.openActionButtonSettings() }, for: .touchUpInside)

    let stack = UIStackView(arrangedSubviews: [text, shortcutButton, actionButton])
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
    ])
  }
}
