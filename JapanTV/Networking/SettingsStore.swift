import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let defaultServerAddress = "http://raspberrypi:40772"

    @Published var serverAddress: String {
        didSet { persist() }
    }

    @Published var useHLSOverride: Bool {
        didSet { persist() }
    }

    @Published var hlsTemplate: String {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let serverAddress = "settings.serverAddress"
        static let useHLSOverride = "settings.useHLSOverride"
        static let hlsTemplate = "settings.hlsTemplate"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.serverAddress = defaults.string(forKey: Keys.serverAddress) ?? Self.defaultServerAddress
        self.useHLSOverride = defaults.object(forKey: Keys.useHLSOverride) as? Bool ?? false
        self.hlsTemplate = defaults.string(forKey: Keys.hlsTemplate) ?? ""
    }

    var serverURL: URL? {
        guard let normalized = normalizedServerAddress else { return nil }
        return URL(string: normalized)
    }

    var normalizedServerAddress: String? {
        Self.normalizeAddress(serverAddress)
    }

    var playbackConfigToken: String {
        "\(serverAddress)|\(useHLSOverride)|\(hlsTemplate)"
    }

    func resetToDefaults() {
        serverAddress = Self.defaultServerAddress
        useHLSOverride = false
        hlsTemplate = ""
    }

    private func persist() {
        defaults.set(serverAddress, forKey: Keys.serverAddress)
        defaults.set(useHLSOverride, forKey: Keys.useHLSOverride)
        defaults.set(hlsTemplate, forKey: Keys.hlsTemplate)
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
