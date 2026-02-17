import SwiftUI
import TVVLCKit

struct VLCRawTSPlayerView: UIViewRepresentable {
    let url: URL
    let onStateChanged: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChanged: onStateChanged, onError: onError)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        context.coordinator.attachDrawable(view)
        context.coordinator.play(url: url)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.attachDrawable(uiView)
        context.coordinator.play(url: url)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        private let mediaPlayer = VLCMediaPlayer()
        private let onStateChanged: (String) -> Void
        private let onError: (String) -> Void

        private weak var drawableView: UIView?
        private var currentURL: URL?

        init(onStateChanged: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onStateChanged = onStateChanged
            self.onError = onError
            super.init()
            mediaPlayer.delegate = self
        }

        func attachDrawable(_ view: UIView) {
            guard drawableView !== view else { return }
            drawableView = view
            mediaPlayer.drawable = view
        }

        func play(url: URL) {
            if currentURL != url {
                currentURL = url
                let media = VLCMedia(url: url)
                media.addOption(":network-caching=1000")
                media.addOption(":clock-jitter=0")
                media.addOption(":clock-synchro=0")
                mediaPlayer.media = media
            }

            if !mediaPlayer.isPlaying {
                mediaPlayer.play()
            }
        }

        func stop() {
            mediaPlayer.stop()
            mediaPlayer.delegate = nil
            mediaPlayer.drawable = nil
            drawableView = nil
            currentURL = nil
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            let state = mediaPlayer.state
            let stateText = Self.describe(state)
            onStateChanged(stateText)
            if state == .error {
                onError("VLC playback error while opening raw TS stream.")
            }
        }

        private static func describe(_ state: VLCMediaPlayerState) -> String {
            switch state {
            case .opening:
                return "Opening"
            case .buffering:
                return "Buffering"
            case .playing:
                return "Playing"
            case .paused:
                return "Paused"
            case .stopped:
                return "Stopped"
            case .ended:
                return "Ended"
            case .error:
                return "Error"
            case .esAdded:
                return "Elementary Stream Added"
            @unknown default:
                return "Unknown"
            }
        }
    }
}
