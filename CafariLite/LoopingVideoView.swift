import AVFoundation
import SwiftUI
import UIKit

struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        view.configure(url: url)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {
        uiView.configure(url: url)
    }
}

final class LoopingPlayerView: UIView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func configure(url: URL) {
        guard currentURL != url else { return }
        currentURL = url
        player?.pause()
        player = nil
        looper = nil

        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: item)
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        playerLayer.player = queue
        queue.isMuted = true
        queue.play()
    }

    deinit {
        player?.pause()
    }
}
