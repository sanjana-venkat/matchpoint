import Foundation
import Supabase

struct RemoteProfileSnapshot: Sendable {
    let player: Player
    let sports: [Sport]
    let onboardingCompleted: Bool
}

protocol ProfileRepository: Sendable {
    func fetchProfile(userID: UUID) async throws -> RemoteProfileSnapshot
    func saveOnboarding(player: Player, sports: [Sport]) async throws
}

private struct ProfileRow: Codable, Sendable {
    let id: UUID
    let username: String
    let displayName: String
    let birthDate: String?
    let gender: String?
    let avatarID: String?
    let bio: String
    let city: String
    let onboardingCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username, gender, bio, city
        case displayName = "display_name"
        case birthDate = "birth_date"
        case avatarID = "avatar_id"
        case onboardingCompletedAt = "onboarding_completed_at"
    }
}

private struct OnboardingParameters: Encodable, Sendable {
    let username: String
    let displayName: String
    let birthDate: String
    let gender: String
    let avatarID: String
    let bio: String
    let city: String
    let sports: [OnboardingSportWrite]
    let availability: [OnboardingAvailabilityWrite]

    enum CodingKeys: String, CodingKey {
        case username = "p_username"
        case displayName = "p_display_name"
        case birthDate = "p_birth_date"
        case gender = "p_gender"
        case avatarID = "p_avatar_id"
        case bio = "p_bio"
        case city = "p_city"
        case sports = "p_sports"
        case availability = "p_availability"
    }
}

private struct SportProfileRow: Codable, Sendable {
    let userID: UUID
    let sport: Sport
    let rating: Double
    let uncertainty: Double?
    let matchesPlayed: Int?
    let wins: Int?
    let losses: Int?
    let draws: Int?
    let ratingOptOut: Bool
    let partnerStatus: String
    let homeCourt: String
    let ownsEquipment: Bool
    let playedTournaments: Bool
    let selfAssessment: String
    let socialSkillLabel: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case sport, rating, uncertainty, wins, losses, draws
        case userID = "user_id"
        case matchesPlayed = "matches_played"
        case ratingOptOut = "rating_opt_out"
        case partnerStatus = "partner_status"
        case homeCourt = "home_court"
        case ownsEquipment = "owns_equipment"
        case playedTournaments = "played_tournaments"
        case selfAssessment = "self_assessment"
        case socialSkillLabel = "social_skill_label"
        case isActive = "is_active"
    }
}

private struct OnboardingSportWrite: Encodable, Sendable {
    let sport: Sport
    let ratingOptOut: Bool
    let partnerStatus: String
    let homeCourt: String
    let ownsEquipment: Bool
    let playedTournaments: Bool
    let selfAssessment: String
    let socialSkillLabel: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case sport
        case ratingOptOut = "rating_opt_out"
        case partnerStatus = "partner_status"
        case homeCourt = "home_court"
        case ownsEquipment = "owns_equipment"
        case playedTournaments = "played_tournaments"
        case selfAssessment = "self_assessment"
        case socialSkillLabel = "social_skill_label"
        case isActive = "is_active"
    }
}

private struct AvailabilityRow: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let recurrenceWeekday: Int?
    let oneOffDate: String?
    let startTime: String
    let endTime: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case recurrenceWeekday = "recurrence_weekday"
        case oneOffDate = "one_off_date"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

private struct OnboardingAvailabilityWrite: Encodable, Sendable {
    let id: UUID
    let recurrenceWeekday: Int?
    let oneOffDate: String?
    let startTime: String
    let endTime: String
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case id, timezone
        case recurrenceWeekday = "recurrence_weekday"
        case oneOffDate = "one_off_date"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

final class SupabaseProfileRepository: ProfileRepository, @unchecked Sendable {
    private let client: SupabaseClient
    private let dateFormatter: ISO8601DateFormatter

