import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore

    let service: MirakurunService

    @State private var playbackURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let playbackURL {
                VLCRawTSPlayerView(
                    url: playbackURL,
                    onStateChanged: { _ in },
                    onError: { message in
                        errorMessage = message
                    }
                )
                .id(playbackURL.absoluteString)
                .ignoresSafeArea()
            } else if let errorMessage {
                ContentUnavailableView(
                    "Playback Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Preparing Stream...")
            }
        }
        .task(id: settings.playbackConfigToken) {
            preparePlayer()
        }
        .onExitCommand {
            dismiss()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func preparePlayer() {
        guard let url = PlaybackURLResolver.resolveURL(for: service, settings: settings) else {
            playbackURL = nil
            errorMessage = "Invalid playback URL. Check your server address and HLS template settings."
            return
        }

        playbackURL = url
        errorMessage = nil
    }
}
