import Foundation

@MainActor
final class ProgramsViewModel: ObservableObject {
    @Published private(set) var services: [MirakurunService] = []
    @Published var selectedServiceID: Int?
    @Published private(set) var programs: [MirakurunProgram] = []
    @Published private(set) var isLoadingServices = false
    @Published private(set) var isLoadingPrograms = false
    @Published var errorMessage: String?

    private let client: MirakurunClient

    init(client: MirakurunClient) {
        self.client = client
    }

    var selectedService: MirakurunService? {
        guard let selectedServiceID else { return nil }
        return services.first(where: { $0.id == selectedServiceID })
    }

    func reload(serverURL: URL?) async {
        guard let serverURL else {
            services = []
            programs = []
            selectedServiceID = nil
            errorMessage = "Set a valid Mirakurun server URL in Settings."
            return
        }

        isLoadingServices = true
        defer { isLoadingServices = false }

        do {
            let fetched = try await client.fetchServices(serverURL: serverURL)
            services = fetched
            errorMessage = nil

            if let selectedServiceID, fetched.contains(where: { $0.id == selectedServiceID }) {
                await loadProgramsForSelected(serverURL: serverURL)
            } else {
                selectedServiceID = fetched.first?.id
                await loadProgramsForSelected(serverURL: serverURL)
            }
        } catch {
            services = []
            programs = []
            selectedServiceID = nil
            errorMessage = error.localizedDescription
        }
    }

    func loadProgramsForSelected(serverURL: URL?) async {
        guard let serverURL, let selectedService else {
            programs = []
            return
        }

        isLoadingPrograms = true
        defer { isLoadingPrograms = false }

        do {
            let fetched = try await client.fetchPrograms(
                serverURL: serverURL,
                networkID: selectedService.networkId,
                serviceID: selectedService.serviceId
            )
            programs = fetched
            errorMessage = nil
        } catch {
            programs = []
            errorMessage = error.localizedDescription
        }
    }
}
