import Foundation

struct PlaybackURLResolver {
    @MainActor
    static func resolveURL(for service: MirakurunService, settings: SettingsStore) -> URL? {
        guard let serverURL = settings.serverURL else {
            return nil
        }

        if settings.useHLSOverride {
            let template = settings.hlsTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !template.isEmpty {
                return resolveTemplate(template, service: service, serverURL: serverURL)
            }
        }

        return MirakurunEndpointBuilder(serverURL: serverURL).serviceStreamURL(serviceID: service.id)
    }

    @MainActor
    static func usesHLSOverride(settings: SettingsStore) -> Bool {
        settings.useHLSOverride && !settings.hlsTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func resolveTemplate(_ template: String, service: MirakurunService, serverURL: URL) -> URL? {
        let replacements: [String: String] = [
            "{serviceId}": String(service.id),
            "{networkId}": String(service.networkId),
            "{channelType}": service.channel?.type.rawValue ?? "",
            "{channel}": service.channel?.channel ?? "",
            "{base}": serverURL.absoluteString
        ]

        let value = replacements.reduce(template) { partial, item in
            partial.replacingOccurrences(of: item.key, with: item.value)
        }

        return URL(string: value)
    }
}
