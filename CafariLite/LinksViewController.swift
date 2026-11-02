// Links. Saved-links screen; Taste colors adapt to light and dark.
// One of Stream, Web on car, and Mirror stays on.
// Web on car only sets the mode. Stream plays the current item on the car.
// Mirror shows the current page on the phone and sends that page to the car.

import Observation
import UIKit

private enum Taste {
  private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
    UIColor { traits in
      traits.userInterfaceStyle == .dark ? dark : light
    }
  }

  static let canvas = adaptive(light: .systemBackground, dark: .black)
  static let charcoal = adaptive(light: .label, dark: .white)
  static let whisper = adaptive(
    light: UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 0.7),
    dark: UIColor(white: 1, alpha: 0.12))
  /// Raised controls (search, paste row, mode pill when selected).
  static let surface = adaptive(light: .white, dark: UIColor(white: 1, alpha: 0.10))
  static let modeSelected = adaptive(light: .white, dark: UIColor(white: 1, alpha: 0.14))
  static let placeholder = adaptive(
    light: UIColor(red: 113/255, green: 113/255, blue: 122/255, alpha: 1),
    dark: UIColor(white: 1, alpha: 0.45))
  static let electric = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1)
  static let electricSubtle = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 0.08)
  static let amber = UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1)
  static let amberText = UIColor(red: 252/255, green: 211/255, blue: 77/255, alpha: 1)
  static let amberTile = UIColor(red: 120/255, green: 53/255, blue: 15/255, alpha: 0.92)
  static let yellowText = UIColor(red: 250/255, green: 204/255, blue: 21/255, alpha: 1)
  static let yellowTile = UIColor(red: 66/255, green: 32/255, blue: 6/255, alpha: 1)
  static let zinc = adaptive(light: UIColor(red: 24/255, green: 24/255, blue: 27/255, alpha: 1), dark: UIColor(white: 1, alpha: 0.10))
  static let zincIcon = UIColor(red: 161/255, green: 161/255, blue: 170/255, alpha: 1)
  static let emerald = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1)
  static let hlsBadge = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 0.85)
  static let webBadge = UIColor(red: 220/255, green: 38/255, blue: 38/255, alpha: 0.85)
}

