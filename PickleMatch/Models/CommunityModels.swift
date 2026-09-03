import Foundation

struct NearbyCommunity: Identifiable, Codable, Sendable {
    var id: UUID { clubID ?? courtID }
    let courtID: UUID
    let clubID: UUID?
    let name: String
    let description: String
    let address: String
    let city: String
    let distanceMiles: Double
    let latitude: Double
    let longitude: Double
    let memberCount: Int
    let groupCount: Int
    var isMember: Bool
    var websiteURL: String? = nil
    var bookingURL: String? = nil

    var isClub: Bool { clubID != nil }
    var locationLine: String {
        [address, city].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct CommunityMember: Identifiable, Codable, Sendable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarID: String?
    let role: String

    var avatar: Avatar { Avatar.all.first(where: { $0.id == avatarID }) ?? .fallback }
}

struct CommunityGroup: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    var memberCount: Int
    var isMember: Bool
}

struct CommunityDetailSnapshot: Sendable {
    let members: [CommunityMember]
    let groups: [CommunityGroup]
}

struct DiscoveredCourt: Identifiable, Sendable {
    let externalID: String
    let name: String
    let address: String
    let city: String
    let region: String
    let postalCode: String
    let latitude: Double
    let longitude: Double
    let websiteURL: String?
    let phone: String?
    let sports: [Sport]

    var id: String { externalID }
}
