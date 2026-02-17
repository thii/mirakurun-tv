import Foundation

enum MirakurunChannelType: String, Codable, CaseIterable {
    case gr = "GR"
    case bs = "BS"
    case cs = "CS"
    case sky = "SKY"
}

struct MirakurunChannel: Codable, Hashable {
    let type: MirakurunChannelType
    let channel: String
    let name: String?
}

struct MirakurunService: Codable, Identifiable, Hashable {
    let id: Int
    let serviceId: Int
    let networkId: Int
    let name: String
    let type: Int
    let logoId: Int?
    let hasLogoData: Bool?
    let remoteControlKeyId: Int?
    let epgReady: Bool?
    let epgUpdatedAt: Int?
    let channel: MirakurunChannel?

    var isPlayableBroadcast: Bool {
        type == 1 || type == 173
    }
}

struct MirakurunProgram: Codable, Identifiable, Hashable {
    let id: Int
    let eventId: Int
    let serviceId: Int
    let networkId: Int
    let startAt: Int64
    let duration: Int64
    let isFree: Bool
    let name: String?
    let description: String?

    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startAt) / 1000)
    }

    var endDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startAt + duration) / 1000)
    }

    func isCurrent(at date: Date) -> Bool {
        startDate <= date && date < endDate
    }
}

struct MirakurunVersion: Codable {
    let current: String
    let latest: String?
}

struct NowNextProgramPair: Hashable {
    let now: MirakurunProgram?
    let next: MirakurunProgram?

    static func from(programs: [MirakurunProgram], referenceDate: Date = Date()) -> NowNextProgramPair {
        let sorted = programs.sorted { $0.startAt < $1.startAt }
        let now = sorted.first(where: { $0.isCurrent(at: referenceDate) })
        let next: MirakurunProgram?

        if let now {
            next = sorted.first(where: { $0.startDate >= now.endDate })
        } else {
            next = sorted.first(where: { $0.startDate > referenceDate })
        }

        return NowNextProgramPair(now: now, next: next)
    }
}