final class LinksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
  private let store = SavedLinkStore.shared
  private var selecting = false
  private var checked: Set<UUID> = []
  private let table = UITableView(frame: .zero, style: .plain)
  private let searchField = UITextField()
  private let countLabel = UILabel()
  private let selectButton = UIButton(type: .system)
  private let carPill = UIButton(type: .system)
  private let modeButtons: [PlayMode: UIButton] = [
    .stream: UIButton(type: .system),
    .webOnCar: UIButton(type: .system),
    .mirror: UIButton(type: .system),
  ]
  private var observers: [NSObjectProtocol] = []
  private var didTraceLink = false
  private weak var chromeAdd: UIButton?
  private weak var chromeSearch: UITextField?
  private weak var chromePaste: UIButton?
  private weak var chromeCapsule: UIView?
  private weak var chromeModes: UIStackView?

  deinit {
    let center = NotificationCenter.default
    observers.forEach { center.removeObserver($0) }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = Taste.canvas

    let header = UIView()
    header.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(header)

    let title = UILabel()
    title.text = "Links"
    title.font = .systemFont(ofSize: 32, weight: .bold)
    title.textColor = Taste.charcoal
    title.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(title)

    carPill.addAction(UIAction { [weak self] _ in self?.pillTapped() }, for: .touchUpInside)
    carPill.layer.cornerRadius = 11
    carPill.layer.borderWidth = 1
    carPill.layer.borderColor = Taste.emerald.withAlphaComponent(0.20).cgColor
    carPill.backgroundColor = Taste.emerald.withAlphaComponent(0.10)
    carPill.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(carPill)

    let add = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in self?.addTapped() })
    let plus = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    add.setImage(UIImage(systemName: "plus", withConfiguration: plus), for: .normal)
    add.tintColor = Taste.charcoal
    add.backgroundColor = Taste.surface
    add.layer.cornerRadius = 18
    add.layer.borderWidth = 1
    chromeAdd = add
    add.layer.shadowColor = UIColor.black.cgColor
    add.layer.shadowOpacity = 0.04
    add.layer.shadowRadius = 3
    add.layer.shadowOffset = CGSize(width: 0, height: 1)
    add.accessibilityLabel = "Add new link"
    add.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(add)

    let modes = UIStackView()
    modes.axis = .horizontal
    modes.distribution = .fillEqually
    modes.spacing = 2
    modes.backgroundColor = Taste.charcoal.withAlphaComponent(0.04)
    modes.layer.cornerRadius = 18
    modes.layer.borderWidth = 1
    modes.layer.borderColor = Taste.whisper.cgColor
    modes.clipsToBounds = true
    chromeModes = modes
    modes.isLayoutMarginsRelativeArrangement = true
    modes.layoutMargins = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
    modes.translatesAutoresizingMaskIntoConstraints = false
    modes.accessibilityLabel = "Streaming modes"
    for mode in [PlayMode.stream, .webOnCar, .mirror] {
      guard let button = modeButtons[mode] else { continue }
      button.addAction(UIAction { [weak self] _ in self?.selectMode(mode) }, for: .touchUpInside)
      modes.addArrangedSubview(button)
    }
    header.addSubview(modes)

    searchField.placeholder = "Search YouTube"
    searchField.font = .systemFont(ofSize: 15, weight: .medium)
    searchField.textColor = Taste.charcoal
    searchField.backgroundColor = Taste.surface
    searchField.layer.cornerRadius = 18
    searchField.layer.borderWidth = 1
    chromeSearch = searchField
    searchField.returnKeyType = .search
    searchField.autocorrectionType = .no
    searchField.autocapitalizationType = .none
    searchField.clearButtonMode = .whileEditing
    searchField.delegate = self
    searchField.accessibilityLabel = "Search YouTube"
    searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 36))
    searchField.leftViewMode = .always
    searchField.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(searchField)

    let paste = UIButton(type: .custom, primaryAction: UIAction { [weak self] _ in self?.pasteTapped() })
    paste.backgroundColor = Taste.surface
    paste.layer.cornerRadius = 18
    paste.layer.borderWidth = 1
    chromePaste = paste
    paste.layer.shadowColor = UIColor.black.cgColor
    paste.layer.shadowOpacity = 0.04
    paste.layer.shadowRadius = 4
    paste.layer.shadowOffset = CGSize(width: 0, height: 1)
    paste.accessibilityLabel = "Paste video or web URL"
    paste.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(paste)

    let linkBadge = UIView()
    linkBadge.backgroundColor = Taste.electricSubtle
    linkBadge.layer.cornerRadius = 10
    linkBadge.isUserInteractionEnabled = false
    linkBadge.translatesAutoresizingMaskIntoConstraints = false
    paste.addSubview(linkBadge)
    let linkIcon = UIImageView(image: UIImage(systemName: "link"))
    linkIcon.tintColor = Taste.electric
    linkIcon.contentMode = .scaleAspectFit
    linkIcon.isUserInteractionEnabled = false
    linkIcon.translatesAutoresizingMaskIntoConstraints = false
    linkBadge.addSubview(linkIcon)
    let pasteLabel = UILabel()
    pasteLabel.text = "Paste video or web URL"
    pasteLabel.font = .systemFont(ofSize: 13, weight: .medium)
    pasteLabel.textColor = Taste.charcoal.withAlphaComponent(0.8)
    pasteLabel.lineBreakMode = .byTruncatingTail
    pasteLabel.isUserInteractionEnabled = false
    pasteLabel.translatesAutoresizingMaskIntoConstraints = false
    paste.addSubview(pasteLabel)
    pasteLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let capsule = UIView()
    capsule.backgroundColor = Taste.surface
    capsule.layer.cornerRadius = 18
    capsule.layer.borderWidth = 1
    chromeCapsule = capsule
    capsule.clipsToBounds = true
    capsule.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(capsule)

    let carPlayAll = iconButton("car", "Play all on car display") { [weak self] in self?.playAllOnCar() }
    let phonePlayAll = iconButton("iphone", "Play all on phone") { [weak self] in self?.playAllOnPhone() }
    let divider = UIView()
    divider.backgroundColor = Taste.whisper
    divider.translatesAutoresizingMaskIntoConstraints = false
    capsule.addSubview(carPlayAll)
    capsule.addSubview(divider)
    capsule.addSubview(phonePlayAll)

    countLabel.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(countLabel)

    selectButton.setTitle("Select", for: .normal)
    selectButton.setTitleColor(Taste.electric, for: .normal)
    selectButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
    selectButton.addAction(UIAction { [weak self] _ in self?.selectTapped() }, for: .touchUpInside)
    selectButton.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(selectButton)

    let hairline = UIView()
    hairline.backgroundColor = Taste.whisper
    hairline.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(hairline)

    table.dataSource = self
    table.delegate = self
    table.backgroundColor = .clear
    table.separatorColor = Taste.whisper
    table.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    table.rowHeight = 88
    table.register(LinkRowCell.self, forCellReuseIdentifier: LinkRowCell.reuseID)
    table.translatesAutoresizingMaskIntoConstraints = false
    table.contentInset.bottom = 110
    table.dragDelegate = self
    table.dropDelegate = self
    table.dragInteractionEnabled = true
    view.addSubview(table)

    NSLayoutConstraint.activate([
      header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      title.topAnchor.constraint(equalTo: header.topAnchor, constant: 8),
      title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      carPill.centerYAnchor.constraint(equalTo: title.centerYAnchor),
      carPill.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
      carPill.heightAnchor.constraint(equalToConstant: 22),
      add.centerYAnchor.constraint(equalTo: title.centerYAnchor),
      add.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      add.widthAnchor.constraint(equalToConstant: 36),
      add.heightAnchor.constraint(equalToConstant: 36),
      modes.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
      modes.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      modes.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      modes.heightAnchor.constraint(equalToConstant: 36),
      searchField.topAnchor.constraint(equalTo: modes.bottomAnchor, constant: 10),
      searchField.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      searchField.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      searchField.heightAnchor.constraint(equalToConstant: 36),
      paste.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
      paste.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      paste.heightAnchor.constraint(equalToConstant: 36),
      capsule.centerYAnchor.constraint(equalTo: paste.centerYAnchor),
      capsule.leadingAnchor.constraint(equalTo: paste.trailingAnchor, constant: 8),
      capsule.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      capsule.heightAnchor.constraint(equalToConstant: 36),
      linkBadge.leadingAnchor.constraint(equalTo: paste.leadingAnchor, constant: 8),
      linkBadge.centerYAnchor.constraint(equalTo: paste.centerYAnchor),
      linkBadge.widthAnchor.constraint(equalToConstant: 20),
      linkBadge.heightAnchor.constraint(equalToConstant: 20),
      linkIcon.centerXAnchor.constraint(equalTo: linkBadge.centerXAnchor),
      linkIcon.centerYAnchor.constraint(equalTo: linkBadge.centerYAnchor),
      linkIcon.widthAnchor.constraint(equalToConstant: 12),
      linkIcon.heightAnchor.constraint(equalToConstant: 12),
      pasteLabel.leadingAnchor.constraint(equalTo: linkBadge.trailingAnchor, constant: 8),
      pasteLabel.trailingAnchor.constraint(equalTo: paste.trailingAnchor, constant: -8),
      pasteLabel.centerYAnchor.constraint(equalTo: paste.centerYAnchor),
      carPlayAll.leadingAnchor.constraint(equalTo: capsule.leadingAnchor),
      carPlayAll.topAnchor.constraint(equalTo: capsule.topAnchor),
      carPlayAll.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),
      carPlayAll.widthAnchor.constraint(equalToConstant: 40),
      divider.leadingAnchor.constraint(equalTo: carPlayAll.trailingAnchor),
      divider.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
      divider.widthAnchor.constraint(equalToConstant: 1),
      divider.heightAnchor.constraint(equalToConstant: 18),
      phonePlayAll.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
      phonePlayAll.trailingAnchor.constraint(equalTo: capsule.trailingAnchor),
      phonePlayAll.topAnchor.constraint(equalTo: capsule.topAnchor),
      phonePlayAll.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),
      phonePlayAll.widthAnchor.constraint(equalToConstant: 40),
      countLabel.topAnchor.constraint(equalTo: paste.bottomAnchor, constant: 16),
      countLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      countLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -10),
      selectButton.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
      selectButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      selectButton.leadingAnchor.constraint(greaterThanOrEqualTo: countLabel.trailingAnchor, constant: 8),
      hairline.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      hairline.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      hairline.bottomAnchor.constraint(equalTo: header.bottomAnchor),
      hairline.heightAnchor.constraint(equalToConstant: 1),
      table.topAnchor.constraint(equalTo: header.bottomAnchor),
      table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: .cafariLiteCarConnected, object: nil, queue: .main) { [weak self] _ in
        self?.refreshPill()
      },
      center.addObserver(forName: .cafariLiteCarDisconnected, object: nil, queue: .main) { [weak self] _ in
        self?.refreshPill()
      },
      center.addObserver(forName: .cafariLiteLinksChanged, object: nil, queue: .main) { [weak self] _ in
        self?.refreshList()
      },
      center.addObserver(forName: .cafariLitePlayModeChanged, object: nil, queue: .main) { [weak self] _ in
        self?.refreshModes()
      },
    ]
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
      self.applyChrome()
      self.setNeedsStatusBarAppearanceUpdate()
    }
    applyChrome()
    refreshPill()
    observeState()
  }

  private func applyChrome() {
    let border = Taste.whisper.resolvedColor(with: traitCollection).cgColor
    chromeAdd?.layer.borderColor = border
    chromeSearch?.layer.borderColor = border
    chromePaste?.layer.borderColor = border
    chromeCapsule?.layer.borderColor = border
    chromeModes?.layer.borderColor = border
    chromeSearch?.attributedPlaceholder = NSAttributedString(
      string: "Search YouTube",
      attributes: [.foregroundColor: Taste.placeholder.resolvedColor(with: traitCollection)])
    table.separatorColor = Taste.whisper.resolvedColor(with: traitCollection)
  }

  private func observeState() {
    withObservationTracking {
      refreshModes()
      refreshList()
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.observeState()
      }
    }
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    PhonePlayback.shared.restoreSavedSession(from: store.links)
    updateContinueBanner()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didTraceLink, ProcessInfo.processInfo.environment["CAFARI_TRACE_LINK"] == "1" else { return }
    didTraceLink = true
    guard !store.links.isEmpty else {
      Log.write("links trace no row")
      return
    }
    tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
  }

  func scrollToTop() {
    table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: true)
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    store.links.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: LinkRowCell.reuseID, for: indexPath) as! LinkRowCell
    let link = store.links[indexPath.row]
    cell.fill(link, selecting: selecting, checked: checked.contains(link.id))
    cell.onStar = { [weak self] in
      self?.store.toggleStar(link.id)
    }
    return cell
  }

  func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    guard !selecting, store.links.indices.contains(indexPath.row) else { return nil }
    let link = store.links[indexPath.row]
    let rename = UIContextualAction(style: .normal, title: "Rename") { [weak self] _, _, done in
      self?.renameLink(link)
      done(true)
    }
    rename.backgroundColor = Taste.electric
    let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
      self?.deleteLink(link)
      done(true)
    }
    let actions = UISwipeActionsConfiguration(actions: [delete, rename])
    actions.performsFirstActionWithFullSwipe = false
    return actions
  }

  func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    !selecting
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let link = store.links[indexPath.row]
    if selecting {
      if checked.contains(link.id) {
        checked.remove(link.id)
        Log.write("links select row \(link.title) checked=false")
      } else {
        checked.insert(link.id)
        Log.write("links select row \(link.title) checked=true")
      }
      tableView.reloadRows(at: [indexPath], with: .none)
      return
    }
    guard let url = link.url else {
      Log.write("links row no url \(link.title)")
      return
    }
    Log.write("links row \(link.title) mode=\(PhonePlayback.shared.mode.rawValue)")
    PhonePlayback.shared.remember(title: link.title, url: url)
    PhonePlayback.shared.setQueue(store.links, index: indexPath.row)
    switch PhonePlayback.shared.mode {
    case .stream:
      CarSender.sendDirect(url)
    case .webOnCar, .mirror:
      CarSender.sendPage(url)
      let page: UIViewController = if url.host()?.contains("youtube.") == true {
        BrowserViewController(showsStatus: true, initialURL: url)
      } else {
        PageBrowserController(url: url, title: link.title)
      }
      page.modalPresentationStyle = .fullScreen
      present(page, animated: true)
    }
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    submitSearch()
    return true
  }

  private func submitSearch() {
    let query = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !query.isEmpty else { return }
    var parts = URLComponents(string: "https://m.youtube.com/results")
    parts?.queryItems = [URLQueryItem(name: "search_query", value: query)]
    guard let url = parts?.url else { return }
    Log.write("links search \(query)")
    searchField.resignFirstResponder()
    let page = BrowserViewController(showsStatus: true, initialURL: url)
    page.modalPresentationStyle = .fullScreen
    present(page, animated: true)
  }

  private func deleteLink(_ link: SavedLink) {
    Log.write("links delete \(link.title)")
    store.delete(id: link.id)
  }

  private func renameLink(_ link: SavedLink) {
    let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
    alert.addTextField { field in
      field.text = link.title
      field.clearButtonMode = .whileEditing
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
      let title = alert.textFields?.first?.text ?? ""
      if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Log.write("links rename empty")
        return
      }
      Log.write("links rename \(link.title)")
      self?.store.rename(id: link.id, title: title)
    })
    present(alert, animated: true)
  }

  private func pillTapped() {
    guard PhonePlayback.shared.currentURL != nil else {
      Log.write("links pill no item")
      let alert = UIAlertController(title: "CarPlay", message: "No item to send.", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .cancel))
      present(alert, animated: true)
      return
    }
    Log.write("links pill mode=\(PhonePlayback.shared.mode.rawValue)")
    CarSender.sendCurrentItem()
  }

  private func addTapped() {
    let alert = UIAlertController(title: "Add new link", message: nil, preferredStyle: .alert)
    alert.addTextField { $0.placeholder = "Video or web URL" }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
      guard let raw = alert.textFields?.first?.text, let url = LinkURL.normalize(raw) else {
        Log.write("links add no url")
        return
      }
      Log.write("links add \(url.absoluteString)")
      self?.store.add(url: url)
    })
    present(alert, animated: true)
  }

  private func selectMode(_ mode: PlayMode) {
    Log.write("links mode \(mode.rawValue)")
    PhonePlayback.shared.mode = mode
    switch mode {
    case .stream:
      playCurrentOnCar(direct: true)
    case .webOnCar:
      break
    case .mirror:
      let url = PhonePlayback.shared.currentURL ?? URL(string: "https://m.youtube.com")!
      let title = PhonePlayback.shared.currentTitle ?? "YouTube"
      PhonePlayback.shared.remember(title: title, url: url)
      CarSender.sendPage(url)
      let page = PageBrowserController(url: url, title: title)
      page.modalPresentationStyle = .fullScreen
      present(page, animated: true)
    }
  }

  private func pasteTapped() {
    guard let raw = UIPasteboard.general.string, let url = LinkURL.normalize(raw) else {
      Log.write("links paste no url")
      let alert = UIAlertController(title: "Paste video or web URL", message: "The clipboard has no link.", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .cancel))
      present(alert, animated: true)
      return
    }
    Log.write("links paste \(url.absoluteString)")
    store.add(url: url)
  }

  private func playAllOnCar() {
    guard let first = store.links.first, let url = first.url else {
      Log.write("links play all on car empty")
      return
    }
    Log.write("links play all on car \(first.title)")
    PhonePlayback.shared.setQueue(store.links, index: 0)
    PhonePlayback.shared.remember(title: first.title, url: url)
    openQueue(onCar: true, send: false)
    playCurrentOnCar(direct: PhonePlayback.shared.mode == .stream)
  }

  private func playAllOnPhone() {
    guard let first = store.links.first, let url = first.url else {
      Log.write("links play all on phone empty")
      return
    }
    Log.write("links play all on phone \(first.title) direct=\(PhonePlayback.shared.mode == .stream)")
    PhonePlayback.shared.setQueue(store.links, index: 0)
    PhonePlayback.shared.remember(title: first.title, url: url)
    openQueue(onCar: false, send: false)
  }

  private func openQueue(onCar: Bool, send: Bool) {
    NotificationCenter.default.post(
      name: .cafariLiteOpenController,
      object: nil,
      userInfo: [
        "clips": PhonePlayback.shared.clipQueue(),
        "index": PhonePlayback.shared.queueIndex,
        "onCar": onCar,
        "tracksQueue": true,
        "send": send,
      ])
  }

  private func selectTapped() {
    selecting.toggle()
    if selecting {
      Log.write("links select on")
    } else {
      Log.write("links select off checked=\(checked.count)")
      checked.removeAll()
    }
    selectButton.setTitle(selecting ? "Done" : "Select", for: .normal)
    updateContinueBanner()
    table.reloadData()
  }

  private func playCurrentOnCar(direct: Bool) {
    guard let url = PhonePlayback.shared.currentURL else {
      Log.write("links play on car no item direct=\(direct)")
      return
    }
    if direct { CarSender.sendDirect(url) } else { CarSender.sendPage(url) }
  }

  private func refreshList() {
    let text = "SAVED · PLAY ON CAR DISPLAY (\(store.links.count))"
    countLabel.attributedText = NSAttributedString(string: text, attributes: [
      .font: UIFont.systemFont(ofSize: 11, weight: .bold),
      .foregroundColor: Taste.charcoal.withAlphaComponent(0.5),
      .kern: 1.1,
    ])
    updateContinueBanner()
    table.reloadData()
  }

  private func updateContinueBanner() {
    guard !selecting,
          let title = PhonePlayback.shared.currentTitle,
          PhonePlayback.shared.currentURL != nil else {
      if table.tableHeaderView != nil { table.tableHeaderView = nil }
      return
    }
    let trimmed = title.count > 42 ? String(title.prefix(39)) + "…" : title
    let button = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
      self?.resumeLastLink()
    })
    var config = UIButton.Configuration.plain()
    config.title = "Continue · \(trimmed)"
    config.image = UIImage(systemName: "play.fill")
    config.imagePadding = 8
    config.imagePlacement = .leading
    config.baseForegroundColor = Taste.electric
    config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    button.configuration = config
    button.contentHorizontalAlignment = .leading
    button.backgroundColor = Taste.electricSubtle
    let header = UIView(frame: CGRect(x: 0, y: 0, width: table.bounds.width, height: 44))
    button.frame = header.bounds
    button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    header.addSubview(button)
    table.tableHeaderView = header
  }

  private func resumeLastLink() {
    let playback = PhonePlayback.shared
    guard let url = playback.currentURL else { return }
    let index = min(playback.queueIndex, max(0, store.links.count - 1))
    playback.setQueue(store.links, index: index)
    playback.remember(title: playback.currentTitle ?? "Video", url: url)
    Log.write("links resume \(playback.currentTitle ?? "-")")
    switch playback.mode {
    case .stream:
      CarSender.sendDirect(url)
      openQueue(onCar: true, send: false)
    case .webOnCar, .mirror:
      CarSender.sendPage(url)
      let page: UIViewController = if url.host()?.contains("youtube.") == true {
        BrowserViewController(showsStatus: true, initialURL: url)
      } else {
        PageBrowserController(url: url, title: playback.currentTitle ?? "Link")
      }
      page.modalPresentationStyle = .fullScreen
      present(page, animated: true)
    }
  }

  private func refreshPill() {
    var config = UIButton.Configuration.plain()
    config.title = "CarPlay"
    config.image = Self.emeraldDot
    config.imagePadding = 5
    config.imagePlacement = .leading
    config.baseForegroundColor = Taste.charcoal.withAlphaComponent(0.7)
    config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var out = incoming
      out.font = .systemFont(ofSize: 11, weight: .medium)
      return out
    }
    carPill.configuration = config
  }

  private static let emeraldDot: UIImage = {
    let size = CGSize(width: 6, height: 6)
    return UIGraphicsImageRenderer(size: size).image { _ in
      Taste.emerald.setFill()
      UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
    }.withRenderingMode(.alwaysOriginal)
  }()

  private func refreshModes() {
    let current = PhonePlayback.shared.mode
    for (mode, button) in modeButtons {
      let on = mode == current
      var config = UIButton.Configuration.plain()
      config.title = titleFor(mode)
      config.cornerStyle = .capsule
      config.baseForegroundColor = on ? Taste.electric : Taste.charcoal.withAlphaComponent(0.6)
      config.background.backgroundColor = on ? Taste.modeSelected : .clear
      config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var out = incoming
        out.font = .systemFont(ofSize: 13, weight: .semibold)
        return out
      }
      if on && mode == .webOnCar {
        config.image = UIImage(systemName: "globe")
        config.imagePadding = 4
        config.imagePlacement = .leading
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
      }
      button.configuration = config
    }
  }

  private func titleFor(_ mode: PlayMode) -> String {
    switch mode {
    case .stream: "Stream"
    case .webOnCar: "Web on car"
    case .mirror: "Mirror"
    }
  }

  private func iconButton(_ symbol: String, _ access: String, _ handler: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system, primaryAction: UIAction { _ in handler() })
    let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    button.setImage(UIImage(systemName: symbol, withConfiguration: config), for: .normal)
    button.tintColor = Taste.charcoal.withAlphaComponent(0.8)
    button.accessibilityLabel = access
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }
}

