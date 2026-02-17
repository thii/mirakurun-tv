import Foundation

@MainActor
final class ChannelsViewModel: ObservableObject {
    private struct ChannelGroupKey: Hashable {
        let channelType: MirakurunChannelType?
        let networkID: Int
        let remoteControlKeyID: Int
    }

    private struct ProgramDedupKey: Hashable {
        let group: ChannelGroupKey
        let title: String
        let startAt: Int64
        let duration: Int64
    }

    @Published private(set) var services: [MirakurunService] = []
    @Published private(set) var uniquifiedServices: [MirakurunService] = []
    @Published private(set) var nowNextByServiceID: [Int: NowNextProgramPair] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: MirakurunClient
    private let useSampleData: Bool
    private var loadingNowNextServiceIDs: Set<Int> = []
    private var nowNextRefreshAfterByServiceID: [Int: Date] = [:]
    private var dedupRefreshTask: Task<Void, Never>?
    private var lastServicesLoadDate: Date?
    private var loadedServerURL: URL?

    private static let servicesReloadInterval: TimeInterval = 180
    private static let fallbackNowNextRefreshInterval: TimeInterval = 300
    private static let maximumNowNextRefreshInterval: TimeInterval = 900
    private static let programBoundaryRefreshDelay: TimeInterval = 2

    init(client: MirakurunClient) {
        self.client = client
        self.useSampleData = ProcessInfo.processInfo.arguments.contains("-uitest-sample-data")
    }

    deinit {
        dedupRefreshTask?.cancel()
    }

    func reload(serverURL: URL?) async {
        if useSampleData {
            services = Self.sampleServices
            nowNextByServiceID = Self.sampleNowNextByServiceID
            nowNextRefreshAfterByServiceID = [:]
            errorMessage = nil
            recomputeUniquifiedServices()
            return
        }

        guard let serverURL else {
            dedupRefreshTask?.cancel()
            services = []
            uniquifiedServices = []
            nowNextByServiceID = [:]
            nowNextRefreshAfterByServiceID = [:]
            lastServicesLoadDate = nil
            loadedServerURL = nil
            errorMessage = "Set a valid Mirakurun server URL in Settings."
            return
        }

        if shouldUseCachedServices(for: serverURL) {
            errorMessage = nil
            await preloadNowNextForDuplicateCandidates(serverURL: serverURL, force: false)
            recomputeUniquifiedServices()
            scheduleDedupRefresh(serverURL: serverURL)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await client.fetchServices(serverURL: serverURL)
            services = fetched
            pruneNowNextCache()
            lastServicesLoadDate = Date()
            loadedServerURL = serverURL
            errorMessage = nil
            await preloadNowNextForDuplicateCandidates(serverURL: serverURL, force: false)
            recomputeUniquifiedServices()
            scheduleDedupRefresh(serverURL: serverURL)
        } catch {
            dedupRefreshTask?.cancel()
            services = []
            uniquifiedServices = []
            nowNextByServiceID = [:]
            nowNextRefreshAfterByServiceID = [:]
            lastServicesLoadDate = nil
            errorMessage = error.localizedDescription
        }
    }

    func ensureNowNext(for service: MirakurunService, serverURL: URL?, forceRefresh: Bool = false) async {
        if !forceRefresh,
           nowNextByServiceID[service.id] != nil,
           let refreshAfter = nowNextRefreshAfterByServiceID[service.id],
           refreshAfter > Date() {
            return
        }

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
            let pair = NowNextProgramPair.from(programs: programs)
            nowNextByServiceID[service.id] = pair
            nowNextRefreshAfterByServiceID[service.id] = nextRefreshDate(for: pair)
        } catch {
            nowNextByServiceID[service.id] = NowNextProgramPair(now: nil, next: nil)
            nowNextRefreshAfterByServiceID[service.id] = Date().addingTimeInterval(Self.fallbackNowNextRefreshInterval)
        }

