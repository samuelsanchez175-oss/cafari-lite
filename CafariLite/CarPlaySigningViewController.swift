import UIKit

final class CarPlaySigningViewController: UIViewController {
  private let scrollView = UIScrollView()
  private let stack = UIStackView()
  private var report: CarPlayEntitlementReport?

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "CarPlay signing"
    view.backgroundColor = .systemGroupedBackground
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .done,
      primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
    )
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Re-check",
      primaryAction: UIAction { [weak self] _ in self?.recheck() }
    )

    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)
    scrollView.addSubview(stack)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
      stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
    ])
    recheck()
  }

  private func recheck() {
    Task { @MainActor in
      report = CarPlayEntitlementDoctor.shared.audit(reason: "settings-panel")
      rebuildCards()
    }
  }

  private func rebuildCards() {
    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    guard let report else { return }

    let status = card(
      title: report.carPlayReady ? "CarPlay entitled" : "Not CarPlay entitled",
      titleColor: report.carPlayReady ? UIColor.systemGreen : UIColor.systemOrange,
      body: report.userMessage + "\n\n" + report.summary
    )
    stack.addArrangedSubview(status)

    let steps = card(
      title: "If the app is missing on the car home screen",
      body: """
      1. Request CarPlay video at developer.apple.com/contact/carplay/ for bundle id com.samuelsanchez.ytos27.
      2. Enable the CarPlay capability on that App ID in Certificates, Identifiers & Profiles.
      3. Download a new Development profile and reinstall on your iPhone.
      4. Run tools/run-on-device.sh and confirm both carplay keys appear in the signed app.
      """
    )
    stack.addArrangedSubview(steps)

    let logCard = UIView()
    logCard.backgroundColor = .secondarySystemGroupedBackground
    logCard.layer.cornerRadius = 12
    logCard.translatesAutoresizingMaskIntoConstraints = false

    let logTitle = UILabel()
    logTitle.text = "car-status.txt (tail)"
    logTitle.font = .systemFont(ofSize: 15, weight: .semibold)
    logTitle.translatesAutoresizingMaskIntoConstraints = false

    let copyButton = UIButton(type: .system)
    copyButton.setTitle("Copy log", for: .normal)
    copyButton.addAction(UIAction { [weak self] _ in
      guard let report = self?.report else { return }
      UIPasteboard.general.string = "\(report.logLine)\n\n\(CarStatusLog.tail())"
    }, for: .touchUpInside)
    copyButton.translatesAutoresizingMaskIntoConstraints = false

    let logText = UILabel()
    logText.numberOfLines = 0
    logText.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    logText.textColor = .secondaryLabel
    logText.text = CarStatusLog.tail()
    logText.translatesAutoresizingMaskIntoConstraints = false

    logCard.addSubview(logTitle)
    logCard.addSubview(copyButton)
    logCard.addSubview(logText)
    NSLayoutConstraint.activate([
      logTitle.topAnchor.constraint(equalTo: logCard.topAnchor, constant: 14),
      logTitle.leadingAnchor.constraint(equalTo: logCard.leadingAnchor, constant: 14),
      copyButton.centerYAnchor.constraint(equalTo: logTitle.centerYAnchor),
      copyButton.trailingAnchor.constraint(equalTo: logCard.trailingAnchor, constant: -14),
      logText.topAnchor.constraint(equalTo: logTitle.bottomAnchor, constant: 10),
      logText.leadingAnchor.constraint(equalTo: logCard.leadingAnchor, constant: 14),
      logText.trailingAnchor.constraint(equalTo: logCard.trailingAnchor, constant: -14),
      logText.bottomAnchor.constraint(equalTo: logCard.bottomAnchor, constant: -14),
    ])
    stack.addArrangedSubview(logCard)
  }

  private func card(title: String, titleColor: UIColor = .label, body: String) -> UIView {
    let card = UIView()
    card.backgroundColor = .secondarySystemGroupedBackground
    card.layer.cornerRadius = 12
    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.textColor = titleColor
    titleLabel.numberOfLines = 0
    let bodyLabel = UILabel()
    bodyLabel.text = body
    bodyLabel.font = .systemFont(ofSize: 14)
    bodyLabel.textColor = .secondaryLabel
    bodyLabel.numberOfLines = 0
    let inner = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
    inner.axis = .vertical
    inner.spacing = 8
    inner.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(inner)
    NSLayoutConstraint.activate([
      inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
      inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
      inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
      inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
    ])
    return card
  }
}
