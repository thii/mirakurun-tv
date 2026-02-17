import Foundation

enum MirakurunClientError: LocalizedError {
    case invalidStatusCode(Int)
    case invalidServerURL

    var errorDescription: String? {
        switch self {
        case .invalidStatusCode(let status):
            return "Mirakurun request failed with status \(status)."
        case .invalidServerURL:
            return "Invalid Mirakurun server URL."
        }
    }
}

actor MirakurunClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func checkVersion(serverURL: URL) async throws -> MirakurunVersion {
        let endpoint = MirakurunEndpointBuilder(serverURL: serverURL)
        return try await get(endpoint.versionURL, as: MirakurunVersion.self)
    }

    func fetchServices(serverURL: URL) async throws -> [MirakurunService] {
        let endpoint = MirakurunEndpointBuilder(serverURL: serverURL)
        let services = try await get(endpoint.servicesURL, as: [MirakurunService].self)
        return services
            .filter(\.isPlayableBroadcast)
            .sorted(by: serviceSort)
    }

    func fetchPrograms(serverURL: URL, networkID: Int, serviceID: Int) async throws -> [MirakurunProgram] {
        let endpoint = MirakurunEndpointBuilder(serverURL: serverURL)
        let programs = try await get(endpoint.programsURL(networkID: networkID, serviceID: serviceID), as: [MirakurunProgram].self)
        return programs.sorted { $0.startAt < $1.startAt }
    }

    private func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MirakurunClientError.invalidStatusCode(-1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MirakurunClientError.invalidStatusCode(httpResponse.statusCode)
        }

        return try decoder.decode(type, from: data)
    }

    private func serviceSort(lhs: MirakurunService, rhs: MirakurunService) -> Bool {
        let lhsType = sortKey(for: lhs.channel?.type)
        let rhsType = sortKey(for: rhs.channel?.type)

        if lhsType != rhsType { return lhsType < rhsType }

        let lhsRemote = lhs.remoteControlKeyId ?? Int.max
        let rhsRemote = rhs.remoteControlKeyId ?? Int.max

        if lhsRemote != rhsRemote { return lhsRemote < rhsRemote }

        if lhs.serviceId != rhs.serviceId { return lhs.serviceId < rhs.serviceId }

        return lhs.id < rhs.id
    }

    private func sortKey(for type: MirakurunChannelType?) -> Int {
        switch type {
        case .gr: return 0
        case .bs: return 1
        case .cs: return 2
        case .sky: return 3
        case nil: return 4
        }
    }
}
