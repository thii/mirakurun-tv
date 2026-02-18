import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let defaultServerAddress = "http://raspberrypi:40772"
    static let defaultSubtitlesEnabled = false

    @Published var serverAddress: String {
        didSet { persist() }
    }

    @Published var subtitlesEnabled: Bool {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let serverAddress = "settings.serverAddress"
        static let subtitlesEnabled = "settings.subtitlesEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.serverAddress = defaults.string(forKey: Keys.serverAddress) ?? Self.defaultServerAddress
        self.subtitlesEnabled = defaults.object(forKey: Keys.subtitlesEnabled) as? Bool ?? Self.defaultSubtitlesEnabled
    }

    var serverURL: URL? {
        guard let normalized = normalizedServerAddress else { return nil }
        return URL(string: normalized)
    }

    var normalizedServerAddress: String? {
        Self.normalizeAddress(serverAddress)
    }

    var playbackConfigToken: String {
        "\(serverAddress)|subtitles:\(subtitlesEnabled)"
    }

    func resetToDefaults() {
        serverAddress = Self.defaultServerAddress
        subtitlesEnabled = Self.defaultSubtitlesEnabled
    }

    private func persist() {
        defaults.set(serverAddress, forKey: Keys.serverAddress)
        defaults.set(subtitlesEnabled, forKey: Keys.subtitlesEnabled)
    }

    static func normalizeAddress(_ input: String) -> String? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if !value.contains("://") {
            value = "http://\(value)"
        }

        guard var components = URLComponents(string: value), components.host != nil else {
            return nil
        }

        if components.path.hasSuffix("/") {
            components.path = String(components.path.dropLast())
        }

        return components.url?.absoluteString
    }
}
