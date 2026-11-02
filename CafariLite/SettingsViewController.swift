import Photos
import UIKit

final class SettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case appearance
        case ambient
        case audio
        case youtube
        case phoneAndCar
        case wallpaper
        case display
        case playback
        case shortcuts
        case diagnostics
        case advanced
        case legal
    }

    private let appearanceControl = UISegmentedControl(items: ["System", "Light", "Dark"])
    private var carObservers: [NSObjectProtocol] = []

    deinit {
        carObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.contentInset.bottom = 112
        tableView.verticalScrollIndicatorInsets.bottom = 112
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BasicCell")
        tableView.register(SettingsSwitchCell.self, forCellReuseIdentifier: SettingsSwitchCell.reuseIdentifier)
        tableView.register(SettingsDetailCell.self, forCellReuseIdentifier: SettingsDetailCell.reuseIdentifier)

        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 64))
        let titleLabel = UILabel()
        titleLabel.text = "Settings"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8)
        ])
        tableView.tableHeaderView = header

        appearanceControl.selectedSegmentIndex = min(max(Settings.appearanceIndex, 0), 2)
        appearanceControl.addAction(UIAction { [weak self] _ in self?.appearanceChanged() }, for: .valueChanged)

        let center = NotificationCenter.default
        carObservers = [
            center.addObserver(forName: .cafariLiteCarConnected, object: nil, queue: .main) { [weak self] _ in
                self?.tableView.reloadData()
            },
            center.addObserver(forName: .cafariLiteCarDisconnected, object: nil, queue: .main) { [weak self] _ in
                self?.tableView.reloadData()
            },
            center.addObserver(forName: .cafariLitePlayModeChanged, object: nil, queue: .main) { [weak self] _ in
                self?.tableView.reloadSections(IndexSet(integer: Section.phoneAndCar.rawValue), with: .none)
            },
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        YouTubeAccountManager.shared.checkStatus()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        return switch section {
        case .appearance, .ambient: 1
        case .audio: 2
        case .youtube: YouTubeAccountManager.shared.isSignedIn ? 2 : 1
        case .phoneAndCar: 4
        case .wallpaper: 2
        case .display, .playback: 5
        case .shortcuts: 2
        case .diagnostics: 6
        case .advanced: 6
        case .legal: 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        return switch section {
        case .appearance: "APPEARANCE"
        case .ambient: "AMBIENT"
        case .audio: "AUDIO & ACOUSTIC PROFILES"
        case .youtube: "YOUTUBE ACCOUNT"
        case .phoneAndCar: "PHONE & CAR"
        case .wallpaper: "WALLPAPER & IDLE"
        case .display: "CARPLAY DISPLAY"
        case .playback: "PLAYBACK & AUDIO"
        case .shortcuts: "SHARE & SHORTCUTS"
        case .diagnostics: "DIAGNOSTICS & LOGS"
        case .advanced: "ADVANCED"
        case .legal: "LEGAL"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        return switch section {
        case .ambient:
            "Projects dynamic blue ambient lighting behind the dock."
        case .audio:
            "Presets are saved on this device. Cafari Lite does not apply EQ or spatial DSP to playback yet (Reels parity at preference level)."
        case .youtube:
            "Signed-in sessions use the same WebKit store as the car browser, so subscriptions and history appear on CarPlay after reload."
        case .phoneAndCar:
            "Same controls as Links — photos for Library, streaming mode, and play-all on the car display."
        case .shortcuts:
            "Share from Safari or YouTube into Cafari Lite. Paste the prompt in Shortcuts under Describe a shortcut."
        case .wallpaper:
            "Choose what fills the car home screen behind your starred links. Full-Screen Mode only affects the in-car browser toolbar."
        case .display:
            "Wallpaper Shortcuts shows Maps, Music, Phone, and Dashboard next to your starred links."
        case .diagnostics:
            "Capture real-time playback events and UI states."
        case .advanced:
            "Verification and debug tools from the toolkit. HUDs stay off until you enable them."
        case .legal:
            "Cafari replaces Reels Sync. One CarPlay app on this device: com.samuelsanchez.ytos27."
        default:
            nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .appearance:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
            cell.selectionStyle = .none
            var content = cell.defaultContentConfiguration()
            content.text = "Theme"
            cell.contentConfiguration = content
            cell.accessoryView = appearanceControl
            return cell
        case .ambient:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
            cell.configure(
                title: "Ambient Light Sync",
                subtitle: "Dynamic blue edge glow",
                isOn: Settings.ambientLightSync
            ) { isOn in
                Settings.ambientLightSync = isOn
                Log.write("settings Ambient Light Sync=\(isOn)")
                NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
            }
            return cell
        case .audio:
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
                cell.configure(title: "Equalizer Preset", detail: Settings.audioEQPreset.rawValue)
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
            cell.configure(
                title: "Spatial Surround Audio",
                subtitle: "Immersive cabin profile",
                isOn: Settings.spatialAudioEnabled
            ) { isOn in
                Settings.spatialAudioEnabled = isOn
                Log.write("settings Spatial Surround Audio=\(isOn)")
                NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
            }
            return cell
        case .youtube:
            if YouTubeAccountManager.shared.isSignedIn {
                if indexPath.row == 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
                    cell.configure(title: "YouTube Account", detail: "Signed In")
                    cell.accessoryType = .none
                    return cell
                }
                let cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
                var content = cell.defaultContentConfiguration()
                content.text = "Sign Out of YouTube"
                content.textProperties.color = .systemRed
                cell.contentConfiguration = content
                cell.accessoryType = .none
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
            cell.configure(title: "YouTube Account", detail: "Sign In")
            return cell
        case .phoneAndCar:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch indexPath.row {
            case 0:
                cell.configure(title: "Photos Access", detail: PhotosAccessSettings.statusLabel(for: status))
            case 1:
                cell.configure(title: "Car Display", detail: CarSessionState.displayHint)
                cell.accessoryType = .none
                cell.selectionStyle = .none
            case 2:
                cell.configure(title: "YouTube on Car", detail: youtubeModeLabel(PhonePlayback.shared.mode))
            default:
                cell.configure(title: "Play All on Car", detail: SavedLinksPlayback.playAllDetail())
            }
            return cell
        case .wallpaper:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
            if indexPath.row == 0 {
                cell.configure(title: "Wallpaper & Ambient", detail: IdleLookStore.shared.selectedLook.title)
            } else {
                cell.configure(title: "Run wallpaper setup again", detail: "")
            }
            return cell
        case .display:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
            let rows: [(String, String?, Bool, (Bool) -> Void)] = [
                ("Wallpaper Shortcuts", "Maps, Music, Phone, Dashboard", Settings.wallpaperShortcuts, {
                    Settings.wallpaperShortcuts = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Native CarPlay Resolution", "Pixel-perfect scaling", Settings.carNativeResolution, {
                    Settings.carNativeResolution = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Keep Clear of Sidebar", "Respect safe area", Settings.avoidSidebar, {
                    Settings.avoidSidebar = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Full-Screen Mode", "Hide CarPlay status bar", Settings.fullScreenCar, {
                    Settings.fullScreenCar = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Show Debug Border", "Green layout frame", Settings.debugBorder, {
                    Settings.debugBorder = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                })
            ]
            let row = rows[indexPath.row]
            cell.configure(title: row.0, subtitle: row.1, isOn: row.2) { isOn in
                row.3(isOn)
                Log.write("settings \(row.0)=\(isOn)")
            }
            return cell
        case .playback:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
            let rows: [(String, String?, Bool, (Bool) -> Void)] = [
                ("Play Only When Parked", "Pause when moving", Settings.playOnlyWhenParked, {
                    Settings.playOnlyWhenParked = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Autoplay Next Video", nil, Settings.autoplayNextVideo, {
                    Settings.autoplayNextVideo = $0
                }),
                ("Auto-Play YouTube Queue", nil, Settings.autoPlayYouTubeQueue, {
                    Settings.autoPlayYouTubeQueue = $0
                }),
                ("Mini Player", "Keep playing when collapsed", Settings.miniPlayer, {
                    Settings.miniPlayer = $0
                }),
                ("Show Captions", nil, Settings.showCaptions, {
                    Settings.showCaptions = $0
                })
            ]
            let row = rows[indexPath.row]
            cell.configure(title: row.0, subtitle: row.1, isOn: row.2) { isOn in
                row.3(isOn)
                Log.write("settings \(row.0)=\(isOn)")
            }
            return cell
        case .shortcuts:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
            if indexPath.row == 0 {
                cell.configure(title: "Create Shortcut", detail: "Copy prompt")
            } else {
                cell.configure(title: "Add to Action Button", detail: "Side button")
            }
            return cell
        case .advanced:
            if indexPath.row == 2 || indexPath.row == 3 || indexPath.row == 4 {
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
                let rows: [(String, String?, Bool, (Bool) -> Void)] = [
                    ("Show parked-gate HUD", "Car browser overlay", Settings.showParkedGateHUD, {
                        Settings.showParkedGateHUD = $0
                        NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                    }),
                    ("Show Links status HUD", "Mode, queue, last send", Settings.showLinksStatusHUD, {
                        Settings.showLinksStatusHUD = $0
                        NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                    }),
                    ("Sidebar safe-area overlay", "Car WebView sidebar inset", Settings.showSidebarSafeAreaOverlay, {
                        Settings.showSidebarSafeAreaOverlay = $0
                        NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                    }),
                ]
                let row = rows[indexPath.row - 2]
                cell.configure(title: row.0, subtitle: row.1, isOn: row.2) { isOn in
                    row.3(isOn)
                    Log.write("settings advanced \(row.0)=\(isOn)")
                }
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
            switch indexPath.row {
            case 0:
                cell.configure(title: "Pre-drive checklist", detail: "Open")
            case 1:
                cell.configure(title: "Test link metadata", detail: "Paste URL")
            default:
                cell.configure(title: "YouTube resolve diagnostics", detail: "Coming soon")
            }
            return cell
        case .diagnostics:
            if indexPath.row == 4 {
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
                cell.configure(
                    title: "Verbose library logging",
                    subtitle: "library-status.txt + in-app trace",
                    isOn: Settings.libraryVerboseLogging
                ) { isOn in
                    Settings.libraryVerboseLogging = isOn
                    Log.write("settings library verbose=\(isOn)")
                }
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
            switch indexPath.row {
            case 0:
                cell.configure(title: "Playback errors", detail: "\(SessionCounts.playbackErrorCount) this session")
            case 1:
                cell.configure(title: "Car Action Log", detail: "\(SessionCounts.carActionCount) events")
            case 2:
                cell.configure(title: "Player Bug Catcher", detail: "\(SessionCounts.playerFaultCount) faults")
            case 3:
                let ready = CarPlayEntitlementDoctor.shared.lastReport?.carPlayReady ?? false
                cell.configure(title: "CarPlay signing", detail: ready ? "Entitled" : "Check")
            default:
                cell.configure(title: "Library log", detail: "\(LibraryTrace.shared.events.count) events")
            }
            return cell
        case .legal:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = indexPath.row == 0 ? "Privacy Policy" : "Terms of Service"
            cell.contentConfiguration = content
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .audio:
            if indexPath.row == 0 {
                presentEQPicker()
            }
        case .youtube:
            if YouTubeAccountManager.shared.isSignedIn {
                if indexPath.row == 1 {
                    confirmYouTubeSignOut()
                }
            } else {
                Log.write("settings youtube sign in")
                let signIn = YouTubeSignInController()
                signIn.modalPresentationStyle = .formSheet
                present(signIn, animated: true)
            }
        case .phoneAndCar:
            switch indexPath.row {
            case 0:
                PhotosAccessSettings.handle(from: self)
                tableView.reloadRows(at: [IndexPath(row: 0, section: Section.phoneAndCar.rawValue)], with: .none)
            case 1:
                break
            case 2:
                presentYouTubeModePicker()
            default:
                playAllFromSettings()
            }
        case .shortcuts:
            if indexPath.row == 0 {
                ShortcutsSupport.copyPromptAndOpenShortcuts { [weak self] message in
                    self?.showNotice(message)
                }
            } else {
                let help = UINavigationController(rootViewController: ActionButtonHelpViewController())
                present(help, animated: true)
            }
        case .wallpaper:
            if indexPath.row == 0 {
                Log.write("settings open wallpaper hub")
                present(WallpaperHubFactory.makeNavigationHub(), animated: true)
            } else {
                Log.write("settings wallpaper setup again")
                let setup = WallpaperHubFactory.makeSetupSheet()
                setup.modalPresentationStyle = .formSheet
                present(setup, animated: true)
            }
        case .advanced:
            switch indexPath.row {
            case 0:
                present(UINavigationController(rootViewController: PreDriveChecklistViewController()), animated: true)
            case 1:
                present(UINavigationController(rootViewController: LinkMetadataTestViewController()), animated: true)
            case 5:
                present(UINavigationController(rootViewController: YouTubeResolveDiagnosticsViewController()), animated: true)
            default:
                break
            }
        case .diagnostics:
            switch indexPath.row {
            case 0, 1, 2:
                let titles = ["Playback errors", "Car Action Log", "Player Bug Catcher"]
                let title = titles[indexPath.row]
                let slice = LogSlice(title: title)
                let count = slice.map { Log.lines(for: $0).count } ?? 0
                Log.write("settings diagnostics \(title) lines=\(count)")
                let viewer = UINavigationController(rootViewController: SettingsLogController(pageTitle: title))
                present(viewer, animated: true)
            case 3:
                let panel = UINavigationController(rootViewController: CarPlaySigningViewController())
                present(panel, animated: true)
            case 4:
                break
            default:
                let viewer = UINavigationController(rootViewController: LibraryTraceViewController())
                present(viewer, animated: true)
            }
        case .legal:
            let title = indexPath.row == 0 ? "Privacy Policy" : "Terms of Service"
            Log.write("settings legal \(title)")
            let message = indexPath.row == 0
                ? "Cafari Lite keeps your saved links and settings on this device."
                : "Use CarPlay video features responsibly and only while parked where required by law."
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        default:
            break
        }
    }

    private func presentEQPicker() {
        let sheet = UIAlertController(title: "Equalizer Preset", message: nil, preferredStyle: .actionSheet)
        for preset in AudioEQPreset.allCases {
            sheet.addAction(UIAlertAction(title: preset.rawValue, style: .default) { [weak self] _ in
                Settings.audioEQPreset = preset
                Log.write("settings EQ preset \(preset.rawValue)")
                NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                self?.tableView.reloadData()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController,
           let cell = tableView.cellForRow(at: IndexPath(row: 0, section: Section.audio.rawValue)) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(sheet, animated: true)
    }

    private func confirmYouTubeSignOut() {
        let alert = UIAlertController(
            title: "Sign Out of YouTube?",
            message: "Clears Google and YouTube cookies from this app. The car browser reloads on next open.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            YouTubeAccountManager.shared.signOut()
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func youtubeModeLabel(_ mode: PlayMode) -> String {
        switch mode {
        case .stream: "Stream"
        case .webOnCar: "Web on car"
        case .mirror: "Mirror"
        }
    }

    private func presentYouTubeModePicker() {
        let sheet = UIAlertController(title: "YouTube on Car", message: nil, preferredStyle: .actionSheet)
        for mode in [PlayMode.stream, .webOnCar, .mirror] {
            sheet.addAction(UIAlertAction(title: youtubeModeLabel(mode), style: .default) { [weak self] _ in
                PhonePlayback.shared.mode = mode
                Log.write("settings youtube mode \(mode.rawValue)")
                self?.tableView.reloadRows(at: [IndexPath(row: 2, section: Section.phoneAndCar.rawValue)], with: .none)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController,
           let cell = tableView.cellForRow(at: IndexPath(row: 2, section: Section.phoneAndCar.rawValue)) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(sheet, animated: true)
    }

    private func playAllFromSettings() {
        guard !SavedLinkStore.shared.links.isEmpty else {
            showNotice("Save a link on Links first.")
            return
        }
        SavedLinksPlayback.playAllOnCar()
        showNotice("Sending saved queue to the car display…")
        tableView.reloadRows(at: [IndexPath(row: 3, section: Section.phoneAndCar.rawValue)], with: .none)
    }

    private func showNotice(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func appearanceChanged() {
        Settings.appearanceIndex = appearanceControl.selectedSegmentIndex
        let names = ["System", "Light", "Dark"]
        let name = names.indices.contains(Settings.appearanceIndex) ? names[Settings.appearanceIndex] : "System"
        Log.write("settings theme \(name)")
        let style: UIUserInterfaceStyle = switch appearanceControl.selectedSegmentIndex {
        case 1: .light
        case 2: .dark
        default: .unspecified
        }
        view.window?.overrideUserInterfaceStyle = style
    }
}

private final class SettingsLogController: UIViewController {
    private let pageTitle: String
    private let slice: LogSlice?
    private let textView = UITextView()

    init(pageTitle: String) {
        self.pageTitle = pageTitle
        self.slice = LogSlice(title: pageTitle)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = pageTitle
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let lines = slice.map { Log.lines(for: $0) } ?? Log.allLines()
        textView.text = lines.isEmpty ? "No matching events yet." : lines.joined(separator: "\n")
    }
}

private final class SettingsSwitchCell: UITableViewCell {
    static let reuseIdentifier = "SettingsSwitchCell"
    private let toggle = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        accessoryView = toggle
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onToggle?(self.toggle.isOn)
        }, for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, subtitle: String?, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        var content = UIListContentConfiguration.subtitleCell()
        content.text = title
        content.secondaryText = subtitle
        content.secondaryTextProperties.color = .secondaryLabel
        contentConfiguration = content
        toggle.isOn = isOn
        self.onToggle = onToggle
    }
}

private final class SettingsDetailCell: UITableViewCell {
    static let reuseIdentifier = "SettingsDetailCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, detail: String) {
        var content = UIListContentConfiguration.valueCell()
        content.text = title
        content.secondaryText = detail
        content.secondaryTextProperties.color = .secondaryLabel
        contentConfiguration = content
    }
}
