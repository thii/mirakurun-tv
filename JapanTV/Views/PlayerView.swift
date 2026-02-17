import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore

    let service: MirakurunService

    @State private var playbackURL: URL?
    @State private var errorMessage: String?
    @State private var statusText = "Preparing stream..."
    @State private var hasStartedPlayback = false
    @State private var animateLoadingRing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let playbackURL {
                VLCRawTSPlayerView(
                    url: playbackURL,
                    onStateChanged: { state in
                        Task { @MainActor in
                            handlePlayerState(state)
                        }
                    },
                    onError: { message in
                        Task { @MainActor in
                            errorMessage = message
                            statusText = "Playback error"
                        }
                    }
                )
                .id(playbackURL.absoluteString)
                .ignoresSafeArea()
            }

            if let errorMessage {
                ContentUnavailableView(
                    "Playback Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if !hasStartedPlayback {
                loadingOverlay
                    .transition(.opacity)
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
        hasStartedPlayback = false
        statusText = "Preparing stream..."

        guard let url = PlaybackURLResolver.resolveURL(for: service, settings: settings) else {
            playbackURL = nil
            errorMessage = "Invalid playback URL. Check your server address and HLS template settings."
            return
        }

        playbackURL = url
        errorMessage = nil
    }

    private func handlePlayerState(_ state: String) {
        if state == "Playing" {
            withAnimation(.easeOut(duration: 0.2)) {
                hasStartedPlayback = true
            }
            return
        }

        if !hasStartedPlayback {
            switch state {
            case "Opening":
                statusText = "Opening stream..."
            case "Buffering":
                statusText = "Buffering..."
            default:
                statusText = state
            }
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 6)
                    .frame(width: 130, height: 130)

                Circle()
                    .trim(from: 0.08, to: 0.88)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(animateLoadingRing ? 360 : 0))
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: animateLoadingRing)

                Image(systemName: "tv.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text(service.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 50)
        .padding(.vertical, 40)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            animateLoadingRing = true
        }
        .onDisappear {
            animateLoadingRing = false
        }
    }
}