extension LinksViewController: UITableViewDragDelegate, UITableViewDropDelegate {
  func tableView(
    _ tableView: UITableView,
    itemsForBeginning session: UIDragSession,
    at indexPath: IndexPath
  ) -> [UIDragItem] {
    guard !selecting, store.links.indices.contains(indexPath.row) else { return [] }
    let link = store.links[indexPath.row]
    let item = UIDragItem(itemProvider: NSItemProvider(object: link.id.uuidString as NSString))
    item.localObject = link.id
    return [item]
  }

  func tableView(
    _ tableView: UITableView,
    dropSessionDidUpdate session: UIDropSession,
    withDestinationIndexPath destinationIndexPath: IndexPath?
  ) -> UITableViewDropProposal {
    guard !selecting, session.localDragSession != nil else {
      return UITableViewDropProposal(operation: .cancel)
    }
    return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
  }

  func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
    guard !selecting,
          let item = coordinator.items.first,
          let source = item.sourceIndexPath,
          let id = item.dragItem.localObject as? UUID,
          store.links.indices.contains(source.row) else { return }
    let proposed = coordinator.destinationIndexPath?.row ?? store.links.count
    var destination = proposed
    if source.row < destination { destination -= 1 }
    if destination >= store.links.count { destination = store.links.count - 1 }
    guard store.links.indices.contains(destination) else { return }
    Log.write("links move \(store.links[source.row].title) to \(destination)")
    store.move(id: id, to: destination)
    coordinator.drop(item.dragItem, toRowAt: IndexPath(row: destination, section: 0))
  }
}

