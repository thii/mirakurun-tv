import Foundation

@MainActor
final class ChannelsViewModel: ObservableObject {
    @Published private(set) var services: [MirakurunService] = []
    @Published private(set) var nowNextByServiceID: [Int: NowNextProgramPair] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: MirakurunClient
    private var loadingNowNextServiceIDs: Set<Int> = []

    init(client: MirakurunClient) {
        self.client = client
    }

    func reload(serverURL: URL?) async {
        guard let serverURL else {
            services = []
            nowNextByServiceID = [:]
            errorMessage = "Set a valid Mirakurun server URL in Settings."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await client.fetchServices(serverURL: serverURL)
            services = fetched
            nowNextByServiceID = [:]
            errorMessage = nil
        } catch {
            services = []
            nowNextByServiceID = [:]
            errorMessage = error.localizedDescription
        }
    }

    func ensureNowNext(for service: MirakurunService, serverURL: URL?) async {
        guard nowNextByServiceID[service.id] == nil else { return }
        guard !loadingNowNextServiceIDs.contains(service.id) else { return }
        guard let serverURL else { return }

        loadingNowNextServiceIDs.insert(service.id)
        defer { loadingNowNextServiceIDs.remove(service.id) }

        do {
            let programs = try await client.fetchPrograms(
                serverURL: serverURL,
                networkID: service.networkId,
                serviceID: service.serviceId
            )
            nowNextByServiceID[service.id] = NowNextProgramPair.from(programs: programs)
        } catch {
            nowNextByServiceID[service.id] = NowNextProgramPair(now: nil, next: nil)
        }
    }

    func logoURL(for service: MirakurunService, serverURL: URL?) -> URL? {
        guard service.hasLogoData == true, let serverURL else { return nil }
        return MirakurunEndpointBuilder(serverURL: serverURL).serviceLogoURL(serviceID: service.id)
    }
}
