import SwiftUI
import TVVLCKit
import os

#if DEBUG
private let subtitleOSLog = Logger(subsystem: "JapanTV", category: "Subtitles")
#endif

struct VLCRawTSPlayerView: UIViewRepresentable {
    let url: URL
    let showsSubtitles: Bool
    let onStateChanged: (String) -> Void
    let onError: (String) -> Void
    let onSubtitleStatusChanged: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onStateChanged: onStateChanged,
            onError: onError,
            subtitlesEnabled: showsSubtitles,
            onSubtitleStatusChanged: onSubtitleStatusChanged
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        context.coordinator.attachDrawable(view)
        context.coordinator.setSubtitlesEnabled(showsSubtitles)
        context.coordinator.play(url: url)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.attachDrawable(uiView)
        context.coordinator.setSubtitlesEnabled(showsSubtitles)
        context.coordinator.play(url: url)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        private static let unsupportedARIBSubtitleMessage =
            "Subtitles unavailable: ARIB subtitles are not supported by the current TVVLCKit build."

        private struct SubtitleTrack {
            let id: Int32
            let name: String
        }

        private let mediaPlayer = VLCMediaPlayer()
        private let onStateChanged: (String) -> Void
        private let onError: (String) -> Void
        private let onSubtitleStatusChanged: (String?) -> Void

        private weak var drawableView: UIView?
        private var currentURL: URL?
        private var subtitlesEnabled: Bool
        private var subtitleRetryAttempts = 0
        private var subtitleRetryWorkItem: DispatchWorkItem?
        private var lastSubtitleEnsureTime = Date.distantPast
        private var subtitleStatusMessage: String?

#if DEBUG
        private weak var loggingLibrary: VLCLibrary?
        private var subtitleDebugLogger: VLCSubtitleDebugLogger?
#endif

        init(
            onStateChanged: @escaping (String) -> Void,
            onError: @escaping (String) -> Void,
            subtitlesEnabled: Bool,
            onSubtitleStatusChanged: @escaping (String?) -> Void
        ) {
            self.onStateChanged = onStateChanged
            self.onError = onError
            self.subtitlesEnabled = subtitlesEnabled
            self.onSubtitleStatusChanged = onSubtitleStatusChanged
            super.init()
            mediaPlayer.delegate = self
#if DEBUG
            installVLCSubtitleDebugLogger(on: mediaPlayer.libraryInstance)
#endif
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
                media.addOption(":avcodec-hw=none")
                media.addOption(":spu")
                media.addOption(":text-renderer=freetype")
                media.addOption(":sub-margin=24")
                media.addOption(":sub-text-scale=120")
                media.addOption(":freetype-opacity=255")
                media.addOption(":freetype-outline-opacity=255")
                media.addOption(":freetype-outline-thickness=2")
                media.addOption(":freetype-background-opacity=96")
                mediaPlayer.media = media
                subtitleRetryAttempts = 0
                subtitleRetryWorkItem?.cancel()
                lastSubtitleEnsureTime = .distantPast
                updateSubtitleStatus(nil)
            }

            applySubtitlePreference()

