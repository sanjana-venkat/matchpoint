import CoreLocation
import Foundation
import Supabase

struct BackendCommunitySnapshot: Sendable {
    var players: [Player]
    var friendIDs: Set<UUID>
    var incomingRequestIDs: Set<UUID>
    var outgoingRequestIDs: Set<UUID>
    var connectionIDsByPeer: [UUID: UUID]
    var unreadNotificationCount: Int
}

struct BackendInboxSnapshot: Sendable {
    var conversations: [Conversation]
    var participants: [Player]
}

struct BackendMatchbookSnapshot: Sendable {
    var faceOffs: [FaceOff]
    var history: [MatchRecord]
    var participants: [Player]
}

protocol ProductionRepository: Sendable {
    func updateLocation(_ location: CLLocation) async throws
    func clearLocation() async throws
    func fetchCommunity(sport: Sport, radiusMiles: Double) async throws -> BackendCommunitySnapshot
    func fetchInbox() async throws -> BackendInboxSnapshot
    func fetchMatchbook() async throws -> BackendMatchbookSnapshot
    func syncDiscoveredCourts(_ courts: [DiscoveredCourt]) async throws
    func fetchNearbyCommunities(sport: Sport, radiusMiles: Double) async throws -> [NearbyCommunity]
    func fetchCommunityDetail(clubID: UUID) async throws -> CommunityDetailSnapshot
    func createClub(sport: Sport, courtID: UUID, name: String, description: String) async throws -> UUID
    func setClubMembership(clubID: UUID, join: Bool) async throws
    func createCommunityGroup(clubID: UUID, name: String, description: String) async throws -> UUID
    func setCommunityGroupMembership(groupID: UUID, join: Bool) async throws
    func sendConnectionRequest(to playerID: UUID) async throws
    func respondToConnection(id: UUID, accept: Bool) async throws
    func setBlocked(_ blocked: Bool, playerID: UUID) async throws
    func createConversation(sport: Sport, memberIDs: [UUID], title: String?) async throws -> UUID
    func acceptConversation(id: UUID) async throws
    func leaveConversation(id: UUID) async throws
    func sendMessage(_ kind: MessageKind, conversationID: UUID) async throws -> UUID
    func createChallenge(_ draft: BackendChallengeDraft) async throws -> UUID
    func createUploadedMatch(_ draft: BackendUploadedMatchDraft) async throws -> UUID
    func respondToChallenge(id: UUID, accept: Bool, selectedSlotID: UUID?) async throws -> UUID?
    func reportMatchResult(matchID: UUID, winningTeam: Int, scores: [GameScore]) async throws
    func submitPeerReview(matchID: UUID, playerID: UUID, scores: [String: Int], writtenReview: String) async throws
    func markNotificationsRead(ids: [UUID]?) async throws
    func requestAccountDeletion() async throws
    func deleteAccount() async throws
}

struct BackendChallengeParticipant: Sendable {
    let userID: UUID
    let team: Int
}

struct BackendChallengeDraft: Sendable {
    let sport: Sport
    let format: String
    let participants: [BackendChallengeParticipant]
    let proposedStarts: [Date]
    let duration: TimeInterval
    let note: String
    let venue: String?
    let conversationID: UUID?
    let ratingExempt: Bool
}

struct BackendUploadedMatchDraft: Sendable {
    let sport: Sport
    let format: String
    let participants: [BackendChallengeParticipant]
    let startsAt: Date
    let ratingExempt: Bool
}

private struct EmptyParameters: Encodable, Sendable {}

private struct InboxMessageRow: Decodable, Sendable {
    let id: UUID
    let senderID: UUID?
    let kind: String
    let body: String?
    let payload: [String: String]
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case id, kind, body, payload
        case senderID = "sender_id"
        case createdAt = "created_at"
    }
}

private struct InboxRow: Decodable, Sendable {
    let conversationID: UUID
    let sport: Sport
    let title: String?
    let updatedAt: Date
    let isRequest: Bool
    let participantIDs: [UUID]
    let participantNames: [String]
    let participantUsernames: [String]
    let participantAvatarIDs: [String]
    let messages: [InboxMessageRow]
    enum CodingKeys: String, CodingKey {
        case sport, title, messages
        case conversationID = "conversation_id"
        case updatedAt = "updated_at"
        case isRequest = "is_request"
        case participantIDs = "participant_ids"
        case participantNames = "participant_names"
        case participantUsernames = "participant_usernames"
        case participantAvatarIDs = "participant_avatar_ids"
    }
}