private final class LinkRowCell: UITableViewCell {
  static let reuseID = "LinkRowCell"
  var onStar: (() -> Void)?
  private let thumb = LinkThumbView()
  private let nameLabel = UILabel()
  private let star = UIButton(type: .system)
  private let check = UIImageView()
  private var titleGap: NSLayoutConstraint!

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    backgroundColor = .clear
    contentView.backgroundColor = .clear
    let selected = UIView()
    selected.backgroundColor = Taste.charcoal.withAlphaComponent(0.02)
    selectedBackgroundView = selected

    thumb.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(thumb)

    nameLabel.font = .systemFont(ofSize: 14, weight: .regular)
    nameLabel.textColor = Taste.charcoal
    nameLabel.numberOfLines = 2
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(nameLabel)

    star.accessibilityLabel = "Favorite item"
    star.addAction(UIAction { [weak self] _ in self?.onStar?() }, for: .touchUpInside)
    star.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(star)

    check.translatesAutoresizingMaskIntoConstraints = false
    check.tintColor = Taste.electric
    contentView.addSubview(check)

    titleGap = nameLabel.trailingAnchor.constraint(equalTo: star.leadingAnchor, constant: -8)
    NSLayoutConstraint.activate([
      thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      thumb.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      thumb.widthAnchor.constraint(equalToConstant: 120),
      thumb.heightAnchor.constraint(equalToConstant: 68),
      nameLabel.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
      nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      titleGap,
      star.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
      star.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      star.widthAnchor.constraint(equalToConstant: 32),
      star.heightAnchor.constraint(equalToConstant: 32),
      check.trailingAnchor.constraint(equalTo: star.leadingAnchor, constant: -2),
      check.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      check.widthAnchor.constraint(equalToConstant: 22),
      check.heightAnchor.constraint(equalToConstant: 22),
    ])
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  func fill(_ link: SavedLink, selecting: Bool, checked: Bool) {
    nameLabel.text = link.title
    thumb.apply(style: Self.style(for: link), duration: link.durationLabel, imageURL: link.thumbImageURL)
    let symbol = link.starred ? "star.fill" : "star"
    let starImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
    star.setImage(UIImage(systemName: symbol, withConfiguration: starImage), for: .normal)
    star.tintColor = link.starred ? Taste.amber : Taste.charcoal.withAlphaComponent(0.3)
    check.isHidden = !selecting
    check.image = UIImage(systemName: checked ? "checkmark.circle.fill" : "circle")
    titleGap.constant = selecting ? -32 : -8
  }

