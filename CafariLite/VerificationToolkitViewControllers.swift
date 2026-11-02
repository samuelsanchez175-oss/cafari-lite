import UIKit

enum VerificationDiagnostics {
  static func lastPlaybackErrorLine() -> String {
    let lines = Log.lines(for: .playbackErrors)
    guard let last = lines.last else { return "None this session" }
    if last.count > 120 { return String(last.prefix(117)) + "…" }
    return last
  }

  static func gateStateOneLiner() -> String {
    guard Settings.playOnlyWhenParked else { return "Gate off (setting disabled)" }
    if !CarGate.shared.isLocationUsable {
      return "Gate on · location \(CarGate.shared.locationAuthorizationLabel) · treats as parked"
    }
    return CarGate.shared.isMoving ? "Gate on · moving (cover active)" : "Gate on · parked"
  }
}

// MARK: - Pre-drive checklist

final class PreDriveChecklistViewController: UITableViewController {
  private enum Row: Int, CaseIterable {
    case signing
    case carConnected
    case playbackErrors
    case gate
    case lastError
  }

  init() {
    super.init(style: .insetGrouped)
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Pre-drive checklist"
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .done,
      primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Refresh",
      primaryAction: UIAction { [weak self] _ in self?.refresh() })
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    refresh()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refresh()
  }

  private func refresh() {
    _ = CarPlayEntitlementDoctor.shared.audit(reason: "pre-drive-checklist")
    tableView.reloadData()
  }

  override func numberOfSections(in tableView: UITableView) -> Int { 1 }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    Row.allCases.count
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    "Run this before a drive test. CarPlay signing needs a device build with video and audio entitlements."
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    cell.selectionStyle = .none
    var content = UIListContentConfiguration.subtitleCell()
    guard let row = Row(rawValue: indexPath.row) else { return cell }

    switch row {
    case .signing:
      let ready = CarPlayEntitlementDoctor.shared.lastReport?.carPlayReady ?? false
      content.text = "CarPlay signing"
      content.secondaryText = ready ? "Entitled ✓" : "Not entitled — open Diagnostics → CarPlay signing"
      content.secondaryTextProperties.color = ready ? .systemGreen : .systemOrange
    case .carConnected:
      content.text = "Car connected"
      content.secondaryText = CarSessionState.isConnected
        ? "Connected ✓ · \(CarSessionState.carSizeHint)"
        : "Not connected — plug in CarPlay"
      content.secondaryTextProperties.color = CarSessionState.isConnected ? .systemGreen : .secondaryLabel
    case .playbackErrors:
      let count = SessionCounts.playbackErrorCount
      content.text = "Playback errors (session)"
      content.secondaryText = count == 0 ? "0 ✓" : "\(count) — see Diagnostics → Playback errors"
      content.secondaryTextProperties.color = count == 0 ? .systemGreen : .systemOrange
    case .gate:
      content.text = "Parked gate"
      content.secondaryText = VerificationDiagnostics.gateStateOneLiner()
    case .lastError:
      content.text = "Last playback error"
      content.secondaryText = VerificationDiagnostics.lastPlaybackErrorLine()
      content.secondaryTextProperties.color = .secondaryLabel
    }

    cell.contentConfiguration = content
    return cell
  }
}

// MARK: - Link metadata test