private struct MatchbookScoreRow: Decodable, Sendable {
    let id: UUID
    let gameNumber: Int
    let teamOneScore: Int
    let teamTwoScore: Int
    enum CodingKeys: String, CodingKey {
        case id
        case gameNumber = "game_number"
        case teamOneScore = "team_one_score"
        case teamTwoScore = "team_two_score"
    }
}

private struct MatchbookRow: Decodable, Sendable {
    let challengeID: UUID?
    let matchID: UUID?
    let sport: Sport
    let format: String
    let status: String
    let note: String
    let venue: String
    let ratingExempt: Bool
    let proposedByMe: Bool
    let startsAt: Date
    let proposedStarts: [Date]
    let participantIDs: [UUID]
    let participantNames: [String]
    let participantAvatarIDs: [String]
    let myTeam: Int?
    let myReportedTeam: Int?
    let otherReportedTeam: Int?
    let ratingBefore: Int?
    let ratingAfter: Int?
    let opponentRating: Int?
    let scores: [MatchbookScoreRow]
    enum CodingKeys: String, CodingKey {
        case sport, format, status, note, venue, scores
        case challengeID = "challenge_id"; case matchID = "match_id"
        case ratingExempt = "rating_exempt"; case proposedByMe = "proposed_by_me"
        case startsAt = "starts_at"; case proposedStarts = "proposed_starts"
        case participantIDs = "participant_ids"; case participantNames = "participant_names"
        case participantAvatarIDs = "participant_avatar_ids"; case myTeam = "my_team"
        case myReportedTeam = "my_reported_team"; case otherReportedTeam = "other_reported_team"
        case ratingBefore = "rating_before"; case ratingAfter = "rating_after"
        case opponentRating = "opponent_rating"
    }
}

private struct DiscoveredCourtWrite: Encodable, Sendable {
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
    enum CodingKeys: String, CodingKey {
        case name, address, city, region, latitude, longitude, phone, sports
        case externalID = "external_id"
        case postalCode = "postal_code"
        case websiteURL = "website_url"
    }
}

private struct CourtSyncParameters: Encodable, Sendable {
    let courts: [DiscoveredCourtWrite]
    enum CodingKeys: String, CodingKey { case courts = "p_courts" }
}

private struct NearbyCommunityParameters: Encodable, Sendable {
    let sport: Sport
    let radius: Double
    let limit: Int
    enum CodingKeys: String, CodingKey {
        case sport = "p_sport"
        case radius = "p_radius_miles"
        case limit = "p_limit"
    }
}

private struct NearbyCommunityRow: Decodable, Sendable {
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
    let isMember: Bool
    enum CodingKeys: String, CodingKey {
        case name, description, address, city, latitude, longitude
        case courtID = "court_id"
        case clubID = "club_id"
        case distanceMiles = "distance_miles"
        case memberCount = "member_count"
        case groupCount = "group_count"
        case isMember = "is_member"
    }
}

private struct ClubIDParameters: Encodable, Sendable {
    let clubID: UUID
    enum CodingKeys: String, CodingKey { case clubID = "p_club_id" }
}

private struct ClubMembershipParameters: Encodable, Sendable {
    let clubID: UUID
    let join: Bool
    enum CodingKeys: String, CodingKey { case clubID = "p_club_id"; case join = "p_join" }
}

private struct CreateClubParameters: Encodable, Sendable {
    let sport: Sport
    let courtID: UUID
    let name: String
    let description: String
    enum CodingKeys: String, CodingKey {
        case sport = "p_sport"; case courtID = "p_court_id"; case name = "p_name"; case description = "p_description"
    }
}

private struct CommunityMemberRow: Decodable, Sendable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarID: String?
    let role: String
    enum CodingKeys: String, CodingKey { case id, username, role; case displayName = "display_name"; case avatarID = "avatar_id" }
}

private struct CommunityGroupRow: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let memberCount: Int
    let isMember: Bool
    enum CodingKeys: String, CodingKey { case id, name, description; case memberCount = "member_count"; case isMember = "is_member" }
}

