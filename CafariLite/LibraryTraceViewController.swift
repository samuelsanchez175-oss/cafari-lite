import UIKit

final class LibraryTraceViewController: UIViewController, UITableViewDataSource {
  private let table = UITableView(frame: .zero, style: .insetGrouped)
  private var events: [LibraryTraceEvent] = []

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Library log"
    view.backgroundColor = .systemGroupedBackground
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .done,
      primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
    )
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Clear",
      primaryAction: UIAction { [weak self] _ in
        LibraryTrace.shared.clear()
        self?.reload()
      }
    )
    table.dataSource = self
    table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    table.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(table)
    NSLayoutConstraint.activate([
      table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    reload()
  }

  private func reload() {
    events = LibraryTrace.shared.events
    table.reloadData()
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    max(events.count, 1)
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    var content = cell.defaultContentConfiguration()
    if events.isEmpty {
      content.text = "No library events yet."
      content.secondaryText = LibraryLog.readTail(maxLines: 8)
    } else {
      let event = events[indexPath.row]
      content.text = event.line
      content.secondaryText = event.timestamp.formatted(date: .omitted, time: .standard)
    }
    content.secondaryTextProperties.color = .secondaryLabel
    content.textProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    cell.contentConfiguration = content
    cell.selectionStyle = .none
    return cell
  }
}