  private static func style(for link: SavedLink) -> String {
    if let style = link.thumbStyle, !style.isEmpty { return style }
    let host = (link.url?.host() ?? "").lowercased()
    if link.urlString.contains("m3u8") { return "hls" }
    if link.url.flatMap({ BrowserViewController.youtubeID(for: $0) }) != nil { return "youtube" }
    if host.contains("youtu") { return "web" }
    return "video"
  }
}

private final class LinkThumbView: UIView {
  private let gradient = CAGradientLayer()
  private let photo = UIImageView()
  private let caption = UILabel()
  private let icon = UIImageView()
  private let playCard = UIView()
  private let badge = UILabel()
  private var imageTask: Task<Void, Never>?
  private var imageToken = UUID()

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.cornerRadius = 12
    layer.borderWidth = 1
    clipsToBounds = true
    layer.insertSublayer(gradient, at: 0)

    photo.contentMode = .scaleAspectFill
    photo.clipsToBounds = true
    photo.isHidden = true
    photo.translatesAutoresizingMaskIntoConstraints = false
    insertSubview(photo, at: 0)

    caption.textAlignment = .center
    caption.numberOfLines = 2
    caption.translatesAutoresizingMaskIntoConstraints = false
    addSubview(caption)

    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    addSubview(icon)