private struct CreateCommunityGroupParameters: Encodable, Sendable {
    let clubID: UUID
    let name: String
    let description: String
    let maxMembers: Int?
    enum CodingKeys: String, CodingKey {
        case clubID = "p_club_id"; case name = "p_name"; case description = "p_description"; case maxMembers = "p_max_members"
    }
}

private struct GroupMembershipParameters: Encodable, Sendable {
    let groupID: UUID
    let join: Bool
    enum CodingKeys: String, CodingKey { case groupID = "p_group_id"; case join = "p_join" }
}

private struct UpdateLocationParameters: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    enum CodingKeys: String, CodingKey {
        case latitude = "p_latitude"
        case longitude = "p_longitude"
        case accuracy = "p_horizontal_accuracy_meters"
    }
}

private struct NearbyParameters: Encodable, Sendable {
    let sport: Sport
    let radius: Double
    let limit: Int
    enum CodingKeys: String, CodingKey {
        case sport = "p_sport"
        case radius = "p_radius_miles"
        case limit = "p_limit"
    }
}

private struct NearbyPlayerRow: Decodable, Sendable {
    let id: UUID
    let username: String
    let displayName: String
    let gender: String?
    let ageYears: Int?
    let avatarID: String?
    let bio: String
    let city: String
    let distanceMiles: Double
    let approximateLatitude: Double
    let approximateLongitude: Double
    let sport: Sport
    let rating: Double
    let uncertainty: Double
    let matchesPlayed: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let ratingOptOut: Bool
    let partnerStatus: String
    let homeCourt: String
    let ownsEquipment: Bool
    let playedTournaments: Bool
    let selfAssessment: String
    let socialSkillLabel: String?

    enum CodingKeys: String, CodingKey {
        case id, username, gender, bio, city, sport, rating, uncertainty, wins, losses, draws
        case displayName = "display_name"
        case ageYears = "age_years"
        case avatarID = "avatar_id"
        case distanceMiles = "distance_miles"
        case approximateLatitude = "approximate_latitude"
        case approximateLongitude = "approximate_longitude"
        case matchesPlayed = "matches_played"
        case ratingOptOut = "rating_opt_out"
        case partnerStatus = "partner_status"
        case homeCourt = "home_court"
        case ownsEquipment = "owns_equipment"
        case playedTournaments = "played_tournaments"
        case selfAssessment = "self_assessment"
        case socialSkillLabel = "social_skill_label"
    }
}

private struct ConnectionRow: Decodable, Sendable {
    let id: UUID
    let requesterID: UUID
    let recipientID: UUID
    let status: String
    enum CodingKeys: String, CodingKey {
        case id, status
        case requesterID = "requester_id"
        case recipientID = "recipient_id"
    }
}

private struct NotificationRow: Decodable, Sendable {
    let id: UUID
    let readAt: Date?
    enum CodingKeys: String, CodingKey { case id; case readAt = "read_at" }
}

private struct PlayerIDParameter: Encodable, Sendable {
    let playerID: UUID
    enum CodingKeys: String, CodingKey { case playerID = "p_recipient_id" }
}

private struct ConnectionResponseParameters: Encodable, Sendable {
    let connectionID: UUID
    let accept: Bool
    enum CodingKeys: String, CodingKey {
        case connectionID = "p_connection_id"
        case accept = "p_accept"
    }
}

private struct BlockParameters: Encodable, Sendable {
    let playerID: UUID
    let blocked: Bool
    enum CodingKeys: String, CodingKey {
        case playerID = "p_player_id"
        case blocked = "p_blocked"
    }
}

private struct ConversationParameters: Encodable, Sendable {
    let sport: Sport
    let memberIDs: [UUID]
    let title: String?
    enum CodingKeys: String, CodingKey {
        case sport = "p_sport"
        case memberIDs = "p_member_ids"
        case title = "p_title"
    }
}

private struct ConversationIDParameters: Encodable, Sendable {
    let conversationID: UUID
    enum CodingKeys: String, CodingKey { case conversationID = "p_conversation_id" }
}

