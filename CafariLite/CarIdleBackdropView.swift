import AVFoundation
import UIKit

/// Full-bleed idle backdrop on the car favorites home (still or looping video).
final class CarIdleBackdropView: UIView {
    private let imageView = UIImageView()
    private let playerHost = LoopingPlayerView()
    private var currentLook: CarIdleLook?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        playerHost.translatesAutoresizingMaskIntoConstraints = false
        playerHost.isHidden = true
        addSubview(imageView)
        addSubview(playerHost)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerHost.topAnchor.constraint(equalTo: topAnchor),
            playerHost.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerHost.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerHost.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func refresh() {
        currentLook = nil
        apply(look: IdleLookStore.shared.selectedLook)
    }

    private func apply(look: CarIdleLook) {
        if look == currentLook {
            if case .wallpaper = look {
                imageView.image = WallpaperStore.shared.image
            }
            return
        }
        currentLook = look

        switch look {
        case .wallpaper:
            playerHost.isHidden = true
            imageView.isHidden = false
            imageView.image = WallpaperStore.shared.image
        case .fireplace, .rain, .colorWaves:
            guard let scene = look.ambientScene, let url = scene.loopURL() else {
                showStill(scene: look.ambientScene ?? .fireplace)
                return
            }
            imageView.isHidden = true
            playerHost.isHidden = false
            playerHost.configure(url: url)
        case .clip(let id):
            guard let url = AmbientLoopStore.shared.url(forID: id) else {
                imageView.isHidden = false
                playerHost.isHidden = true
                imageView.image = WallpaperStore.shared.image
                return
            }
            imageView.isHidden = true
            playerHost.isHidden = false
            playerHost.configure(url: url)
        }
    }

    private func showStill(scene: IdleAmbientScene) {
        playerHost.isHidden = true
        imageView.isHidden = false
        imageView.image = scene.previewImage()
    }
}
