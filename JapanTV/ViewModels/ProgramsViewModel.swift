import Foundation

@MainActor
final class ProgramsViewModel: ObservableObject {
    @Published private(set) var services: [MirakurunService] = []
    @Published private(set) var isLoadingServices = false
    @Published var errorMessage: String?

    private let client: MirakurunClient
    private let useSampleData: Bool

    init(client: MirakurunClient) {
        self.client = client
        self.useSampleData = ProcessInfo.processInfo.arguments.contains("-uitest-sample-data")
    }

    func reload(serverURL: URL?) async {
        if useSampleData {
            services = Self.sampleServices
            errorMessage = nil
            return
        }

        guard let serverURL else {
            services = []
            errorMessage = "Set a valid Mirakurun server URL in Settings."
            return
        }

        isLoadingServices = true
        defer { isLoadingServices = false }

        do {
            let fetched = try await client.fetchServices(serverURL: serverURL)
            services = fetched
            errorMessage = nil
        } catch {
            services = []
            errorMessage = error.localizedDescription
        }
    }

    func fetchPrograms(for service: MirakurunService, serverURL: URL?) async throws -> [MirakurunProgram] {
        if useSampleData {
            return Self.samplePrograms(for: service)
        }

        guard let serverURL else {
            throw MirakurunClientError.invalidServerURL
        }

        return try await client.fetchPrograms(
            serverURL: serverURL,
            networkID: service.networkId,
            serviceID: service.serviceId
        )
    }

    private static let sampleServices: [MirakurunService] = [
        MirakurunService(
            id: 101,
            serviceId: 101,
            networkId: 1,
            name: "NHK Sample 1",
            type: 1,
            logoId: nil,
            hasLogoData: false,
            remoteControlKeyId: 1,
            epgReady: true,
            epgUpdatedAt: nil,
            channel: MirakurunChannel(type: .gr, channel: "27", name: "Sample")
        ),
        MirakurunService(
            id: 102,
            serviceId: 102,
            networkId: 1,
            name: "Tokyo MX Sample",
            type: 1,
            logoId: nil,
            hasLogoData: false,
            remoteControlKeyId: 9,
            epgReady: true,
            epgUpdatedAt: nil,
            channel: MirakurunChannel(type: .gr, channel: "23", name: "Sample")
        )
    ]

    private static func samplePrograms(for service: MirakurunService) -> [MirakurunProgram] {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let halfHour: Int64 = 30 * 60 * 1000

        return [
            MirakurunProgram(
                id: service.id * 10 + 1,
                eventId: 1,
                serviceId: service.serviceId,
                networkId: service.networkId,
                startAt: now,
                duration: halfHour,
                isFree: true,
                name: "Sample Program A",
                description: "Sample data for UI verification."
            ),
            MirakurunProgram(
                id: service.id * 10 + 2,
                eventId: 2,
                serviceId: service.serviceId,
                networkId: service.networkId,
                startAt: now + halfHour,
                duration: halfHour,
                isFree: true,
                name: "Sample Program B",
                description: "Next program in UI test dataset."
            )
        ]
    }
}