private struct MessageParameters: Encodable, Sendable {
    let conversationID: UUID
    let kind: String
    let body: String?
    let payload: [String: String]
    enum CodingKeys: String, CodingKey {
        case conversationID = "p_conversation_id"
        case kind = "p_kind"
        case body = "p_body"
        case payload = "p_payload"
    }
}

private struct ChallengeParticipantWrite: Encodable, Sendable {
    let userID: UUID
    let team: Int
    enum CodingKeys: String, CodingKey { case userID = "user_id"; case team }
}

private struct ChallengeSlotWrite: Encodable, Sendable {
    let startsAt: String
    let endsAt: String
    enum CodingKeys: String, CodingKey { case startsAt = "starts_at"; case endsAt = "ends_at" }
}

private struct ChallengeParameters: Encodable, Sendable {
    let sport: Sport
    let format: String
    let participants: [ChallengeParticipantWrite]
    let slots: [ChallengeSlotWrite]
    let note: String
    let venue: String?
    let conversationID: UUID?
    let ratingExempt: Bool
    enum CodingKeys: String, CodingKey {
        case sport = "p_sport"
        case format = "p_format"
        case participants = "p_participants"
        case slots = "p_slots"
        case note = "p_note"
        case venue = "p_venue_name"
        case conversationID = "p_conversation_id"
        case ratingExempt = "p_rating_exempt"
    }
}

private struct ChallengeResponseParameters: Encodable, Sendable {
    let challengeID: UUID
    let accept: Bool
    let selectedSlotID: UUID?
    enum CodingKeys: String, CodingKey {
        case challengeID = "p_challenge_id"
        case accept = "p_accept"
        case selectedSlotID = "p_selected_slot_id"
    }
}

private struct MatchResultParameters: Encodable, Sendable {
    let matchID: UUID
    let winningTeam: Int
    let scores: [GameScoreWrite]
    enum CodingKeys: String, CodingKey {
        case matchID = "p_match_id"
        case winningTeam = "p_result_team"
        case scores = "p_scores"
    }
}

private struct GameScoreWrite: Encodable, Sendable {
    let teamOneScore: Int
    let teamTwoScore: Int
    enum CodingKeys: String, CodingKey {
        case teamOneScore = "team_one_score"
        case teamTwoScore = "team_two_score"
    }
}

private struct UploadedMatchParameters: Encodable, Sendable {
    let sport: Sport
    let format: String
    let participants: [ChallengeParticipantWrite]
    let startsAt: String
    let ratingExempt: Bool
    enum CodingKeys: String, CodingKey {
        case sport = "p_sport"
        case format = "p_format"
        case participants = "p_participants"
        case startsAt = "p_starts_at"
        case ratingExempt = "p_rating_exempt"
    }
}

private struct PeerReviewParameters: Encodable, Sendable {
    let matchID: UUID
    let playerID: UUID
    let skillScores: [String: Int]
    let writtenReview: String
    enum CodingKeys: String, CodingKey {
        case matchID = "p_match_id"
        case playerID = "p_player_id"
        case skillScores = "p_skill_scores"
        case writtenReview = "p_written_review"
    }
}

private struct MarkReadParameters: Encodable, Sendable {
    let ids: [UUID]?
    enum CodingKeys: String, CodingKey { case ids = "p_ids" }
}

final class SupabaseProductionRepository: ProductionRepository, @unchecked Sendable {
    private let client: SupabaseClient
    private static let isoFormatter = ISO8601DateFormatter()

    init(client: SupabaseClient) { self.client = client }

    func updateLocation(_ location: CLLocation) async throws {
        try await client.rpc("update_my_location", params: UpdateLocationParameters(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy
        )).execute()
    }

    func clearLocation() async throws {
        try await client.rpc("clear_my_location", params: EmptyParameters()).execute()
    }

    func syncDiscoveredCourts(_ courts: [DiscoveredCourt]) async throws {
        guard !courts.isEmpty else { return }
        let writes = courts.prefix(50).map {
            DiscoveredCourtWrite(
                externalID: $0.externalID, name: $0.name, address: $0.address,
                city: $0.city, region: $0.region, postalCode: $0.postalCode,
                latitude: $0.latitude, longitude: $0.longitude,
                websiteURL: $0.websiteURL, phone: $0.phone, sports: $0.sports
            )
        }
        try await client.rpc("sync_discovered_courts", params: CourtSyncParameters(courts: writes)).execute()
    }