    init(client: SupabaseClient) {
        self.client = client
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func fetchProfile(userID: UUID) async throws -> RemoteProfileSnapshot {
        let profiles: [ProfileRow] = try await client
            .rpc("my_profile", params: EmptyProfileParameters())
            .execute()
            .value
        guard let profile = profiles.first, profile.id == userID else {
            throw ProfileRepositoryError.profileNotFound
        }

        let sportRows: [SportProfileRow] = try await client
            .from("sport_profiles")
            .select()
            .eq("user_id", value: userID.uuidString)
            .eq("is_active", value: true)
            .execute()
            .value

        let availabilityRows: [AvailabilityRow] = try await client
            .from("availability_slots")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        var player = Player(
            id: profile.id,
            name: profile.displayName,
            username: profile.username,
            gender: profile.gender.flatMap(genderFromBackend) ?? .nonBinary,
            age: age(from: profile.birthDate),
            avatar: Avatar.all.first(where: { $0.id == profile.avatarID }) ?? .fallback,
            city: profile.city,
            distanceMiles: 0,
            bio: profile.bio,
            profiles: [:],
            availability: availabilityRows.compactMap(makeAvailability)
        )

        for row in sportRows {
            player.profiles[row.sport] = SportProfile(
                sport: row.sport,
                rating: RatingEngine.publicRating(row.rating),
                uncertainty: row.uncertainty ?? RatingConfiguration.matchPoint.initialUncertainty,
                gamesPlayed: row.matchesPlayed ?? 0,
                wins: row.wins ?? 0,
                losses: row.losses ?? 0,
                draws: row.draws ?? 0,
                ratingOptOut: row.ratingOptOut,
                socialSkillLabel: row.socialSkillLabel.flatMap(SocialSkillLabel.init(rawValue:)),
                partnerStatus: PartnerStatus(rawValue: row.partnerStatus) ?? .solo,
                homeCourt: row.homeCourt,
                ownsEquipment: row.ownsEquipment,
                playedTournaments: row.playedTournaments,
                selfAssessment: SelfAssessment(rawValue: row.selfAssessment) ?? .casual
            )
        }

        return RemoteProfileSnapshot(
            player: player,
            sports: sportRows.filter(\.isActive).map(\.sport),
            onboardingCompleted: profile.onboardingCompletedAt != nil
        )
    }

    func saveOnboarding(player: Player, sports: [Sport]) async throws {
        let parameters = OnboardingParameters(
            username: normalizedUsername(player.username, fallbackID: player.id),
            displayName: player.name,
            birthDate: approximateBirthDate(age: player.age),
            gender: backendGender(player.gender),
            avatarID: player.avatar.id,
            bio: player.bio,
            city: player.city,
            sports: sports.compactMap { sport -> OnboardingSportWrite? in
                guard let value = player.profiles[sport] else { return nil }
                return OnboardingSportWrite(
                    sport: sport,
                    ratingOptOut: value.ratingOptOut,
                    partnerStatus: value.partnerStatus.rawValue,
                    homeCourt: value.homeCourt,
                    ownsEquipment: value.ownsEquipment,
                    playedTournaments: value.playedTournaments,
                    selfAssessment: value.selfAssessment.rawValue,
                    socialSkillLabel: value.socialSkillLabel?.rawValue,
                    isActive: true
                )
            },
            availability: player.availability.map(availabilityWrite)
        )
        try await client.rpc("complete_onboarding", params: parameters).execute()
    }

    private func age(from value: String?) -> Int {
        guard let value, let date = Self.dayFormatter.date(from: value) else { return 18 }
        return max(13, Calendar.current.dateComponents([.year], from: date, to: .now).year ?? 18)
    }

    private func approximateBirthDate(age: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(byAdding: .year, value: -max(13, age), to: .now) ?? .now
        return Self.dayFormatter.string(from: date)
    }

    private func normalizedUsername(_ username: String, fallbackID: UUID) -> String {
        let allowed = username.lowercased().map { character in
            character.isLetter || character.isNumber || character == "_" ? character : "_"
        }
        let collapsed = String(allowed).prefix(24)
        return collapsed.count >= 3 ? String(collapsed) : "player_\(fallbackID.uuidString.prefix(8).lowercased())"
    }

    private func makeAvailability(_ row: AvailabilityRow) -> AvailabilitySlot? {
        guard let period = period(startTime: row.startTime) else { return nil }
        if let weekday = row.recurrenceWeekday {
            return AvailabilitySlot(id: row.id, weekday: weekday, period: period)
        }
        if let dateValue = row.oneOffDate, let date = Self.dayFormatter.date(from: dateValue) {
            return AvailabilitySlot(id: row.id, date: date, period: period)
        }
        return nil
    }

    private func availabilityWrite(_ slot: AvailabilitySlot) -> OnboardingAvailabilityWrite {
        let oneOffDate: String?
        let weekday: Int?
        switch slot.rule {
        case .weekly(let value):
            weekday = value
            oneOffDate = nil
        case .oneOff(let date):
            weekday = nil
            oneOffDate = Self.dayFormatter.string(from: date)
        }
        return OnboardingAvailabilityWrite(
            id: slot.id,
            recurrenceWeekday: weekday,
            oneOffDate: oneOffDate,
            startTime: String(format: "%02d:00:00", slot.period.startHour),
            endTime: String(format: "%02d:00:00", slot.period.endHour),
            timezone: TimeZone.current.identifier
        )
    }

    private func backendGender(_ gender: Gender) -> String {
        switch gender {
        case .male: return "male"
        case .female: return "female"
        case .nonBinary: return "nonBinary"
        }
    }

    private func genderFromBackend(_ value: String) -> Gender? {
        switch value {
        case "male": return .male
        case "female": return .female
        case "nonBinary": return .nonBinary
        default: return nil
        }
    }

    private func period(startTime: String) -> AvailabilityPeriod? {
        guard let hour = Int(startTime.prefix(2)) else { return nil }
        return AvailabilityPeriod.allCases.min { abs($0.startHour - hour) < abs($1.startHour - hour) }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct EmptyProfileParameters: Encodable, Sendable {}

private enum ProfileRepositoryError: LocalizedError {
    case profileNotFound
    var errorDescription: String? { "Your Matchpoint profile could not be loaded." }
}