        recomputeUniquifiedServices()
    }

    func logoURL(for service: MirakurunService, serverURL: URL?) -> URL? {
        guard service.hasLogoData == true, let serverURL else { return nil }
        return MirakurunEndpointBuilder(serverURL: serverURL).serviceLogoURL(serviceID: service.id)
    }

    private func preloadNowNextForDuplicateCandidates(serverURL: URL, force: Bool) async {
        for service in duplicateCandidateServices {
            if Task.isCancelled { return }
            await ensureNowNext(for: service, serverURL: serverURL, forceRefresh: force)
        }
    }

    private func shouldUseCachedServices(for serverURL: URL) -> Bool {
        guard loadedServerURL == serverURL else { return false }
        guard !services.isEmpty else { return false }
        guard let lastServicesLoadDate else { return false }
        return Date().timeIntervalSince(lastServicesLoadDate) < Self.servicesReloadInterval
    }

    private func pruneNowNextCache() {
        let serviceIDs = Set(services.map(\.id))
        nowNextByServiceID = nowNextByServiceID.filter { serviceIDs.contains($0.key) }
        nowNextRefreshAfterByServiceID = nowNextRefreshAfterByServiceID.filter { serviceIDs.contains($0.key) }
    }

    private func recomputeUniquifiedServices() {
        var seen = Set<ProgramDedupKey>()
        var result: [MirakurunService] = []

        for service in services {
            guard let key = dedupKey(for: service) else {
                result.append(service)
                continue
            }

            if seen.insert(key).inserted {
                result.append(service)
            }
        }

        uniquifiedServices = result
    }

    private func nextRefreshDate(for pair: NowNextProgramPair, referenceDate: Date = Date()) -> Date {
        let maxDate = referenceDate.addingTimeInterval(Self.maximumNowNextRefreshInterval)

        if let now = pair.now {
            let boundary = now.endDate.addingTimeInterval(Self.programBoundaryRefreshDelay)
            if boundary > referenceDate {
                return min(boundary, maxDate)
            }
        }

        if let next = pair.next {
            let boundary = next.startDate.addingTimeInterval(Self.programBoundaryRefreshDelay)
            if boundary > referenceDate {
                return min(boundary, maxDate)
            }
        }

        return referenceDate.addingTimeInterval(Self.fallbackNowNextRefreshInterval)
    }

    private func scheduleDedupRefresh(serverURL: URL) {
        dedupRefreshTask?.cancel()
        guard !duplicateCandidateServices.isEmpty else { return }

        let refreshAt = nextDedupRefreshDate(referenceDate: Date())
        let delay = max(refreshAt.timeIntervalSinceNow, 1)
        let delayNanoseconds = UInt64(delay * 1_000_000_000)

        dedupRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            await preloadNowNextForDuplicateCandidates(serverURL: serverURL, force: false)
            scheduleDedupRefresh(serverURL: serverURL)
        }
    }

    private func nextDedupRefreshDate(referenceDate: Date) -> Date {
        let defaultDate = referenceDate.addingTimeInterval(Self.fallbackNowNextRefreshInterval)
        let refreshDates = duplicateCandidateServices.compactMap { service in
            nowNextRefreshAfterByServiceID[service.id]
        }

        return refreshDates.min() ?? defaultDate
    }

    private var duplicateCandidateServices: [MirakurunService] {
        var grouped: [ChannelGroupKey: [MirakurunService]] = [:]

        for service in services {
            guard let key = dedupGroupKey(service) else { continue }
            grouped[key, default: []].append(service)
        }

        return services.filter { service in
            guard let key = dedupGroupKey(service),
                  let members = grouped[key] else {
                return false
            }
            return members.count > 1
        }
    }

    private func dedupKey(for service: MirakurunService) -> ProgramDedupKey? {
        guard let group = dedupGroupKey(service) else { return nil }
        guard let now = nowNextByServiceID[service.id]?.now else { return nil }
        guard let title = normalizedProgramTitle(now.name), !title.isEmpty else { return nil }

        return ProgramDedupKey(
            group: group,
            title: title,
            startAt: now.startAt,
            duration: now.duration
        )
    }

    private func dedupGroupKey(_ service: MirakurunService) -> ChannelGroupKey? {
        guard let remoteControlKeyID = service.remoteControlKeyId else { return nil }

        return ChannelGroupKey(
            channelType: service.channel?.type,
            networkID: service.networkId,
            remoteControlKeyID: remoteControlKeyID
        )
    }

    private func normalizedProgramTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
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
            id: 103,
            serviceId: 103,
            networkId: 1,
            name: "NHK Sample 2",
            type: 1,
            logoId: nil,
            hasLogoData: false,
            remoteControlKeyId: 1,
            epgReady: true,
            epgUpdatedAt: nil,
            channel: MirakurunChannel(type: .gr, channel: "28", name: "Sample")
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
        ),
        MirakurunService(
            id: 201,
            serviceId: 201,
            networkId: 4,
            name: "BS Sample 4K",
            type: 1,
            logoId: nil,
            hasLogoData: false,
            remoteControlKeyId: 4,
            epgReady: true,
            epgUpdatedAt: nil,
            channel: MirakurunChannel(type: .bs, channel: "141", name: "Sample")
        )
    ]

    private static let sampleNowNextByServiceID: [Int: NowNextProgramPair] = {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let halfHour: Int64 = 30 * 60 * 1000
        let tenMinutes: Int64 = 10 * 60 * 1000
        let currentStart = now - tenMinutes

        func pair(service: MirakurunService, nowTitle: String, nextTitle: String) -> NowNextProgramPair {
            let current = MirakurunProgram(
                id: service.id * 100 + 1,
                eventId: 1,
                serviceId: service.serviceId,
                networkId: service.networkId,
                startAt: currentStart,
                duration: halfHour,
                isFree: true,
                name: nowTitle,
                description: "Sample now program."
            )
            let next = MirakurunProgram(
                id: service.id * 100 + 2,
                eventId: 2,
                serviceId: service.serviceId,
                networkId: service.networkId,
                startAt: currentStart + halfHour,
                duration: halfHour,
                isFree: true,
                name: nextTitle,
                description: "Sample next program."
            )
            return NowNextProgramPair(now: current, next: next)
        }

        guard let service101 = sampleServices.first(where: { $0.id == 101 }),
              let service102 = sampleServices.first(where: { $0.id == 102 }),
              let service103 = sampleServices.first(where: { $0.id == 103 }),
              let service201 = sampleServices.first(where: { $0.id == 201 }) else {
            return [:]
        }

        return [
            101: pair(service: service101, nowTitle: "Sample Simulcast News", nextTitle: "Sample Local News"),
            103: pair(service: service103, nowTitle: "Sample Simulcast News", nextTitle: "Sample Local News"),
            102: pair(service: service102, nowTitle: "Sample Variety", nextTitle: "Sample Late Show"),
            201: pair(service: service201, nowTitle: "Sample BS Feature", nextTitle: "Sample BS Night")
        ]
    }()
}