    func fetchNearbyCommunities(sport: Sport, radiusMiles: Double) async throws -> [NearbyCommunity] {
        let rows: [NearbyCommunityRow] = try await client.rpc(
            "nearby_courts_and_clubs",
            params: NearbyCommunityParameters(sport: sport, radius: radiusMiles, limit: 100)
        ).execute().value
        return rows.map {
            NearbyCommunity(
                courtID: $0.courtID, clubID: $0.clubID, name: $0.name,
                description: $0.description, address: $0.address, city: $0.city,
                distanceMiles: $0.distanceMiles, latitude: $0.latitude,
                longitude: $0.longitude, memberCount: $0.memberCount,
                groupCount: $0.groupCount, isMember: $0.isMember
            )
        }
    }

    func fetchCommunityDetail(clubID: UUID) async throws -> CommunityDetailSnapshot {
        async let memberRows: [CommunityMemberRow] = client.rpc(
            "club_members", params: ClubIDParameters(clubID: clubID)
        ).execute().value
        async let groupRows: [CommunityGroupRow] = client.rpc(
            "club_groups", params: ClubIDParameters(clubID: clubID)
        ).execute().value
        let (members, groups) = try await (memberRows, groupRows)
        return CommunityDetailSnapshot(
            members: members.map { CommunityMember(id: $0.id, displayName: $0.displayName, username: $0.username, avatarID: $0.avatarID, role: $0.role) },
            groups: groups.map { CommunityGroup(id: $0.id, name: $0.name, description: $0.description, memberCount: $0.memberCount, isMember: $0.isMember) }
        )
    }

    func createClub(sport: Sport, courtID: UUID, name: String, description: String) async throws -> UUID {
        try await client.rpc("create_club", params: CreateClubParameters(
            sport: sport, courtID: courtID, name: String(name.prefix(80)), description: String(description.prefix(1_000))
        )).execute().value
    }

    func setClubMembership(clubID: UUID, join: Bool) async throws {
        try await client.rpc("set_club_membership", params: ClubMembershipParameters(clubID: clubID, join: join)).execute()
    }

    func createCommunityGroup(clubID: UUID, name: String, description: String) async throws -> UUID {
        try await client.rpc("create_community_group", params: CreateCommunityGroupParameters(
            clubID: clubID, name: String(name.prefix(80)), description: String(description.prefix(1_000)), maxMembers: nil
        )).execute().value
    }

    func setCommunityGroupMembership(groupID: UUID, join: Bool) async throws {
        try await client.rpc("set_community_group_membership", params: GroupMembershipParameters(groupID: groupID, join: join)).execute()
    }

    func fetchCommunity(sport: Sport, radiusMiles: Double) async throws -> BackendCommunitySnapshot {
        let userID = try await client.auth.session.user.id
        async let nearbyRequest: [NearbyPlayerRow] = client
            .rpc("find_nearby_players", params: NearbyParameters(sport: sport, radius: radiusMiles, limit: 150))
            .execute().value
        async let connectionRequest: [ConnectionRow] = client
            .from("connections").select().execute().value
        async let notificationRequest: [NotificationRow] = client
            .from("notifications").select("id,read_at").is("read_at", value: nil).execute().value

        let (nearby, connections, notifications) = try await (nearbyRequest, connectionRequest, notificationRequest)
        let players = nearby.map(makePlayer)
        var friends = Set<UUID>()
        var incoming = Set<UUID>()
        var outgoing = Set<UUID>()
        var connectionIDsByPeer: [UUID: UUID] = [:]
        for connection in connections {
            let peer = connection.requesterID == userID ? connection.recipientID : connection.requesterID
            connectionIDsByPeer[peer] = connection.id
            switch connection.status {
            case "accepted": friends.insert(peer)
            case "pending" where connection.recipientID == userID: incoming.insert(peer)
            case "pending": outgoing.insert(peer)
            default: break
            }
        }
        return BackendCommunitySnapshot(
            players: players,
            friendIDs: friends,
            incomingRequestIDs: incoming,
            outgoingRequestIDs: outgoing,
            connectionIDsByPeer: connectionIDsByPeer,
            unreadNotificationCount: notifications.count
        )
    }

