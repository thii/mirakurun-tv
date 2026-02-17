import SwiftUI

struct PlayerView: View {
    private enum ChannelChangeDirection {
        case previous
        case next
        case none

        var iconName: String {
            switch self {
            case .previous:
                return "chevron.left.circle.fill"
            case .next:
                return "chevron.right.circle.fill"
            case .none:
                return "dot.radiowaves.left.and.right"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore

    let services: [MirakurunService]

    @State private var currentIndex: Int
    @State private var playbackURL: URL?
    @State private var errorMessage: String?
    @State private var statusText = "Preparing stream..."
    @State private var hasStartedPlayback = false
    @State private var animateLoadingRing = false
    @State private var isRailVisible = false
    @State private var railDirection: ChannelChangeDirection = .none
    @State private var isChannelSwitchHintVisible = false
    @State private var transitionMaskOpacity = 0.0
    @State private var railDismissTask: Task<Void, Never>?
    @State private var channelSwitchHintDismissTask: Task<Void, Never>?
    @State private var transitionMaskTask: Task<Void, Never>?

    init(services: [MirakurunService], initialServiceID: Int) {
        self.services = services

        let index = services.firstIndex(where: { $0.id == initialServiceID }) ?? 0
        _currentIndex = State(initialValue: index)
    }

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

            RemoteCommandCaptureView(onMoveCommand: handleMoveCommand)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)

            Color.black
                .opacity(transitionMaskOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

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
        .overlay(alignment: .bottom) {
            channelRail
        }
        .overlay(alignment: .top) {
            channelSwitchHint
        }
        .task(id: playbackTaskToken) {
            preparePlayer()
        }
        .focusable(true)
        .focusEffectDisabled()
        .onMoveCommand(perform: handleMoveCommand)
        .onAppear {
            showRail(direction: .none)
            showChannelSwitchHint()
        }
        .onDisappear {
            railDismissTask?.cancel()
            channelSwitchHintDismissTask?.cancel()
            transitionMaskTask?.cancel()
        }
        .onExitCommand {
            dismiss()
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("player.streamView.service.\(currentService?.id ?? -1)")
    }

    @ViewBuilder
    private var channelRail: some View {
        if isRailVisible, let currentService {
            LiveTVRailView(
                service: currentService,
                subtitle: channelSubtitle(for: currentService),
                logoURL: logoURL(for: currentService),
                direction: railDirection
            )
            .id(currentService.id)
            .padding(.horizontal, 60)
            .padding(.bottom, 64)
            .transition(transition(for: railDirection))
        }
    }

    @ViewBuilder
    private var channelSwitchHint: some View {
        if isChannelSwitchHintVisible {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.chevron.right")
                    .font(.subheadline.weight(.bold))
                Text("Press Left or Right to switch channels")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.26), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.36), radius: 16, y: 8)
            .padding(.top, 56)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityIdentifier("player.channelSwitchHint")
        }
    }