    playCard.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.8)
    playCard.layer.cornerRadius = 3
    playCard.layer.borderWidth = 1
    playCard.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
    playCard.translatesAutoresizingMaskIntoConstraints = false
    addSubview(playCard)
    let play = UIImageView(image: UIImage(systemName: "play.fill"))
    play.tintColor = Taste.electric
    play.contentMode = .scaleAspectFit
    play.translatesAutoresizingMaskIntoConstraints = false
    playCard.addSubview(play)

    badge.font = .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
    badge.textAlignment = .center
    badge.layer.cornerRadius = 3
    badge.clipsToBounds = true
    badge.translatesAutoresizingMaskIntoConstraints = false
    addSubview(badge)
    refreshBorder()

    NSLayoutConstraint.activate([
      photo.leadingAnchor.constraint(equalTo: leadingAnchor),
      photo.trailingAnchor.constraint(equalTo: trailingAnchor),
      photo.topAnchor.constraint(equalTo: topAnchor),
      photo.bottomAnchor.constraint(equalTo: bottomAnchor),
      caption.centerXAnchor.constraint(equalTo: centerXAnchor),
      caption.centerYAnchor.constraint(equalTo: centerYAnchor),
      caption.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
      caption.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
      icon.centerXAnchor.constraint(equalTo: centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 24),
      icon.heightAnchor.constraint(equalToConstant: 24),
      playCard.centerXAnchor.constraint(equalTo: centerXAnchor),
      playCard.centerYAnchor.constraint(equalTo: centerYAnchor),
      playCard.widthAnchor.constraint(equalToConstant: 28),
      playCard.heightAnchor.constraint(equalToConstant: 36),
      play.centerXAnchor.constraint(equalTo: playCard.centerXAnchor),
      play.centerYAnchor.constraint(equalTo: playCard.centerYAnchor),
      play.widthAnchor.constraint(equalToConstant: 12),
      play.heightAnchor.constraint(equalToConstant: 12),
      badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      badge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
      badge.heightAnchor.constraint(equalToConstant: 14),
    ])
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  override func layoutSubviews() {
    super.layoutSubviews()
    gradient.frame = bounds
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
    refreshBorder()
  }

  private func refreshBorder() {
    layer.borderColor = Taste.whisper.resolvedColor(with: traitCollection).cgColor
  }

  func apply(style: String, duration: String?, imageURL: URL? = nil) {
    imageTask?.cancel()
    imageTask = nil
    let token = UUID()
    imageToken = token
    photo.image = nil
    photo.isHidden = true
    caption.isHidden = true
    icon.isHidden = true
    playCard.isHidden = true
    badge.isHidden = true
    gradient.isHidden = true
    switch style {
    case "youtube":
      backgroundColor = Taste.zinc
      playCard.isHidden = false
      showWash(bottomHeavy: false)
      showDuration(duration)
      if let imageURL {
        loadPhoto(from: imageURL, token: token)
      }
    case "kt789":
      backgroundColor = Taste.amberTile
      caption.isHidden = false
      caption.text = "KT #789"
      caption.textColor = Taste.amberText
      caption.font = .systemFont(ofSize: 12, weight: .black)
      showWash(bottomHeavy: true)
      showDuration(duration)
    case "kt780":
      backgroundColor = Taste.yellowTile
      caption.isHidden = false
      caption.text = "KT #780 · FLUFFY"
      caption.textColor = Taste.yellowText
      caption.font = .systemFont(ofSize: 10, weight: .black)
      showWash(bottomHeavy: true)
      showDuration(duration)
    case "hls":
      backgroundColor = Taste.zinc
      icon.isHidden = false
      icon.image = UIImage(systemName: "film")
      icon.tintColor = Taste.zincIcon
      showWord("HLS", color: Taste.hlsBadge)
    case "web":
      backgroundColor = Taste.zinc
      icon.isHidden = false
      icon.image = UIImage(systemName: "globe")
      icon.tintColor = Taste.zincIcon
      showWord("WEB", color: Taste.webBadge)
    default:
      backgroundColor = Taste.zinc
      playCard.isHidden = false
      showWash(bottomHeavy: false)
      showDuration(duration)
    }
  }

  private func showWash(bottomHeavy: Bool) {
    gradient.isHidden = false
    if bottomHeavy {
      gradient.colors = [
        UIColor.black.withAlphaComponent(0.85).cgColor,
        UIColor.black.withAlphaComponent(0.25).cgColor,
        UIColor.clear.cgColor,
      ]
      gradient.startPoint = CGPoint(x: 0.5, y: 1)
      gradient.endPoint = CGPoint(x: 0.5, y: 0)
    } else {
      gradient.colors = [
        UIColor.black.withAlphaComponent(0.8).cgColor,
        UIColor.clear.cgColor,
      ]
      gradient.startPoint = CGPoint(x: 0, y: 1)
      gradient.endPoint = CGPoint(x: 1, y: 0)
    }
  }

  private func showDuration(_ text: String?) {
    guard let text, !text.isEmpty else { return }
    badge.isHidden = false
    badge.text = " \(text) "
    badge.textColor = UIColor.white.withAlphaComponent(0.9)
    badge.backgroundColor = UIColor.black.withAlphaComponent(0.75)
    badge.font = .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
  }

  private func showWord(_ text: String, color: UIColor) {
    badge.isHidden = false
    badge.text = " \(text) "
    badge.textColor = .white
    badge.backgroundColor = color
    badge.font = .monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
  }

  private func loadPhoto(from url: URL, token: UUID) {
    imageTask = Task { @MainActor in
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard !Task.isCancelled, imageToken == token,
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let image = UIImage(data: data) else {
          return
        }
        photo.image = image
        photo.isHidden = false
      } catch {
        Log.write("link thumb load fail \(url.absoluteString)")
      }
    }
  }
}