            if !mediaPlayer.isPlaying {
                mediaPlayer.play()
            }
        }

        func setSubtitlesEnabled(_ enabled: Bool) {
            guard subtitlesEnabled != enabled else { return }
            subtitlesEnabled = enabled
            subtitleRetryAttempts = 0
            subtitleRetryWorkItem?.cancel()
            lastSubtitleEnsureTime = .distantPast
            if !enabled {
                updateSubtitleStatus(nil)
            }
            applySubtitlePreference()
        }

        func stop() {
            mediaPlayer.stop()
            mediaPlayer.delegate = nil
            mediaPlayer.drawable = nil
            drawableView = nil
            currentURL = nil
            subtitleRetryWorkItem?.cancel()
            subtitleRetryWorkItem = nil
            updateSubtitleStatus(nil)
#if DEBUG
            uninstallVLCSubtitleDebugLogger()
#endif
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            if Thread.isMainThread {
                handleMediaPlayerStateChanged()
                return
            }

            performSelector(onMainThread: #selector(handleMediaPlayerStateChangedFromSelector), with: nil, waitUntilDone: false)
        }

        func mediaPlayerTimeChanged(_ aNotification: Notification) {
            if Thread.isMainThread {
                handleMediaPlayerTimeChanged()
                return
            }

            performSelector(onMainThread: #selector(handleMediaPlayerTimeChangedFromSelector), with: nil, waitUntilDone: false)
        }

        @objc
        private func handleMediaPlayerStateChangedFromSelector() {
            handleMediaPlayerStateChanged()
        }

        @objc
        private func handleMediaPlayerTimeChangedFromSelector() {
            handleMediaPlayerTimeChanged()
        }

        private func handleMediaPlayerStateChanged() {
            applySubtitlePreference()

            let state = mediaPlayer.state
            let stateText = Self.describe(state)
            onStateChanged(stateText)
            if state == .error {
                onError("VLC playback error while opening raw TS stream.")
            }
        }

        private func handleMediaPlayerTimeChanged() {
            guard subtitlesEnabled else { return }
            let now = Date()
            guard now.timeIntervalSince(lastSubtitleEnsureTime) >= 1 else { return }
            lastSubtitleEnsureTime = now
            applySubtitlePreference()
        }

        private func applySubtitlePreference() {
            if !subtitlesEnabled {
                if let current = currentSubtitleIndex(), current == -1 { return }
                setCurrentSubtitleIndex(-1)
#if DEBUG
                debugLog("Disabled: set currentVideoSubTitleIndex=-1")
#endif
                subtitleRetryAttempts = 0
                subtitleRetryWorkItem?.cancel()
                return
            }

            let tracks = availableSubtitleTracks()

            if tracks.isEmpty {
#if DEBUG
                debugLog("No subtitle tracks available yet (attempt \(subtitleRetryAttempts + 1)).")
#endif
                scheduleSubtitleRetry()
                return
            }

            let enabledTrackIDs = tracks.map(\.id)
            if let current = currentSubtitleIndex(), enabledTrackIDs.contains(current) {
                if let currentTrack = tracks.first(where: { $0.id == current }) {
                    updateSubtitleStatus(subtitleStatusMessage(for: currentTrack))
                } else {
                    updateSubtitleStatus(nil)
                }
#if DEBUG
                debugLog("Keeping current subtitle track id=\(current). Available=\(tracks.map { "\($0.id):\($0.name)" })")
#endif
                subtitleRetryAttempts = 0
                subtitleRetryWorkItem?.cancel()
                return
            }

            guard let firstSubtitleTrack = tracks.first else {
                return
            }

            setCurrentSubtitleIndex(firstSubtitleTrack.id)
            updateSubtitleStatus(subtitleStatusMessage(for: firstSubtitleTrack))
#if DEBUG
            debugLog("Selected subtitle track id=\(firstSubtitleTrack.id) name='\(firstSubtitleTrack.name)'. Available=\(tracks.map { "\($0.id):\($0.name)" })")
#endif
            subtitleRetryAttempts = 0
            subtitleRetryWorkItem?.cancel()
        }

        private func currentSubtitleIndex() -> Int32? {
            mediaPlayer.currentVideoSubTitleIndex
        }

        private func setCurrentSubtitleIndex(_ index: Int32) {
            mediaPlayer.currentVideoSubTitleIndex = index
        }

        private func availableSubtitleTracks() -> [SubtitleTrack] {
            let rawIDs = mediaPlayer.videoSubTitlesIndexes
            let rawNames = mediaPlayer.videoSubTitlesNames

            let names = rawNames.compactMap { value -> String? in
                if let string = value as? String { return string }
                if let nsString = value as? NSString { return nsString as String }
                return nil
            }

            var tracks: [SubtitleTrack] = []
            for (index, idValue) in rawIDs.enumerated() {
                let id: Int32
                if let number = idValue as? NSNumber {
                    id = number.int32Value
                } else if let intValue = idValue as? Int32 {
                    id = intValue
                } else if let intValue = idValue as? Int {
                    guard let converted = Int32(exactly: intValue) else { continue }
                    id = converted
                } else {
                    continue
                }

                let name = index < names.count ? names[index] : ""
                let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if id == -1 { continue }
                if normalizedName == "disabled" || normalizedName == "disable" || normalizedName == "off" || normalizedName == "none" {
                    continue
                }
                tracks.append(SubtitleTrack(id: id, name: name))
            }

            return tracks
        }

        private func scheduleSubtitleRetry() {
            guard subtitlesEnabled else { return }
            guard subtitleRetryAttempts < 12 else { return }

            subtitleRetryWorkItem?.cancel()
            subtitleRetryAttempts += 1

            let workItem = DispatchWorkItem { [weak self] in
                self?.applySubtitlePreference()
            }
            subtitleRetryWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        }

#if DEBUG
        private func debugLog(_ message: String) {
            subtitleOSLog.debug("[Subtitles] \(message, privacy: .public)")
            print("[Subtitles] \(message)")
        }
#endif

#if DEBUG
        private func installVLCSubtitleDebugLogger(on library: VLCLibrary) {
            let logger = VLCSubtitleDebugLogger { [weak self] message in
                self?.handleVLCSubtitleDebugMessage(message)
            }
            loggingLibrary = library
            subtitleDebugLogger = logger
            library.loggers = (library.loggers ?? []) + [logger]
        }

        private func uninstallVLCSubtitleDebugLogger() {
            guard let logger = subtitleDebugLogger, let library = loggingLibrary else {
                return
            }

            library.loggers = (library.loggers ?? []).filter { existingLogger in
                guard let existingLoggerObject = existingLogger as AnyObject? else { return true }
                return existingLoggerObject !== logger
            }
            subtitleDebugLogger = nil
            loggingLibrary = nil
        }

        private func handleVLCSubtitleDebugMessage(_ message: String) {
            guard subtitlesEnabled else { return }
            let lower = message.lowercased()
            let isUnsupportedARIBSubtitle =
                lower.contains("fcc=arba")
                || lower.contains("could not decode the format \"arba\"")
                || (lower.contains("codec `arba'") && lower.contains("not supported"))

            guard isUnsupportedARIBSubtitle else { return }
            updateSubtitleStatus(Self.unsupportedARIBSubtitleMessage)
        }
#endif

        private func subtitleStatusMessage(for track: SubtitleTrack) -> String? {
            let normalizedName = track.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalizedName.contains("arib") {
                return Self.unsupportedARIBSubtitleMessage
            }
            return nil
        }

        private func updateSubtitleStatus(_ message: String?) {
            guard subtitleStatusMessage != message else { return }
            subtitleStatusMessage = message
#if DEBUG
            if let message {
                debugLog("Status: \(message)")
            }
#endif
            onSubtitleStatusChanged(message)
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

#if DEBUG
private final class VLCSubtitleDebugLogger: NSObject, VLCLogging {
    var level: VLCLogLevel = .debug
    private let onMessage: (String) -> Void

    init(onMessage: @escaping (String) -> Void) {
        self.onMessage = onMessage
        super.init()
    }

    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        let lower = message.lowercased()
        if lower.contains("subtitle")
            || lower.contains("spu")
            || lower.contains("arib")
            || lower.contains("arba")
            || lower.contains("blend")
            || lower.contains("decoderplayspu")
            || lower.contains("es 0x") {
            subtitleOSLog.debug("[VLCSub] \(message, privacy: .public)")
            print("[VLCSub] \(message)")
            onMessage(message)
        }
    }
}
#endif