    private func preparePlayer() {
        hasStartedPlayback = false
        statusText = "Preparing stream..."

        guard let currentService else {
            playbackURL = nil
            errorMessage = "No channels available for playback."
            return
        }

        guard let url = PlaybackURLResolver.resolveURL(for: currentService, settings: settings) else {
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

    private var currentService: MirakurunService? {
        guard services.indices.contains(currentIndex) else { return nil }
        return services[currentIndex]
    }

    private var playbackTaskToken: String {
        "\(settings.playbackConfigToken)-\(currentService?.id ?? -1)"
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .left:
            switchChannel(step: -1, direction: .previous)
        case .right:
            switchChannel(step: 1, direction: .next)
        default:
            break
        }
    }

    private func switchChannel(step: Int, direction: ChannelChangeDirection) {
        guard services.count > 1 else {
            showRail(direction: .none)
            return
        }

        let nextIndex = wrappedIndex(currentIndex + step)
        guard nextIndex != currentIndex else { return }

        hideChannelSwitchHint()

        withAnimation(.easeInOut(duration: 0.24)) {
            currentIndex = nextIndex
        }
        showRail(direction: direction)
        animateTransitionMask()
    }

    private func wrappedIndex(_ index: Int) -> Int {
        let count = services.count
        guard count > 0 else { return 0 }
        let candidate = index % count
        return candidate >= 0 ? candidate : candidate + count
    }

    private func showRail(direction: ChannelChangeDirection) {
        railDirection = direction
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            isRailVisible = true
        }

        railDismissTask?.cancel()
        railDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.22)) {
                isRailVisible = false
            }
        }
    }

    private func showChannelSwitchHint() {
        withAnimation(.easeOut(duration: 0.26)) {
            isChannelSwitchHintVisible = true
        }

        channelSwitchHintDismissTask?.cancel()
        channelSwitchHintDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            hideChannelSwitchHint()
        }
    }

    private func hideChannelSwitchHint() {
        guard isChannelSwitchHintVisible else { return }
        channelSwitchHintDismissTask?.cancel()
        withAnimation(.easeIn(duration: 0.20)) {
            isChannelSwitchHintVisible = false
        }
    }

    private func animateTransitionMask() {
        withAnimation(.easeOut(duration: 0.10)) {
            transitionMaskOpacity = 0.28
        }

        transitionMaskTask?.cancel()
        transitionMaskTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(.easeIn(duration: 0.20)) {
                transitionMaskOpacity = 0.0
            }
        }
    }

    private func transition(for direction: ChannelChangeDirection) -> AnyTransition {
        switch direction {
        case .previous:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .next:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .none:
            return .move(edge: .bottom).combined(with: .opacity)
        }
    }

    private func channelSubtitle(for service: MirakurunService) -> String {
        let position = "\(currentIndex + 1)/\(services.count)"

        if let remoteControlKey = service.remoteControlKeyId {
            return "Channel \(remoteControlKey)  •  \(position)"
        }

        if let channelNumber = service.channel?.channel {
            return "Channel \(channelNumber)  •  \(position)"
        }

        return "Channel \(position)"
    }

    private func logoURL(for service: MirakurunService) -> URL? {
        guard service.hasLogoData == true, let serverURL = settings.serverURL else { return nil }
        return MirakurunEndpointBuilder(serverURL: serverURL).serviceLogoURL(serviceID: service.id)
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

            Text(currentService?.name ?? "No Channel")
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

    private struct LiveTVRailView: View {
        let service: MirakurunService
        let subtitle: String
        let logoURL: URL?
        let direction: ChannelChangeDirection

        var body: some View {
            HStack(spacing: 18) {
                Image(systemName: direction.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 34)

                ServiceLogoView(logoURL: logoURL, width: 96, height: 54)

                VStack(alignment: .leading, spacing: 6) {
                    Text(service.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .frame(maxWidth: 860)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(service.name)
            .accessibilityIdentifier("player.channelRail")
        }
    }

    private struct RemoteCommandCaptureView: UIViewRepresentable {
        let onMoveCommand: (MoveCommandDirection) -> Void

        func makeUIView(context: Context) -> CommandCaptureUIView {
            let view = CommandCaptureUIView()
            view.onMoveCommand = onMoveCommand
            view.activateIfNeeded()
            return view
        }

        func updateUIView(_ uiView: CommandCaptureUIView, context: Context) {
            uiView.onMoveCommand = onMoveCommand
            uiView.activateIfNeeded()
        }

        final class CommandCaptureUIView: UIView {
            var onMoveCommand: ((MoveCommandDirection) -> Void)?

            override init(frame: CGRect) {
                super.init(frame: frame)
                backgroundColor = .clear
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override var canBecomeFirstResponder: Bool { true }

            func activateIfNeeded() {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    _ = self.becomeFirstResponder()
                }
            }

            override func didMoveToWindow() {
                super.didMoveToWindow()
                activateIfNeeded()
            }

            override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
                for press in presses {
                    switch press.type {
                    case .leftArrow:
                        onMoveCommand?(.left)
                    case .rightArrow:
                        onMoveCommand?(.right)
                    default:
                        break
                    }
                }
                super.pressesEnded(presses, with: event)
            }
        }
    }
}