final class LinkMetadataTestViewController: UIViewController {
  private let urlField = UITextField()
  private let runButton = UIButton(type: .system)
  private let resultView = UITextView()
  private let thumbView = UIImageView()
  private var loadTask: Task<Void, Never>?

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  deinit { loadTask?.cancel() }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Test link metadata"
    view.backgroundColor = .systemGroupedBackground
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .done,
      primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })

    urlField.placeholder = "Paste YouTube URL"
    urlField.borderStyle = .roundedRect
    urlField.autocapitalizationType = .none
    urlField.autocorrectionType = .no
    urlField.keyboardType = .URL
    urlField.clearButtonMode = .whileEditing
    urlField.translatesAutoresizingMaskIntoConstraints = false

    var runConfig = UIButton.Configuration.filled()
    runConfig.title = "Fetch metadata"
    runButton.configuration = runConfig
    runButton.addAction(UIAction { [weak self] _ in self?.runTest() }, for: .touchUpInside)
    runButton.translatesAutoresizingMaskIntoConstraints = false

    thumbView.contentMode = .scaleAspectFill
    thumbView.clipsToBounds = true
    thumbView.layer.cornerRadius = 8
    thumbView.backgroundColor = .secondarySystemFill
    thumbView.translatesAutoresizingMaskIntoConstraints = false

    resultView.isEditable = false
    resultView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    resultView.backgroundColor = .secondarySystemGroupedBackground
    resultView.layer.cornerRadius = 10
    resultView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
    resultView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(urlField)
    view.addSubview(runButton)
    view.addSubview(thumbView)
    view.addSubview(resultView)

    NSLayoutConstraint.activate([
      urlField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      urlField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      urlField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      runButton.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 12),
      runButton.leadingAnchor.constraint(equalTo: urlField.leadingAnchor),
      thumbView.topAnchor.constraint(equalTo: runButton.bottomAnchor, constant: 16),
      thumbView.leadingAnchor.constraint(equalTo: urlField.leadingAnchor),
      thumbView.widthAnchor.constraint(equalToConstant: 120),
      thumbView.heightAnchor.constraint(equalToConstant: 68),
      resultView.topAnchor.constraint(equalTo: thumbView.bottomAnchor, constant: 12),
      resultView.leadingAnchor.constraint(equalTo: urlField.leadingAnchor),
      resultView.trailingAnchor.constraint(equalTo: urlField.trailingAnchor),
      resultView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
    ])

    resultView.text = "Paste a URL and tap Fetch. Uses the same oEmbed + duration path as Links."
  }

  private func runTest() {
    loadTask?.cancel()
    guard let raw = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
          let url = LinkURL.normalize(raw) else {
      resultView.text = "Enter a valid URL."
      return
    }
    runButton.isEnabled = false
    resultView.text = "Fetching…"
    thumbView.image = nil
    loadTask = Task { @MainActor [weak self] in
      let diag = await YouTubeLinkMetadata.resolveDiagnostic(url: url)
      guard !Task.isCancelled, let self else { return }
      self.runButton.isEnabled = true
      if let resolved = diag.resolved {
        self.thumbView.image = await Self.loadThumb(resolved.thumbImageURL)
        var lines = [
          "Title: \(resolved.title)",
          "Thumb: \(resolved.thumbImageURL.absoluteString)",
          "Duration: \(resolved.durationLabel ?? "—")",
          "",
          "Timing:",
          "  oEmbed: \(diag.oEmbedMilliseconds.map { "\($0) ms" } ?? "—")",
          "  duration scrape: \(diag.durationMilliseconds.map { "\($0) ms" } ?? "—")",
          "  total: \(diag.totalMilliseconds) ms",
        ]
        if !diag.errorNotes.isEmpty {
          lines.append("")
          lines.append("Notes:")
          diag.errorNotes.forEach { lines.append("  · \($0)") }
        }
        self.resultView.text = lines.joined(separator: "\n")
      } else {
        self.resultView.text = (diag.errorNotes + ["Total: \(diag.totalMilliseconds) ms"]).joined(separator: "\n")
      }
      Log.write("verify link metadata \(url.absoluteString) total=\(diag.totalMilliseconds)ms")
    }
  }

  private static func loadThumb(_ url: URL) async -> UIImage? {
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      return UIImage(data: data)
    } catch {
      return nil
    }
  }
}

// MARK: - YouTube resolve stub

final class YouTubeResolveDiagnosticsViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "YouTube resolve"
    view.backgroundColor = .systemBackground
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .done,
      primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })

    let label = UILabel()
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = .secondaryLabel
    label.font = .preferredFont(forTextStyle: .body)
    label.text = "Coming soon\n\nStream-mode innertube resolve trace (Reels parity) will log last attempt here."
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
    ])
  }
}