    func fetchInbox() async throws -> BackendInboxSnapshot {
        let userID = try await client.auth.session.user.id
        let rows: [InboxRow] = try await client.rpc("my_inbox", params: EmptyParameters()).execute().value
        var participantsByID: [UUID: Player] = [:]
        let conversations = rows.compactMap { row -> Conversation? in
            guard let anchorID = row.participantIDs.first else { return nil }
            for index in row.participantIDs.indices {
                let id = row.participantIDs[index]
                let name = row.participantNames.indices.contains(index) ? row.participantNames[index] : "Player"
                let username = row.participantUsernames.indices.contains(index) ? row.participantUsernames[index] : ""
                let avatarID = row.participantAvatarIDs.indices.contains(index) ? row.participantAvatarIDs[index] : ""
                let avatar = Avatar.all.first(where: { $0.id == avatarID }) ?? .fallback
                var existing = participantsByID[id] ?? Player(
                    id: id, name: name, username: username, gender: .nonBinary, age: 18,
                    avatar: avatar, city: "", distanceMiles: 0, bio: "", profiles: [:]
                )
                if existing.profiles[row.sport] == nil { existing.profiles[row.sport] = SportProfile(sport: row.sport) }
                participantsByID[id] = existing
            }
            let chatMessages = row.messages.map { message in
                ChatMessage(
                    id: message.id,
                    fromMe: message.senderID == userID,
                    kind: decodeMessageKind(message),
                    date: message.createdAt
                )
            }
            return Conversation(
                id: row.conversationID,
                backendID: row.conversationID,
                partnerId: anchorID,
                sport: row.sport,
                messages: chatMessages,
                participantIds: row.participantIDs,
                groupName: row.title,
                isMessageRequest: row.isRequest
            )
        }
        return BackendInboxSnapshot(conversations: conversations, participants: Array(participantsByID.values))
    }

    func fetchMatchbook() async throws -> BackendMatchbookSnapshot {
        let rows: [MatchbookRow] = try await client.rpc("my_matchbook", params: EmptyParameters()).execute().value
        var participantsByID: [UUID: Player] = [:]
        var faceOffs: [FaceOff] = []
        var history: [MatchRecord] = []
        for row in rows {
            guard let opponentID = row.participantIDs.first else { continue }
            let names = row.participantNames.isEmpty ? ["Player"] : row.participantNames
            for index in row.participantIDs.indices {
                let id = row.participantIDs[index]
                let name = names.indices.contains(index) ? names[index] : "Player"
                let avatarID = row.participantAvatarIDs.indices.contains(index) ? row.participantAvatarIDs[index] : ""
                let avatar = Avatar.all.first(where: { $0.id == avatarID }) ?? .fallback
                var participant = participantsByID[id] ?? Player(
                    id: id, name: name, gender: .nonBinary, age: 18, avatar: avatar,
                    city: "", distanceMiles: 0, bio: "", profiles: [:]
                )
                if participant.profiles[row.sport] == nil {
                    participant.profiles[row.sport] = SportProfile(sport: row.sport, rating: row.opponentRating ?? EloRating.start)
                }
                participantsByID[id] = participant
            }
            let myTeam = row.myTeam ?? 1
            let scores = row.scores.map {
                GameScore(
                    id: $0.id,
                    myScore: myTeam == 1 ? $0.teamOneScore : $0.teamTwoScore,
                    opponentScore: myTeam == 1 ? $0.teamTwoScore : $0.teamOneScore
                )
            }
            let state = FaceOffState(rawValue: row.status) ?? .proposed
            let myOutcome = row.myReportedTeam.map { $0 == myTeam ? MatchOutcome.iWon : .theyWon }
            let theirOutcome = row.otherReportedTeam.map { $0 == myTeam ? MatchOutcome.iWon : .theyWon }
            let opponentName = names.joined(separator: " & ")
            let faceOff = FaceOff(
                id: row.matchID ?? row.challengeID ?? UUID(),
                backendChallengeID: row.challengeID,
                backendMatchID: row.matchID,
                sport: row.sport,
                opponentId: opponentID,
                opponentName: opponentName,
                participantIds: row.participantIDs,
                myTeam: myTeam,
                date: row.startsAt,
                proposedDates: row.proposedStarts,
                venue: row.venue,
                wager: "No wager",
                state: state,
                proposedByMe: row.proposedByMe,
                reportedWinnerByMe: myOutcome,
                reportedWinnerByThem: theirOutcome,
                ratingDelta: row.ratingAfter.flatMap { after in row.ratingBefore.map { after - $0 } },
                gameScores: scores,
                isRatingExempt: row.ratingExempt,
                source: row.challengeID == nil ? .unscheduled : .scheduled
            )
            if state == .completed, let reportedTeam = row.myReportedTeam {
                let before = row.ratingBefore ?? EloRating.start
                let after = row.ratingAfter ?? before
                let avatarID = row.participantAvatarIDs.first ?? ""
                history.append(MatchRecord(
                    id: row.matchID ?? UUID(), sport: row.sport, opponentName: opponentName,
                    opponentAvatar: Avatar.all.first(where: { $0.id == avatarID }) ?? .fallback,
                    opponentRatingAtTime: row.opponentRating ?? EloRating.start,
                    didWin: reportedTeam == myTeam, ratingBefore: before, ratingAfter: after,
                    date: row.startsAt, venue: row.venue, wager: "No wager", gameScores: scores,
                    opponentId: opponentID, isRatingExempt: row.ratingExempt,
                    source: row.challengeID == nil ? .unscheduled : .scheduled
                ))
            } else {
                faceOffs.append(faceOff)
            }
        }
        return BackendMatchbookSnapshot(
            faceOffs: faceOffs.sorted { $0.date < $1.date },
            history: history.sorted { $0.date > $1.date },
            participants: Array(participantsByID.values)
        )
    }

