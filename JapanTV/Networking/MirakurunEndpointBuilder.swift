import Foundation

struct MirakurunEndpointBuilder {
    let serverURL: URL

    var apiBaseURL: URL {
        serverURL.appending(path: "api", directoryHint: .isDirectory)
    }

    var servicesURL: URL {
        apiBaseURL.appending(path: "services")
    }

    var versionURL: URL {
        apiBaseURL.appending(path: "version")
    }

    func serviceLogoURL(serviceID: Int) -> URL {
        apiBaseURL.appending(path: "services").appending(path: String(serviceID)).appending(path: "logo")
    }

    func serviceStreamURL(serviceID: Int) -> URL {
        apiBaseURL.appending(path: "services").appending(path: String(serviceID)).appending(path: "stream")
    }

    func programsURL(networkID: Int, serviceID: Int) -> URL {
        var components = URLComponents(url: apiBaseURL.appending(path: "programs"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "networkId", value: String(networkID)),
            URLQueryItem(name: "serviceId", value: String(serviceID))
        ]
        return components?.url ?? apiBaseURL.appending(path: "programs")
    }
}
