import Foundation

struct PlaybackURLResolver {
    @MainActor
    static func resolveURL(for service: MirakurunService, settings: SettingsStore) -> URL? {
        guard let serverURL = settings.serverURL else {
            return nil
        }

        return MirakurunEndpointBuilder(serverURL: serverURL).serviceStreamURL(serviceID: service.id)
    }
}