    func sendConnectionRequest(to playerID: UUID) async throws {
        try await client.rpc("send_connection_request", params: PlayerIDParameter(playerID: playerID)).execute()
    }

    func respondToConnection(id: UUID, accept: Bool) async throws {
        try await client.rpc("respond_connection_request", params: ConnectionResponseParameters(connectionID: id, accept: accept)).execute()
    }

    func setBlocked(_ blocked: Bool, playerID: UUID) async throws {
        try await client.rpc("set_player_blocked", params: BlockParameters(playerID: playerID, blocked: blocked)).execute()
    }

    func createConversation(sport: Sport, memberIDs: [UUID], title: String?) async throws -> UUID {
        try await client.rpc("create_conversation", params: ConversationParameters(
            sport: sport, memberIDs: memberIDs, title: title
        )).execute().value
    }

    func acceptConversation(id: UUID) async throws {
        try await client.rpc("accept_conversation", params: ConversationIDParameters(conversationID: id)).execute()
    }

    func leaveConversation(id: UUID) async throws {
        try await client.rpc("leave_conversation", params: ConversationIDParameters(conversationID: id)).execute()
    }

    func sendMessage(_ kind: MessageKind, conversationID: UUID) async throws -> UUID {
        let content = messageContent(kind)
        return try await client.rpc("send_chat_message", params: MessageParameters(
            conversationID: conversationID,
            kind: content.kind,
            body: content.body,
            payload: content.payload
        )).execute().value
    }

    func createChallenge(_ draft: BackendChallengeDraft) async throws -> UUID {
        let slots = draft.proposedStarts.prefix(3).map {
            ChallengeSlotWrite(
                startsAt: Self.isoFormatter.string(from: $0),
                endsAt: Self.isoFormatter.string(from: $0.addingTimeInterval(max(1_800, draft.duration)))
            )
        }
        return try await client.rpc("create_challenge", params: ChallengeParameters(
            sport: draft.sport,
            format: draft.format,
            participants: draft.participants.map { ChallengeParticipantWrite(userID: $0.userID, team: $0.team) },
            slots: slots,
            note: String(draft.note.prefix(1_000)),
            venue: draft.venue,
            conversationID: draft.conversationID,
            ratingExempt: draft.ratingExempt
        )).execute().value
    }

    func createUploadedMatch(_ draft: BackendUploadedMatchDraft) async throws -> UUID {
        try await client.rpc("create_uploaded_match", params: UploadedMatchParameters(
            sport: draft.sport,
            format: draft.format,
            participants: draft.participants.map { ChallengeParticipantWrite(userID: $0.userID, team: $0.team) },
            startsAt: Self.isoFormatter.string(from: draft.startsAt),
            ratingExempt: draft.ratingExempt
        )).execute().value
    }

