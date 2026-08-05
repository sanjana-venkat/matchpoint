import Foundation

/// Hard-coded sample data so the prototype is fully explorable with no backend.
enum MockData {

    static func sampleAvailability(seed: Int) -> [AvailabilitySlot] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let oneOffs: [AvailabilitySlot] = (0..<21).compactMap { offset in
            guard (offset + seed) % 3 != 0,
                  let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let period: AvailabilityPeriod
            switch (offset + seed) % 4 {
            case 0: period = .morning
            case 1: period = .evening
            case 2: period = .midday
            default: period = .evening
            }
            return AvailabilitySlot(date: date, period: period)
        }
        let weekly = [
            AvailabilitySlot(weekday: ((seed + 2) % 7) + 1, period: .evening),
            AvailabilitySlot(weekday: ((seed + 4) % 7) + 1, period: seed.isMultiple(of: 2) ? .midday : .morning)
        ]
        return weekly + oneOffs
    }

    static func emptyMe() -> Player {
        Player(name: "", username: "", gender: .nonBinary, age: 25, avatar: Avatar.fallback,
               city: "Austin", distanceMiles: 0, bio: "", profiles: [:])
    }

    private static func history(from base: Int, days: Int, count: Int) -> [RatingPoint] {
        var pts: [RatingPoint] = []
        var r = base
        for i in stride(from: days, through: 0, by: -max(1, days / count)) {
            r = max(0, r + Int.random(in: -2...3))
            pts.append(RatingPoint(date: Date().addingTimeInterval(TimeInterval(-i * 86400)), rating: r))
        }
        return pts
    }

    static func players() -> [Player] {
        func pball(_ rating: Int, _ status: PartnerStatus, court: String,
                   equip: Bool, tourneys: Bool, assess: SelfAssessment) -> SportProfile {
            SportProfile(sport: .pickleball, rating: rating, partnerStatus: status,
                         homeCourt: court, ownsEquipment: equip, playedTournaments: tourneys,
                         selfAssessment: assess, ratingHistory: history(from: rating, days: 120, count: 24))
        }
        func bmintn(_ rating: Int, _ status: PartnerStatus) -> SportProfile {
            SportProfile(sport: .badminton, rating: rating, partnerStatus: status,
                         homeCourt: "Rec Center", ownsEquipment: true, playedTournaments: false,
                         selfAssessment: .casual, ratingHistory: history(from: rating, days: 120, count: 24))
        }
        func individual(_ sport: Sport, _ rating: Int, _ status: PartnerStatus = .solo) -> SportProfile {
            SportProfile(
                sport: sport,
                rating: rating,
                partnerStatus: status,
                homeCourt: "Community Sports Center",
                ownsEquipment: true,
                selfAssessment: .casual,
                ratingHistory: history(from: rating, days: 120, count: 24)
            )
        }
        func group(_ sport: Sport, seed: Int) -> SportProfile {
            SportProfile(
                sport: sport,
                ratingOptOut: true,
                socialSkillLabel: .social,
                peerSkillRatings: sport.skillCategories.enumerated().map { index, category in
                    PeerSkillRating(
                        category: category,
                        average: min(5, 4.2 + Double((seed + index) % 7) / 10),
                        count: 7 + seed + index * 3
                    )
                },
                selfAssessment: .casual
            )
        }

        var people = [
            Player(name: "Maya Chen", gender: .female, age: 29, avatar: Avatar.all[3],
                   city: "Austin", distanceMiles: 1.2,
                   bio: "New to Austin, obsessed with dinking. Free most evenings.",
                   profiles: [.pickleball: pball(86, .lookingForPartner, court: "Zilker Courts", equip: true, tourneys: true, assess: .competitive),
                              .volleyball: group(.volleyball, seed: 2)]),

            Player(name: "Diego Ramirez", gender: .male, age: 34, avatar: Avatar.all[5],
                   city: "Austin", distanceMiles: 3.8,
                   bio: "3rd-shot drive specialist. Got a partner, looking for teams to scrimmage.",
                   profiles: [.pickleball: pball(93, .hasPartner, court: "Austin Pickle Ranch", equip: true, tourneys: true, assess: .tournament),
                              .soccer: group(.soccer, seed: 4)]),

            Player(name: "Priya Nair", gender: .female, age: 26, avatar: Avatar.all[0],
                   city: "Round Rock", distanceMiles: 12.4,
                   bio: "Weekend warrior. Will play for tacos. 🌮",
                   profiles: [.pickleball: pball(76, .solo, court: "Old Settlers Park", equip: false, tourneys: false, assess: .casual),
                              .badminton: bmintn(82, .solo),
                              .cricket: group(.cricket, seed: 5)]),

            Player(name: "Sam Whitaker", gender: .male, age: 41, avatar: Avatar.all[4],
                   city: "Austin", distanceMiles: 5.1,
                   bio: "Former tennis player converting to pickle. Competitive but chill.",
                   profiles: [.pickleball: pball(83, .lookingForPartner, court: "Pharr Tennis Center", equip: true, tourneys: false, assess: .competitive),
                              .tennis: individual(.tennis, 88)]),

            Player(name: "Aisha Khan", gender: .female, age: 31, avatar: Avatar.all[7],
                   city: "Cedar Park", distanceMiles: 9.7,
                   bio: "Early-morning drills, sunset games. Bring your A-game.",
                   profiles: [.pickleball: pball(89, .hasPartner, court: "Cedar Park Courts", equip: true, tourneys: true, assess: .competitive),
                              .volleyball: group(.volleyball, seed: 6)]),

            Player(name: "Tyler Brooks", gender: .male, age: 23, avatar: Avatar.all[2],
                   city: "Austin", distanceMiles: 2.0,
                   bio: "Just picked up a paddle last month. Down to learn and lose.",
                   profiles: [.pickleball: pball(59, .solo, court: "Any court, honestly", equip: false, tourneys: false, assess: .newbie),
                              .pingPong: individual(.pingPong, 71)]),

            Player(name: "Grace Okafor", gender: .female, age: 37, avatar: Avatar.all[7],
                   city: "Austin", distanceMiles: 4.3,
                   bio: "Banger turned dinker. Wager a beer and let's go. 🍺",
                   profiles: [.pickleball: pball(96, .lookingForPartner, court: "Krieg Fields", equip: true, tourneys: true, assess: .tournament),
                              .football: group(.football, seed: 8)]),

            Player(name: "Leo Martins", gender: .male, age: 28, avatar: Avatar.all[2],
                   city: "Pflugerville", distanceMiles: 14.9,
                   bio: "Consistency over flash. I don't miss third shots.",
                   profiles: [.pickleball: pball(79, .solo, court: "Stone Hill Courts", equip: true, tourneys: false, assess: .casual),
                              .badminton: bmintn(87, .lookingForPartner),
                              .soccer: group(.soccer, seed: 3)]),

            Player(name: "Hannah Lee", gender: .female, age: 24, avatar: Avatar.all[6],
                   city: "Austin", distanceMiles: 6.6,
                   bio: "Social player, big on rec nights. Left-handed lob queen.",
                   profiles: [.pickleball: pball(73, .lookingForPartner, court: "Bartholomew Park", equip: true, tourneys: false, assess: .casual),
                              .baseball: group(.baseball, seed: 2)]),

            Player(name: "Marcus Bell", gender: .male, age: 46, avatar: Avatar.all[1],
                   city: "Austin", distanceMiles: 8.2,
                   bio: "5.0 in a past life. Coaching curious. Ask me about spin serves.",
                   profiles: [.pickleball: pball(112, .hasPartner, court: "Austin Pickle Ranch", equip: true, tourneys: true, assess: .tournament),
                              .squash: individual(.squash, 105)]),
        ]
        for index in people.indices {
            people[index].availability = sampleAvailability(seed: index % 4)
        }
        return people
    }

    static func conversations(players: [Player]) -> [Conversation] {
        guard players.count > 3 else { return [] }
        let maya = players[0], diego = players[1], grace = players[6]
        return [
            Conversation(partnerId: maya.id, sport: .pickleball, messages: [
                ChatMessage(fromMe: false, kind: .text("Hey! Saw you're around my rating — want to hit this week?"), date: Date().addingTimeInterval(-7200)),
                ChatMessage(fromMe: true, kind: .text("Yes! I'm free Thursday evening."), date: Date().addingTimeInterval(-7000)),
            ]),
            Conversation(partnerId: diego.id, sport: .pickleball, messages: [
                ChatMessage(fromMe: true, kind: .challenge(Challenge(wager: "No wager proposed", note: "Best of 3, race to 11.")), date: Date().addingTimeInterval(-90000)),
                ChatMessage(fromMe: false, kind: .text("You're on! When and where? 🔥"), date: Date().addingTimeInterval(-89000)),
            ], wagerProposal: WagerProposal(value: "loser buys tacos 🌮", state: .agreed)),
            Conversation(partnerId: grace.id, sport: .pickleball, messages: [
                ChatMessage(fromMe: false, kind: .text("Wager a beer? 🍺"), date: Date().addingTimeInterval(-200000)),
            ], wagerProposal: WagerProposal(value: "a cold beer 🍺", state: .proposedByThem)),
        ]
    }

    static func faceOffs(players: [Player]) -> [FaceOff] {
        guard players.count > 6 else { return [] }
        let diego = players[1], aisha = players[4]
        return [
            FaceOff(sport: .pickleball, opponentId: diego.id, opponentName: diego.name,
                    date: Date().addingTimeInterval(-5400), venue: "Zilker Courts",
                    wager: "No wager", state: .confirmed),
            FaceOff(sport: .pickleball, opponentId: diego.id, opponentName: diego.name,
                    date: futureDate(days: 3, hour: 17), venue: "Austin Pickle Ranch, Court 4",
                    wager: "loser buys tacos 🌮", state: .confirmed),
            FaceOff(sport: .pickleball, opponentId: aisha.id, opponentName: aisha.name,
                    date: futureDate(days: 6, hour: 18), venue: "Cedar Park Courts",
                    wager: "a cold beer 🍺", state: .confirmed),
        ]
    }

    private static func futureDate(days: Int, hour: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: days, to: .now) ?? .now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    static func matchHistory() -> [MatchRecord] {
        let names = ["Jordan P.", "Casey L.", "Nikhil R.", "Erin S.", "Tom W.", "Bianca G.", "Raj M.", "Chloe D."]
        var records: [MatchRecord] = []
        var rating = EloRating.start
        for i in 0..<14 {
            let opp = Int.random(in: 35...85)
            let didWin = Bool.random()
            let before = rating
            rating = EloRating.newRating(player: rating, opponent: opp, didWin: didWin)
            records.append(
                MatchRecord(sport: .pickleball,
                            opponentName: names[i % names.count],
                            opponentAvatar: Avatar.all[i % Avatar.all.count],
                            opponentRatingAtTime: opp,
                            didWin: didWin,
                            ratingBefore: before,
                            ratingAfter: rating,
                            date: Date().addingTimeInterval(TimeInterval(-(i + 1) * 5 * 86400)),
                            venue: ["Zilker", "Pickle Ranch", "Krieg Fields", "Cedar Park"].randomElement()!,
                            wager: ["a beer 🍺", "tacos 🌮", "$10", "bragging rights"].randomElement()!))
        }
        return records
    }
}