    func respondToChallenge(id: UUID, accept: Bool, selectedSlotID: UUID?) async throws -> UUID? {
        try await client.rpc("respond_to_challenge", params: ChallengeResponseParameters(
            challengeID: id, accept: accept, selectedSlotID: selectedSlotID
        )).execute().value
    }

    func reportMatchResult(matchID: UUID, winningTeam: Int, scores: [GameScore]) async throws {
        try await client.rpc("save_and_report_match_result", params: MatchResultParameters(
            matchID: matchID,
            winningTeam: winningTeam,
            scores: scores.map { GameScoreWrite(teamOneScore: $0.myScore, teamTwoScore: $0.opponentScore) }
        )).execute()
    }

    func submitPeerReview(matchID: UUID, playerID: UUID, scores: [String: Int], writtenReview: String) async throws {
        try await client.rpc("submit_peer_review", params: PeerReviewParameters(
            matchID: matchID,
            playerID: playerID,
            skillScores: scores,
            writtenReview: String(writtenReview.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        )).execute()
    }

    func markNotificationsRead(ids: [UUID]?) async throws {
        try await client.rpc("mark_notifications_read", params: MarkReadParameters(ids: ids)).execute()
    }

    func requestAccountDeletion() async throws {
        try await client.rpc("request_account_deletion", params: EmptyParameters()).execute()
    }

    func deleteAccount() async throws {
        try await client.rpc("delete_my_account", params: EmptyParameters()).execute()
    }

    private func makePlayer(_ row: NearbyPlayerRow) -> Player {
        let gender: Gender
        switch row.gender { case "male": gender = .male; case "female": gender = .female; default: gender = .nonBinary }
        let avatar = Avatar.all.first(where: { $0.id == row.avatarID }) ?? .fallback
        let profile = SportProfile(
            sport: row.sport,
            rating: RatingEngine.publicRating(row.rating),
            uncertainty: row.uncertainty,
            gamesPlayed: row.matchesPlayed,
            wins: row.wins,
            losses: row.losses,
            draws: row.draws,
            ratingOptOut: row.ratingOptOut,
            socialSkillLabel: row.socialSkillLabel.flatMap(SocialSkillLabel.init(rawValue:)),
            partnerStatus: PartnerStatus(rawValue: row.partnerStatus) ?? .solo,
            homeCourt: row.homeCourt,
            ownsEquipment: row.ownsEquipment,
            playedTournaments: row.playedTournaments,
            selfAssessment: SelfAssessment(rawValue: row.selfAssessment) ?? .casual
        )
        return Player(
            id: row.id,
            name: row.displayName,
            username: row.username,
            gender: gender,
            age: row.ageYears ?? 18,
            avatar: avatar,
            city: row.city,
            distanceMiles: row.distanceMiles,
            bio: row.bio,
            profiles: [row.sport: profile],
            approximateLatitude: row.approximateLatitude,
            approximateLongitude: row.approximateLongitude
        )
    }

    private func messageContent(_ value: MessageKind) -> (kind: String, body: String?, payload: [String: String]) {
        switch value {
        case .text(let text): return ("text", text, [:])
        case .image: return ("image", nil, ["attachment": "pending"])
        case .location(let label): return ("location", label, [:])
        case .challenge(let challenge):
            return ("challenge", challenge.note, ["challenge_id": challenge.id.uuidString, "wager": challenge.wager])
        case .faceOff(let faceOff):
            return ("match", faceOff.opponentName, ["match_id": faceOff.id.uuidString])
        case .system(let text): return ("system", text, [:])
        }
    }


    private func decodeMessageKind(_ row: InboxMessageRow) -> MessageKind {
        switch row.kind {
        case "text": return .text(row.body ?? "")
        case "image": return .image
        case "location": return .location(row.body ?? "Shared location")
        case "challenge":
            let id = row.payload["challenge_id"].flatMap(UUID.init(uuidString:)) ?? row.id
            return .challenge(Challenge(id: id, wager: row.payload["wager"] ?? "No wager", note: row.body ?? ""))
        case "system", "match": return .system(row.body ?? "Match update")
        default: return .text(row.body ?? "")
        }
    }
}
