# PickleMatch Product Specification and Business Foundation Report

**Audit date:** July 31, 2026  
**Product stage:** Buildable, high-fidelity iOS prototype; pre-production network marketplace  
**Evidence reviewed:** all SwiftUI source, models, state logic, widget code, 19 exported workspace mockups, 12 production image assets, three referenced JSX prototypes, the linked editable Paper canvas, the README, project configuration, and a successful iOS Simulator build.

**Evidence legend used in this report**

- **Implemented / routed:** reachable from the current four-tab app or onboarding.
- **Implemented / secondary:** compiled code that is no longer a primary tab or is reachable only through a related flow.
- **Prototype-only:** visually or behaviorally represented with mock data, simulated replies, generated coordinates, or hard-coded widget content.
- **Reference-only:** retained in exported mockups, Paper, or JSX but not in the current routed SwiftUI product.
- **Production requirement:** required before a real public launch.

The distinction matters. The product is not merely a concept—the app and widget compile—but the visible social graph, active users, conversations, availability, matches, ratings, and most stats are presently local mock data. Only the current user's availability persists through `UserDefaults`.

---

# SECTION 1: EXECUTIVE OVERVIEW & CORE CONCEPT

## 1. Core Value Proposition

PickleMatch is a local racket-sports coordination network that converts four fragmented tasks—finding a compatible player, discovering mutual free time, agreeing on a match, and recording a trustworthy result—into one continuous loop.

For pickleball and badminton players, the app answers the practical question that rating apps, court directories, and group chats usually answer only in pieces: **“Who near me is at my level, when are we both free, and how do we turn that overlap into a completed match that improves future recommendations?”**

Its proposed value is not another player directory. Its value is **time-to-play compression**:

1. Rank candidates using sport, geography, level, intent, and availability.
2. Let users discover candidates through personalized shelves or a zoomable map.
3. Move a player into direct or group chat without losing match context.
4. Surface the next overlapping availability as immediately actionable time pills.
5. Negotiate an optional social wager explicitly and consensually.
6. Confirm venue and time as a structured face-off.
7. Launch a focused live-match mode, record multiple game scores, and resolve the outcome.
8. Update an Elo-style rating, performance history, recommendations, and the next-match widget.

This creates a closed behavioral loop:

`discover → coordinate → commit → play → verify → improve matching → repeat`

The strongest strategic interpretation is **“the availability and commitment layer for local amateur racket sports.”** Discovery attracts users; completed, verified games create the durable data asset.

## 2. Primary Elevator Pitch

Most amateur racket-sports players do not stop playing because they dislike the sport. They stop because organizing a fair game is work. Player discovery lives in one app, court information in another, availability in a group chat, and scores or ratings somewhere else—if they are recorded at all.

PickleMatch turns that fragmented process into one consumer workflow. A player selects pickleball or badminton, receives a baseline match rating, saves normal play windows, and sees compatible nearby players. The app automatically identifies mutual availability inside chat, converts a chosen window into a scheduled face-off, supports optional agreed wagers, and opens a distraction-free live scoring experience when the match begins. Verified results update each player's rating and improve the next set of recommendations.

The business is a local network marketplace with a measurable transaction: a verified match completed. Consumer liquidity creates the wedge; subscriptions, organizer tools, booking/referral economics, and club infrastructure create monetization. The defensible asset is not a profile list—it is a local compatibility graph combining who plays, who is trustworthy, who is similarly skilled, when people are actually free, where they will play, and which introductions become repeat matches.

## 3. Core Philosophy

### Product philosophy

- **Optimize for matches completed, not profiles browsed.** A swipe, chat, or map tap has little standalone value. The core outcome is a completed, mutually recognized game.
- **Availability is first-class product data.** Free time is collected once in onboarding, editable in Profile, compared automatically in chat, and converted into structured proposals. Users should not repeatedly type “When are you free?”
- **Coordination belongs inside the conversation.** Challenge, wager, shared openings, scheduling, venue, face-off status, result reporting, and safety controls are part of chat context rather than disconnected utilities.
- **Ratings are earned, not self-marketed.** Everyone currently starts at 50. Verified match outcomes move the number. Self-assessment informs tone and intent but must not be represented as the same thing as earned skill.
- **Multi-sport identity; sport-specific performance.** A person has one social identity and availability calendar, but separate pickleball/badminton ratings, profiles, matches, and recommendations.
- **Privacy before precision.** The character system avoids mandatory photos. A production map should expose coarse or venue-centered presence rather than exact live home coordinates.
- **Consent before stakes.** A wager is not embedded in the first challenge. It is proposed in chat, accepted by the other player, or explicitly skipped.
- **Progressive commitment.** Browsing is low commitment; messaging is higher; choosing a shared time is higher; a confirmed match is higher; live score and mutual verification complete the transaction.
- **A coherent “Court Glass” design system.** The current system uses deep forest backgrounds (`#07110E`), forest surfaces (`#121E1A`), warm white text (`#F4F3ED`), mint action color (`#38E0B1`), secondary blue for another player's calendar, Avenir Next typography, rounded cards, capsules, illustrated avatars, and selective pink/grape/lime accents.
- **System accessibility over aesthetic novelty.** The implementation already uses semantic labels for map pins, widget summaries, calendar ownership, and several controls; honors Reduce Motion in live-match and reusable button interactions; and uses relative custom fonts. Production quality requires larger minimum text, non-color state cues, comprehensive Dynamic Type QA, and VoiceOver journey testing.

### Product architecture

The current prototype uses one `@MainActor` observable `AppState` as an in-memory source of truth. It holds onboarding identity, sport profiles, mock community data, filters, chats, availability, face-offs, match history, rating history, and derived stats. This is effective for rapid prototyping but must be decomposed for production into identity, profile, presence, recommendation, conversation, availability, match, rating, moderation, notification, and analytics services.

### Rating model currently implemented

The app uses an Elo-style 1–100 scale:

`Expected(A) = 1 / (1 + 10^((R_B - R_A) / 25))`

`NewRating(A) = clamp(1, 100, round(R_A + 16 × (S_A - Expected(A))))`

where `S_A = 1` for a win and `0` for a loss. Everyone starts at 50. Tiers are Beginner (1–24), Improver (25–44), Intermediate (45–59), Advanced (60–74), Competitive (75–89), and Elite (90–100).

Illustrative behavior:

| Match situation | Expected win probability | Rating impact if lower-rated player wins | Rating impact if lower-rated player loses |
|---|---:|---:|---:|
| Equal ratings | 50.0% | +8 | −8 |
| 10-point underdog | 28.5% | about +11 | about −5 |
| 20-point underdog | 13.7% | about +14 | about −2 |
| 30-point underdog | 5.9% | about +15 | about −1 |

This is understandable and demo-friendly. It is not yet launch-grade because it does not account for provisional ratings, uncertainty, doubles partner/opponent composition, margin of victory, sport format, inactivity, collusion, disconnects, disputed results, or confidence based on match count.

### Business foundation and metric system

The North Star should be **Verified Matches Completed per Weekly Active Player (VMC/WAP)**, not MAU or messages sent.

Supporting funnel definitions:

- `Discovery-to-chat = unique conversations started / unique profile-detail viewers`
- `Chat-to-proposal = structured match proposals / active match-intent conversations`
- `Proposal acceptance = accepted proposals / proposals sent`
- `Schedule-to-play = verified completed matches / confirmed face-offs`
- `Time-to-first-match = median(completion timestamp − account creation timestamp)`
- `Repeat-opponent rate = players with a second verified match against any prior opponent within 30 days / players with one verified match`
- `Local liquidity = users receiving at least 5 compatible candidates and 2 mutual openings within 7 days / eligible active users`
- `Safety rate = substantiated safety incidents / 1,000 completed matches`
- `Rating integrity = mutually confirmed non-disputed results / all submitted results`

A useful compatibility model for recommendation is:

`C(u,v) = Sport × Geo × Skill × Availability × Intent × Trust × Freshness`

Each factor should be normalized to `[0,1]`; a hard zero on sport or acceptable geography should remove a candidate. The product should maximize expected completion, not superficial similarity:

`P(completed match | u,v) = P(reply) × P(shared time) × P(agreement) × P(show) × P(verification)`

The local-market activation criterion should therefore be operational: launch a neighborhood/city only when at least 70% of target users can receive five compatible candidates and two shared availability windows inside seven days. This is a proposed target, not observed performance.

The initial business-model hypothesis should be freemium:

- Free: profile, discovery, map, chat, availability, match scheduling, basic rating, and basic scoring.
- Consumer Plus ($7.99–$11.99/month test range): advanced filters, expanded radius/travel mode, richer analytics, unlimited groups, recurring availability, priority discovery, and partner offers.
- Organizer/Club ($49–$199/month test range): roster, session creation, waitlists, round robins, court inventory, verified result import, leaderboards, and member analytics.
- Transaction/referral revenue: court booking, event entry, lessons, equipment, or insurance—not cash wagers.

Illustrative unit economics, clearly treated as a planning scenario: at $9.99 monthly subscription, 85% net revenue after platform/payment effects, and 4% monthly paid churn, contribution LTV is approximately `$9.99 × 0.85 / 0.04 = $212`. A target CAC below $64 gives a 3.3× LTV:CAC ratio; payback is about `64 / (9.99 × .85) = 7.5 months`. These are decision thresholds, not forecast results.

---

# SECTION 2: PROBLEM SPACE & MARKET GAP ANALYSIS

## 1. Market Problems Tackled

### Fragmented amateur-sports workflow

The category is split among court directories, booking systems, rating databases, event schedulers, team/group messengers, tournament tools, and generic social platforms. Players assemble a game manually across several systems. Every handoff loses context: the chosen player, level expectation, free time, court, stakes, score, and post-match history.

### Local network liquidity is invisible

A city may contain thousands of players but still feel empty to one user because compatibility is constrained by sport, travel radius, level, gender preference, play intent, and schedule. Traditional directories display inventory; they do not reliably calculate who can actually meet.

### Scheduling is conversational labor

Most casual matches are negotiated through repeated asynchronous messages. The cost is not entering one time; it is maintaining several people's availability, recognizing overlap, proposing a venue, and reconciling changes. Group chats scale this friction multiplicatively.

### Ratings are disconnected from discovery and behavior

Ratings can help produce fair games, but a rating that lives in a separate system does not necessarily improve local recommendations or explain the immediate impact of a result. Conversely, self-selected “beginner/intermediate/advanced” labels are inconsistent and susceptible to social desirability bias.

### Informal matches generate little trusted data

Casual players play many games that never enter a rating system. If results are entered unilaterally, trust suffers. If verification is too heavy, people do not log them. The product must minimize input while preserving opponent consent and dispute handling.

### Presence and privacy conflict

“Active nearby” is valuable but exact location sharing creates safety risk. A production product must model active intent and coarse presence without exposing persistent precise coordinates.

### Venue and player supply are poorly connected

Court platforms optimize bookings; player networks optimize connections. Empty spots, idle courts, compatible players, and overlapping availability are rarely matched as one supply-demand problem.

## 2. Detailed User Pain Points

### Functional pain points

- “I want to play tonight, but I do not know who is both nearby and free.”
- “I cannot tell whether someone who says ‘intermediate’ will create a fair game.”
- “I have contacts, but scheduling four people takes dozens of messages.”
- “The group agreed vaguely, but no one committed to a specific time or court.”
- “I forgot the match details because they were buried in chat.”
- “We played three games, but the result and rating impact were never recorded.”
- “I play two sports and do not want two identities, calendars, and friend graphs.”
- “I need gear, a doubles partner, or a home court, but generic profiles do not communicate that context.”
- “Map search expands visually, but conventional lists do not explain the area being searched.”
- “I want to start scoring quickly at court without navigating several screens.”

### Emotional pain points

- Anxiety about approaching strangers or being judged for skill.
- Fear of wasting another player's time through a bad skill match.
- Social fatigue from repeated rejection, unanswered messages, and scheduling loops.
- Embarrassment about uploading a profile photo or concern about appearance-based discovery.
- Frustration after a loss when rating movement feels arbitrary.
- Uncertainty about safety, legitimacy, and whether a new player will show up.
- Loss of momentum when a promising chat never becomes a game.

### Economic pain points

- Paid court time wasted by incomplete groups or no-shows.
- Higher search and organizer labor for clubs, captains, and recurring groups.
- Paying for multiple subscriptions that solve only ratings, booking, or event organization.
- Poor player-level matching reducing retention for venues and leagues.
- Underutilized off-peak court inventory.

### Pain-to-feature mapping

- Compatibility uncertainty → earned rating, rating-aware recommendations, sport-specific profiles.
- Availability negotiation → persistent play windows, overlap engine, immediate shared-time pills.
- Commitment ambiguity → structured proposals, venue field, face-off confirmation, upcoming-match card/widget.
- Result friction → live timer, multi-game score controls, Elo preview, confirmation/dispute states.
- Photo reluctance → branded character avatars.
- Group coordination → group chat creation and all-participant overlap.
- Safety → block/report controls; production identity, presence privacy, and moderation remain required.

## 3. Competitor Landscape & Newcomer Advantage

### What the evidence says

A literal claim that “this combination does not exist anywhere” is not supportable in 2026. Several products overlap significantly:

- [DUPR](https://www.dupr.com/) combines pickleball ratings, match result entry, history/analytics, nearby player connection, clubs, and events. It reports more than one million rated players, 12,000+ clubs, 183 countries, and 10M+ logged matches.
- [Pickleheads](https://www.pickleheads.com/) combines a large court/game finder, groups, recurring schedules, messaging, waitlists, payments, leagues/ladders/tournaments, and DUPR result integration. Its group product explicitly supports calendars, group/session/direct chat, skill constraints, and validated score submission.
- [Playtomic](https://playerhelp.playtomic.com/hc/en-gb/articles/19831629310481-Community-Match-Play-on-Any-Court-Anywhere) combines booking, public/open matches, community matches, player chat, calendar export, level-based participation, notifications, and payments in its supported sports/markets.
- [RacketPal](https://play.google.com/store/apps/details?id=com.racketpal) markets nearby player discovery, chat, match organization, skill matching, public games, leagues, and multiple racket sports including badminton.
- [Playminton](https://playminton.app/) explicitly combines badminton clubs, court booking, open matches, level/schedule matching, player connection, and chat, initially focused on Bali.
- Emerging products such as [All in Badminton](https://allinbadminton.com/), [Kreeda](https://www.kreeda.net/), and [Paero](https://paero.app/) claim combinations of discovery, Elo-like ratings, match logs, clubs, and multi-sport ladders.

Therefore, investors should not be told the app is defensible because no adjacent feature bundle exists. That assertion would fail basic diligence. The credible differentiation must be narrower, behaviorally measurable, and executed better.

### Where incumbent and adjacent solutions leave room

| Competitive archetype | Strength | Typical gap PickleMatch can target |
|---|---|---|
| Rating network (DUPR) | Trusted rating identity, result volume, club integrations | Rating is the center; availability-first conversion from individual discovery to a scheduled casual match is not the primary product thesis |
| Court/game directory (Pickleheads) | Court data, sessions, organizer tooling, large pickleball community | Strong organized-session model; less differentiated around persistent individual availability graphs, live match UX, and a cross-sport social identity |
| Booking marketplace (Playtomic) | Venue inventory, payments, open matches, international racket-sport footprint | Venue supply is primary; community matches may still leave court coordination/payment responsibility to users outside integrated venues |
| Player-matching social app (RacketPal/Paero) | Multi-sport discovery and communication | Must prove local density, schedule overlap quality, rating integrity, and a distinctive completion loop |
| Club/league software | Structured operations, brackets, rosters, admin controls | Designed around organizers and pre-existing communities, not spontaneous individual demand and friend-like retention |
| Generic chat/calendar | Universal reach and existing habits | No skill model, sport intent, local discovery, match object, live scoring, or rating consequence |

### Defensible newcomer thesis

The proposed newcomer advantage is **availability-to-verification integration**, not feature novelty alone:

1. **Persistent availability graph:** model reusable play windows for every member, then compute group intersections automatically.
2. **Commitment objects inside chat:** a shared time, venue, wager state, and match state are structured data—not unsearchable text.
3. **Completion-aware recommendations:** ranking learns from reply, proposal, acceptance, attendance, repeat-play, safety, and verification behavior.
4. **Sport-specific performance on one identity:** pickleball and badminton share trust, social connections, and availability while maintaining separate ratings.
5. **Distinctive non-photo brand identity:** coherent illustrated characters reduce appearance pressure and can become ownable IP if created and governed consistently.
6. **On-court operating mode:** countdown, timer, multi-game scoring, wager reminder, outcome celebration, rating delta, and next-opponent recalibration close the loop at the moment competitors often hand off.

### Defensibility and moat construction

The moat is not present at prototype stage. It must be built through four compounding assets:

- **Local liquidity moat:** enough compatible players and available windows in each micro-market that new entrants cannot offer equivalent time-to-match.
- **Compatibility graph:** sport, rating, availability, travel, intent, response, attendance, repeat-play, and safety outcomes form a higher-signal recommendation dataset.
- **Trust graph:** verified identities, mutual match confirmation, dispute history, no-show reliability, organizer verification, and club imports.
- **Distribution moat:** venue/club partnerships, ambassador-led city launches, university/corporate groups, and shareable confirmed-match artifacts.

The network effect should be measured as a causal loop:

`more qualified local players → more shared openings → shorter time-to-match → more completed matches → better ratings/recommendations → higher retention → more qualified local players`

Primary strategic risk: this loop is hyperlocal. National registrations do not guarantee neighborhood liquidity. The launch strategy must seed one compact geography and one sport/daypart at a time rather than advertise broadly.

---

# SECTION 3: TARGET AUDIENCE & USER PERSONAS

## 1. Primary User Personas

### Persona A — The New-to-City Social Player

- **Profile:** 22–35, urban/suburban renter or young professional, new resident or socially rebuilding, moderate discretionary income.
- **Psychographics:** values low-pressure connection, activity-based friendships, and spontaneity; dislikes networking events and appearance-driven social apps.
- **Daily habits:** checks phone frequently, works hybrid, has evening/weekend availability, uses maps, messaging, and social discovery naturally.
- **Tech fluency:** high; expects instant feedback and transparent privacy.
- **Core need:** convert “I want to play” into one safe, compatible person and time without entering an established clique.
- **Success moment:** receives a reply and finds a shared opening within the first session; completes first match within seven days.
- **Retention hook:** repeat opponents, group formation, streaks, improving rating, stronger local social graph.

### Persona B — The Busy Intermediate Regular

- **Profile:** 28–48, employed, often partnered/parenting, plays one to three times weekly, owns gear, knows several courts.
- **Psychographics:** values reliability and fair competition more than novelty; frustrated by organizer overhead and mismatched levels.
- **Daily habits:** calendar-driven; plans around work and family; opens sports apps around lunch or late evening.
- **Tech fluency:** moderate to high; will use automation if it saves messages.
- **Core need:** find a fair game that fits narrow windows and avoid no-shows.
- **Success moment:** taps a mutual-availability pill, confirms a court, and gets a widget reminder without negotiation.
- **Retention hook:** reliable regulars, accurate rating, upcoming-match hub, calendar synchronization, performance history.

### Persona C — The Competitive Progress Seeker

- **Profile:** 18–45, plays multiple times weekly, participates in ladders/round robins/tournaments, tracks improvement.
- **Psychographics:** achievement-oriented, responds to clear rules and credible ratings, skeptical of self-reported skill.
- **Daily habits:** follows sports content, records workouts, compares performance, seeks stronger opponents.
- **Tech fluency:** high for performance tools.
- **Core need:** find opponents near the optimal challenge range and make informal matches count.
- **Success moment:** sees expected rating impact, records a best-of-three, receives mutual confirmation, and gets recalibrated recommendations.
- **Retention hook:** rating history, verified record, top-scorer visibility, analytics, challenges, leagues.

### Persona D — The Group Organizer / Court Captain

- **Profile:** 30–60, informal community leader, club volunteer, university/corporate recreation lead, or recurring-session captain.
- **Psychographics:** generous but overloaded; wants fairness and attendance certainty; becomes a distribution node if the app removes administrative work.
- **Daily habits:** manages multiple group chats/spreadsheets, chases responses, fills last-minute vacancies.
- **Tech fluency:** moderate; expects bulk operations, clear statuses, and calendar reliability.
- **Core need:** create a group, identify the next overlap, fill spots, and record results without being the human scheduler.
- **Success moment:** schedules a four-person match from combined availability with minimal follow-up.
- **Retention hook:** recurring windows, rosters, waitlists, substitutions, payments, venue tools, leaderboards.

### Persona E — The Multi-Sport Racket Player

- **Profile:** 20–50, alternates between pickleball and badminton based on weather, venue, season, or social group.
- **Psychographics:** identity is “racket-sports person,” not one-sport loyalist; values variety and transferable relationships.
- **Daily habits:** plays opportunistically, uses different venues and groups for each sport.
- **Tech fluency:** moderate to high.
- **Core need:** one identity and calendar, separate skill signals and discovery feeds.
- **Success moment:** switches sport pills and receives a correctly filtered map, feed, chats, matches, and rating.
- **Retention hook:** cross-sport availability utilization and lower app fragmentation.

## 2. Secondary & Ecosystem Stakeholders

- **Court facilities and clubs:** want utilization, qualified demand, lower no-show rates, recurring players, and booking conversion.
- **Tournament/league operators:** want verified identity, seeding, registration, brackets, result import, and communication.
- **Coaches:** want player leads, objective development history, assessment sessions, and recommendations.
- **Universities, employers, and residential communities:** want lightweight recreation programming and community formation.
- **National/local sport associations:** want participation growth, safe-play standards, and interoperable ratings/results.
- **Equipment brands and retailers:** want contextual commerce at moments of need, but must not distort recommendations.
- **Moderation and trust operations:** require reports, evidence, block graphs, identity signals, appeals, and incident tooling.
- **Customer support/admins:** need account recovery, match correction, dispute resolution, data export/deletion, and audit trails.
- **Friends/spectators:** may receive share links, watch scores, or encourage participation; they should not see precise presence or private wagers.
- **Platform actors:** Apple Maps/MapKit, push notification services, calendar providers, payment processors, booking partners, and analytics vendors.

## 3. Jobs-To-Be-Done (JTBD)

### Functional jobs

- When I unexpectedly have free time, show me people I can realistically play soon.
- When I evaluate a stranger, help me judge sport fit, skill, distance, intent, equipment, and reliability.
- When several people want to play, identify overlap without a scheduling thread.
- When we agree, create a concrete time, venue, participants, sport, and wager state.
- When the match starts, let me track multiple games without distraction.
- When the match ends, update a credible record with opponent confirmation and a clear rating explanation.
- When plans change, let participants edit, cancel, reschedule, or substitute without losing context.
- When I play another sport, preserve my identity and calendar but switch performance context.

### Social jobs

- Help me meet people through an activity so conversation is less awkward.
- Help me signal competitiveness or social intent without writing a long bio.
- Help me build a reliable circle of regular partners and rivals.
- Help me gain standing in a local community through verified play rather than follower counts.
- Help me invite others into a group without becoming the permanent organizer.

### Emotional jobs

- Give me confidence the match will be fair and the other person will show up.
- Reduce rejection anxiety by making intent and availability explicit.
- Make scheduling feel light rather than burdensome.
- Let me participate without uploading a personal photo.
- Make wins satisfying and losses constructive rather than punitive or opaque.
- Help me feel momentum: there is always a credible next match.

---

# SECTION 4: COMPREHENSIVE FEATURE MATRIX & PURPOSE MAPPING

The table covers routed SwiftUI, compiled secondary views, meaningful states, the widget, assets, and reference concepts. Status is embedded in the functional description because the requested column structure is preserved exactly.

| Feature Name | Category / Module | Detailed Functional Description | User Pain Point Solved | Strategic Purpose & Business Value |
|---|---|---|---|---|
| Root onboarding gate | App shell | **Implemented/routed.** `RootView` shows onboarding until `hasCompletedOnboarding`, then dissolves into the four-tab app. Debug flags can launch specific demo states. Completion itself is not persisted. | Separates first-time education from ongoing use. | Enables staged activation measurement; production needs authenticated persistence and resumable onboarding. |
| Editorial welcome story | Onboarding | Three full-screen illustrated pages: find players, join games/climb ranks, build community; page indicator and consistent capsule CTA; opacity transitions replace swipe paging. | Explains value before requesting profile data. | Establishes category, brand, and intent; supports onboarding A/B testing. |
| Sport selection | Onboarding | Multi-select badminton/pickleball rows with check states; at least one is required. | Avoids irrelevant discovery and supports multi-sport users. | Creates two liquidity pools while preserving one identity; risk of splitting early density. |
| Play-style selection | Onboarding | Newbie, casual/social, or competitive selection plus optional notes. Tournament exists in the model/legacy screen but is not shown in the current three-option UI. | Provides intent when earned rating is initially uninformative. | Cold-start recommendation input; should remain distinct from skill rating. |
| “How it works” education | Onboarding | Three cards explain find people, lock a shared time, and play/score/grow. States all users start at 50 and earn rating through verified matches. | Reduces confusion about assigned baseline and app workflow. | Sets behavioral expectations and trust in the rating loop. |
| Baseline Match Rating | Rating | All selected sports begin at 50; tier is Intermediate. | Removes unreliable self-assigned numeric skill. | Creates a common system, but provisional uncertainty is required to avoid misleading precision. |
| Onboarding availability calendar | Onboarding / Availability | Current/future month editor; select a date and any Morning 7–10, Midday 11–2, Evening 5–9 windows; past dates disabled. | Prevents repeated “when are you free?” negotiation. | Core differentiation and compatibility data; current model uses coarse one-off windows rather than recurring rules. |
| Identity details | Onboarding | Name, age, gender, character selection; optionality copy; stores notes as bio. Birthday is referenced in copy but the model stores age, not date of birth. | Gives enough context for trust and filtering without mandatory photo. | Profile completion and moderation substrate; production needs privacy controls and age eligibility. |
| Character avatar system | Identity / Brand | Eight illustrated human characters with fallback, selectable during onboarding and Profile; no photo required. | Reduces appearance pressure and upload friction. | Ownable brand/IP and inclusive identity system; needs provenance/licensing governance and broader customization. |
| Sport mode switcher | Global navigation | Header capsule switches active sport; all feeds, ratings, chats, map players, matches, and profile stats use that context. Hidden as a switch when only one sport is enrolled. | Avoids separate accounts and irrelevant cross-sport data. | Increases cross-sport retention; requires unambiguous active-mode state and sport-aware deep links. |
| Four-tab architecture | Navigation | **Implemented/routed:** Home, Map, Chat, Profile. Older Discover, Calendar, and Stats screens remain compiled but are no longer primary tabs. | Provides stable mental model around intent, place, coordination, and identity. | Keeps v1 navigation focused; avoids feature sprawl. |
| Personalized Home hero | Home | Greeting, brand mark, current avatar, count of nearby active-sport players. | Quickly orients the user to available supply. | Creates perceived liquidity; “active” is currently mock-only and must be truthful. |
| Upcoming matches | Home | Up to two confirmed/awaiting matches show date, opponent/group, time, venue, and wager. | Prevents confirmed plans from being buried in chat. | Drives return sessions and match completion. |
| Start-game eligibility | Home | Circular Start appears within one hour before through six hours after scheduled time; otherwise relative date/time is shown. | Makes on-court entry fast and prevents accidental early starts. | Critical transaction conversion; production needs late/cancelled/no-show states and timezone handling. |
| Quick Match hub | Home | Branded card shows current rating, “find your next rival,” explanation, CTA, streak, wins, and win rate. | Gives a clear primary action and progress context. | Concentrates discovery intent and activation; current CTA opens only the first ranked player, not a dedicated result set. |
| “For you” shelf | Home / Recommendation | Sorts players by twice the absolute rating difference plus integer distance; displays featured player cards. | Reduces candidate search effort. | Prototype recommendation wedge; production should optimize completion probability, safety, and freshness. |
| “People also played with” shelf | Home / Social proof | Current prototype sorts by self-assessment string rather than behavioral co-play data. | Intended to use social similarity to build trust. | **Prototype-only semantic gap:** label promises collaborative filtering that is not implemented. |
| “Top scorers this week” shelf | Home / Competition | Sorts by static overall rating, not week-specific points or results. | Helps competitive users discover strong opponents. | **Prototype-only semantic gap:** requires weekly event data and fair exposure rules. |
| “Most frequently played” shelf | Home / Engagement | Displays deterministic fake monthly game counts derived from player names. | Surfaces reliable/high-activity candidates. | **Prototype-only semantic gap:** production should use verified completion/attendance, not activity popularity alone. |
| Player cards | Home | Avatar, rating/tier, name, distance/city, play style, bio or game-count badge. | Supports fast comparison without profile overload. | Core recommendation inventory; must add trust/reliability and availability signals. |
| Player quick sheet | Home / Map | Age near name, distance/city, rating, partner status, play style, gear, bio, then vertically stacked Challenge and Message actions. | Clarifies hierarchy and presents next actions consistently. | Converts discovery into coordination; shared component reduces design drift. |
| Challenge composer | Challenge | Shows opponent/rating, explains wager will be decided together, accepts optional match note, sends structured challenge. | Makes intent explicit without prematurely forcing time or stakes. | High-intent activation event and notification trigger. |
| Zoomable nearby-player map | Map | Native MapKit view centered on Austin; zoom changes an estimated radius from 1–50 miles and visible player count. Current coordinates are generated offsets. | Supports spatial discovery and radius expansion. | Strong discovery surface; production requires location permission, geospatial querying, clustering, and privacy zones. |
| Map player pins | Map | Illustrated avatar pin with sport rating; tap opens the same quick sheet. | Makes map candidates recognizable and comparable. | Visualizes local liquidity and drives profile conversion. |
| Map gender filter | Map / Filters | Menu filters by Woman, Man, Non-binary, or Prefer not to say; reset available. | Supports comfort, partner format, and preference. | Useful but sensitive; must prevent discriminatory misuse and explain purpose/privacy. |
| Map rating filter | Map / Filters | All, 1–40, 41–65, 66–100 bands. | Reduces mismatch. | Improves conversion but bands do not align exactly with all six tier thresholds. |
| “Active now” map chip | Map / Presence | Visually active chip and LIVE label, but there is no presence field or toggle behavior; every mock candidate is treated as active. | Intended to find immediate partners. | **Prototype-only and high trust risk.** Must not ship until backed by explicit, expiring presence consent. |
| Recenter control | Map | Returns camera to hard-coded Austin center. | Helps recover after pan/zoom. | Required map usability; production centers on coarse current/user-selected area. |
| Conversation list | Chat | Sport-specific direct/group conversations with character, title, preview, rating, blocked state, and create-group control. | Keeps match relationships organized. | Retention surface; needs unread counts, timestamps, sync, delivery, and notifications. |
| Simulated chat replies | Chat / Prototype | Local text/challenge send triggers canned reply after 1.1 seconds. | Makes demos feel responsive. | **Prototype-only:** must never be confused with real user communication. |
| Direct text messages | Chat | Multiline composer, disabled empty send, message bubbles, autoscroll. | Supports flexible coordination. | Required social infrastructure; production needs delivery/read state, offline sync, encryption policy, abuse tooling. |
| Attachments menu | Chat | Photo and a fixed “Zilker Park Courts” location can be sent as message kinds. | Shares context needed to meet. | Prototype affordance for venue/media; real upload, permission, maps, retention, and moderation are absent. |
| Group chat creation | Chat / Groups | Select two or more active-sport players, name the group, create a conversation, and evaluate all-participant availability. | Reduces multi-person scheduling labor. | Organizer and doubles wedge; current group messages route through one anchor partner and are not a real multi-user transport. |
| Matching-availability strip | Chat / Availability | Automatically displays up to four next shared openings as direct time pills; otherwise prompts adding availability; Calendars opens coordination sheet. | Removes the extra “view availability” step and makes matches immediately actionable. | Central conversion mechanism from conversation to proposal. |
| Calendar ownership legend | Availability | Mint = You/editable, blue = other/saved, split mint-blue = both; participant cards repeat identity and slot count; VoiceOver values name owners. | Resolves ambiguity about whose time is shown. | Trust and accessibility; color remains too dominant and 7–9pt labels are undersized. |
| Shared-time intersection engine | Availability | Intersects the user's future slots with every participant on same calendar day and coarse period, returns earliest matches. | Automates group overlap. | Core proprietary behavioral layer; algorithm is currently exact/coarse and local-only. |
| Availability coordination sheet | Chat / Availability | Shows next shared opening, participant calendars, editable own slots, read-only comparison slots, calendar, and save/schedule actions. Updates availability continuously. | Lets users compare without editing someone else's schedule. | Converts coordination into structured match data; “Schedule shared time” currently immediately confirms the earliest slot rather than sending an approval request. |
| Time proposal sheet | Scheduling | Opens from a shared-time pill, shows date/window, venue field, and agreed/no-wager status, then sends a match proposal. | Converts mutual free window into a specific plan. | Key transaction object; current implementation creates a confirmed face-off immediately despite “proposal” copy. |
| Manual face-off composer | Scheduling | In chat menu: future DatePicker, venue, suggested home court, agreed wager summary, Confirm. | Supports times outside coarse availability. | Important escape hatch; visual design uses native Form and is less consistent than Court Glass components. |
| Profile availability management | Profile / Availability | Shows next saved window and count; full calendar sheet edits and persists only the current user's slots to `UserDefaults`. | Keeps availability reusable and maintainable. | Retention and recommendation input; needs recurrence, expiry reminders, external calendar sync, and server sync. |
| Wager status card | Chat / Wager | Always-visible state: not decided, proposed by me/them, agreed, or no wager; Accept/Decide/Edit action. | Makes social stakes explicit and prevents unilateral assumptions. | Differentiated delight and social commitment; should remain optional, non-cash by default, age-gated, and legally reviewed. |
| Wager agreement sheet | Chat / Wager | Suggestion chips plus custom text; proposal is sent to opponent and only appears in match after acceptance; “play without a wager” supported. | Replaces awkward negotiation with consent states. | Engagement and identity; not a financial wagering product. |
| Face-off status banner | Chat / Match state | Shows scheduled details, report-result action after start time, awaiting opponent confirmation, or disputed result warning. | Keeps match state visible in the conversation. | Increases completion and data integrity. |
| Block control | Safety | Toggles a conversation-level blocked state; composer becomes an unblock bar. | Gives immediate protection from unwanted communication. | Minimum trust feature; production block must apply globally and server-side. |
| Report control | Safety | Shows a local “submitted” alert; no report data is captured or transmitted. | Signals recourse. | **Prototype-only:** shipping a nonfunctional report would be harmful; moderation pipeline is a launch blocker. |
| Live countdown | Live Match | Full black screen counts 3–2–1, honors Reduce Motion, then starts timer. | Creates a clear transition into play and removes app distractions. | Moment of delight and product memorability. |
| Live elapsed timer | Live Match | `TimelineView` displays MM:SS from start. | Tracks match duration without a separate fitness app. | Future performance/venue analytics; currently no pause/resume/background recovery. |
| Multi-game score entry | Live Match | One or more game cards with plus/minus per competitor and running game leader; add another game. | Handles best-of-three and longer sessions. | Produces structured result data; rules do not validate win-by-two, target score, sport format, or doubles. |
| Finish validation | Live Match | Requires every game to be non-tied and total games to have a winner. | Prevents incomplete or tied match submission. | Basic integrity; insufficient sport-rule validation. |
| Winner/result celebration | Live Match | Confetti, winning avatar, game tally, wager, rating before/change/after, and recommendation explanation; loss view is constructive. | Makes outcome emotionally legible. | Reinforces completion loop and rating value. |
| Live-match settlement | Rating / Integrity | `completeLiveMatch` immediately settles Elo and writes history. Separate report flow waits for simulated opponent confirmation. | Gives immediate result feedback. | **Critical inconsistency:** live mode bypasses mutual confirmation and enables unilateral rating manipulation. |
| Result report + Elo preview | Secondary result flow | User chooses winner, sees predicted rating and contextual explanation, then submits; simulated opponent confirms after 1.4s or dispute state is possible. | Makes rating consequence transparent. | Strong trust pattern, but server verification and real opponent action are absent. |
| Rating history and derived stats | Profile / Analytics | Current rating, tier, wins, losses, win rate, rating chart, recent matches, peak/low in legacy Stats. | Shows progress over time. | Retention and premium analytics foundation; current mock history is randomly generated. |
| Profile identity card | Profile | Character editing, name, age, gender, city, enrolled sports. | Gives user control and a stable sports identity. | Trust/identity hub; full editing and privacy controls are incomplete. |
| Sport-specific profile facts | Profile | Partner status, home court, equipment, tournament participation, self-assessment. Current onboarding does not collect most of these; they default until legacy/add-sport flows. | Communicates match logistics and intent. | Improves matching, but current data provenance is inconsistent and some labels can mislead. |
| Add Sport | Profile | Compiled sheet adds a not-yet-enrolled sport with profile questions and rating seed. | Lets the product expand with the user. | Cross-sport retention; must avoid automatically assuming transferable skill. |
| Legacy card-deck Discover | Secondary / legacy | Swipe-style deck, pass/message/like, detail sheet, full filter sheet, reset/caught-up state. Not a primary tab. | Offers focused one-at-a-time evaluation. | Design provenance and possible experiment; currently superseded by shelves/map. |
| Legacy Discover filters | Secondary / legacy | Distance slider, 1–100 range slider, partner status, equipment, tournaments, reset/apply. | Fine-grained candidate control. | Potential Plus feature, but filter abundance can damage liquidity. |
| Legacy Calendar | Secondary / legacy | List of scheduled face-off tickets, empty state, report result path. Not in current tab bar. | Centralizes plans. | Function absorbed by Home and Chat; dedicated tab is unnecessary until schedule volume grows. |
| Legacy Stats screen | Secondary / legacy | Current rating, period picker, chart, summary cards, history rows. Not in current tab bar. | Deep performance review. | Function partly absorbed by Profile; could become a premium drill-down. |
| Next Match widget | Widget | Small/medium dark widget shows opponent, date, venue, sport, rating, and Start Game availability; 15-minute refresh, privacy-sensitive. | Makes next match and court-time entry visible from iOS Home Screen. | High-retention surface; currently hard-coded to Priya/tomorrow/7 AM and not connected to app data or a deep-link intent. |
| Design tokens/components | Design system | Court Glass palette, Avenir Next styles, cards, tags, rating badges, section titles, icon buttons, scale button behavior. | Prevents clashing UI and inconsistent buttons. | Faster product iteration and brand consistency; naming still contains legacy “Sorbet” terms. |
| Sports/mascot assets | Brand | Pickle/shuttle sports objects, Birdie/Pickle mascots, onboarding court/tournament/community illustrations. | Makes onboarding and sport selection more ownable and less generic. | Brand recall, merchandising/content potential; must maintain a single illustration grammar. |
| Editable Paper mockups | Collaboration | Paper contains editable native vector/text mockups for welcome/profile plus an “Accessibility + Scheduling v2” page showing chat, wager, and color-owned calendars. | Enables non-engineer comments and visual iteration. | Reduces design-engineering handoff loss; not automatically bidirectionally synced with SwiftUI. |

---

# SECTION 5: USER JOURNEY ARCHITECTURE & FLOWS

## 1. Core User Flow

### Journey A — First launch to a match-ready profile

1. **Welcome / problem framing:** user sees three editorial stories and taps Next; transition is dissolve, not swipe.
2. **Choose sports:** user selects pickleball, badminton, or both. Continue remains disabled until selection.
3. **Declare play intent:** user chooses just starting, casual/social, or competitive and may add a short note.
4. **Understand system:** app explains discovery, shared-time scheduling, scoring, and the 50 baseline rating.
5. **Save availability:** user selects future dates and Morning/Midday/Evening windows. Current code permits continuing with no slots; production activation should encourage at least three windows without blocking users who are uncertain.
6. **Create identity:** user selects a branded character and enters name/age/gender. The product should explain each field's visibility and matchmaking use.
7. **Complete profile:** app creates a sport profile at rating 50 for each sport, persists availability locally, chooses first sport as active, and enters Home.
8. **First-value requirement:** within the first Home session, the user should see at least five compatible players and ideally a shared-availability signal. If local liquidity is insufficient, show an honest waitlist/invite/session alternative—not fake activity.

### Journey B — Personalized discovery to conversation

1. Home ranks candidates into shelves; user can also switch sports.
2. User taps a player card or map pin.
3. Quick sheet establishes identity hierarchy: character, name + age, location, rating, logistics tags, bio.
4. User chooses **Message** to enter the chat screen or **Challenge** to send structured intent.
5. A new direct conversation is created if needed; current prototype simulates replies, but production waits for real transport and push.

### Journey C — Availability overlap to confirmed match

1. Chat automatically computes the next four shared windows across all participants.
2. If overlap exists, each window appears as a direct pill. If not, Calendars opens comparison.
3. User taps a shared-time pill.
4. Proposal sheet shows the shared period, lets user set venue, and displays only a mutually agreed wager.
5. User sends a match proposal.
6. **Production-correct state:** proposal should be `pending`, notify every participant, and become `confirmed` only after required acceptance. Current code skips pending acceptance and creates confirmed state immediately.
7. Confirmed match appears in chat, Home upcoming matches, notifications/calendar, and widget.

### Journey D — Wager negotiation

1. Challenge is sent without a wager.
2. Inside chat, “Wager not decided” exposes Decide.
3. A user chooses a suggestion or enters custom text and proposes it.
4. Other participant sees the proposal and can accept, counter/edit, or choose no wager.
5. Only the `agreed` value is attached to the face-off; otherwise it becomes “No wager.”
6. Production should restrict cash-like stakes, age-gate where necessary, show community rules, and avoid facilitating settlement.

### Journey E — Court-time scoring to rating update

1. Within one hour before the match, Home/widget exposes Start Game.
2. User enters a full-screen 3–2–1 countdown.
3. Timer begins; avatars and games-won counters establish competitors.
4. User adjusts each game score and adds games as necessary.
5. Finish remains disabled until all games are non-tied and one player wins more games.
6. User submits scores.
7. **Production-correct state:** opponent receives a result confirmation; rating remains provisional/pending until verified. Current live flow settles immediately.
8. Winner receives celebratory animation; both see rating before/change/after and the new recommendation rationale.
9. Result writes match history, rating history, stats, and recommendation features.

### Journey F — Group scheduling

1. From Chat list, user taps create group.
2. Selects at least two active-sport players and optional group name.
3. System creates group chat and intersects the user's calendar with all selected player calendars.
4. Shared-time pills display only windows common to the entire group.
5. One member proposes a slot and venue; every required participant accepts.
6. Confirmed group match reaches Home and each participant's widget/calendar.

## 2. Edge Cases & High-Value Touchpoints

### High-value moments of delight

- First real shared opening appears without negotiation.
- Quick sheet shows a compatible rating and recognizable character rather than anonymous colored shape.
- Time pill turns into a confirmed face-off with a single structured action.
- Start Game activates at the right moment and opens the dramatic countdown.
- Winner animation celebrates; loser copy focuses on recalibration rather than shame.
- Rating change immediately explains why recommendations will shift.
- Widget surfaces next match without opening the app.

### Critical decision gates

- **Sport selection:** multi-select improves lifetime value but splits cold-start supply.
- **Play style versus skill:** wording must prevent “casual” from being read as a low rating.
- **Precise location:** explicit opt-in, coarse display, expiry, and venue-based presence are required.
- **Gender filter:** needs transparent purpose, user control, and anti-harassment safeguards.
- **Wager:** consent and legality gate; avoid cash facilitation.
- **Proposal acceptance:** all required participants must accept before confirmation.
- **Result verification:** no rating mutation before server-side mutual confirmation or trusted organizer import.

### Required edge states

- No compatible players in radius; offer expand radius, next active period, local sessions, or invites.
- Player is compatible but has no availability; allow message/request windows without fabricating overlap.
- One group member has no calendar; identify the missing person without exposing private details.
- Slot expires while proposal is pending; mark expired and recompute.
- Timezone/daylight-saving changes; store instants with timezone and show local conversion.
- User changes sport while viewing a conversation or proposal; pin the object to its original sport.
- Opponent blocks after a proposal; cancel future communication and escalate safety policy.
- Duplicate challenges or matches; deduplicate and warn.
- Venue closes, weather changes, or court is unavailable; provide structured reschedule.
- User starts too early, arrives late, pauses, backgrounds, loses battery, or switches device.
- Score violates rules (e.g., target score/win-by-two) or users played a custom format; let format be explicit.
- Doubles match requires four identities and rating math distinct from singles.
- Opponent rejects/disputes a score; preserve immutable reports, collect evidence, and prevent premature rating updates.
- User never confirms result; expire pending status and exclude from rating until resolution.
- No-show; capture separately from a loss and incorporate into reliability, not skill.
- Minor user or unsafe wager content; apply age and content policy.
- Avatar or name used abusively; report identity content.
- Widget shows private opponent on locked screen; privacy-sensitive behavior exists, but allow user-configurable redaction.
- Offline court; queue score locally, show unsynced state, and reconcile safely.

### Current usability/accessibility risks found in implementation

- Repeated 7–10pt captions are below a comfortable practical minimum even when defined relative to Dynamic Type.
- Availability ownership uses text and accessibility values, but mint/blue and gradient remain visually dominant; add patterns/icons/initials in every state.
- Some bright accent backgrounds use forest text and are likely strong; opacity-based muted text and hairlines require contrast measurement in every state.
- “People also played with,” “Top scorers this week,” and “Active now” overclaim the current data semantics.
- “Send match proposal” currently confirms immediately; state/copy mismatch will damage trust.
- Live scoring and result-report paths use different verification rules.
- Group chat data is represented through an anchor partner, so group delivery and safety behavior are not real.
- The widget looks functional but displays hard-coded data and lacks a targeted deep link.
- The product forces dark mode in primary flows; it needs high-contrast dark QA and either a supported light theme or an explicit brand choice validated with users.
- Reduce Motion support is partial; onboarding and sport-switch animations need consistent handling.
- There is no automated UI, accessibility, rating, scheduling, or state-transition test target.

---

# SECTION 6: IDEATION, AFFINITY MAPPING & PRIORITIZATION

## 1. Feature Affinity Clusters

### Cluster A — Identity, onboarding, and preference graph

Welcome story, sports, play style, baseline rating education, identity details, character avatar, sport-specific profiles, equipment, partner status, home court, availability, sport switcher.

**Shared user intent:** “Understand me enough to make credible introductions without asking for excessive data.”  
**Primary KPI:** onboarding completion and percent reaching a liquidity-qualified Home.  
**Risk:** over-collecting fields before delivering value.

### Cluster B — Local discovery and recommendation engine

Home shelves, Quick Match, player cards, quick sheet, map, pins, radius, recentering, sport/gender/rating filters, active presence, legacy deck/filters.

**Shared user intent:** “Show me the best realistic next opponent.”  
**Primary KPI:** qualified profile-to-chat conversion and candidate coverage.  
**Risk:** fake/low-quality supply, filter-induced sparsity, exposure bias, location privacy.

### Cluster C — Communication and relationship graph

Conversation list, direct chat, group creation, attachments, challenge objects, block/report, repeat opponents.

**Shared user intent:** “Let me safely turn a stranger into a rival, partner, or group.”  
**Primary KPI:** reply rate, meaningful-conversation rate, block/report rate.  
**Risk:** harassment, moderation cost, notification fatigue.

### Cluster D — Availability and scheduling engine

Persistent windows, ownership legend, exact/group intersection, shared-time pills, coordination sheet, proposal sheet, face-off composer, venue, upcoming matches, calendar/widget.

**Shared user intent:** “Find the next time everyone can actually play and make it official.”  
**Primary KPI:** chat-to-confirmed-match conversion and median coordination time.  
**Risk:** stale availability, timezone errors, skipped acceptance, court uncertainty.

### Cluster E — Match transaction and trust

Face-off states, countdown, timer, multi-game scoring, validation, result report, opponent confirmation, disputes, no-show/cancellation (planned), safety.

**Shared user intent:** “Run and verify the real-world event with minimal friction.”  
**Primary KPI:** schedule-to-verified-play conversion and dispute rate.  
**Risk:** manipulation, unsafe meetups, offline failure.

### Cluster F — Rating, analytics, and motivation

Elo, tiers, rating preview, rating delta, rating history, win/loss/win rate, recommendations, top scorer/most played shelves, celebration, streak.

**Shared user intent:** “Help me improve and make every game meaningful.”  
**Primary KPI:** results logged per completed match, 30-day repeat play, rating confidence.  
**Risk:** false precision, discouragement, gaming, unfair doubles math.

### Cluster G — Brand and interaction system

Court Glass tokens, Avenir Next, character art, mascots, sport objects, onboarding illustrations, capsules/cards, dissolves, reduced-motion behavior, editable Paper components.

**Shared user intent:** “Make coordination feel energetic, credible, and recognizable.”  
**Primary KPI:** qualitative brand recall, usability success, accessibility conformance.  
**Risk:** style inconsistency across native Forms/legacy screens and unreadably small ornamental text.

### Cluster H — Platform, monetization, and operations

Backend, auth, geospatial presence, push, calendar sync, app/widget shared data, moderation, payments/booking, organizer tools, analytics, experimentation, customer support.

**Shared business intent:** “Turn a local prototype into a safe, measurable, repeatable marketplace.”  
**Primary KPI:** local liquidity, contribution margin, safety rate, service reliability.  
**Risk:** building visible features before foundational trust and data correctness.

## 2. Impact vs. Effort Prioritization Matrix

Scoring method for sequencing: **Impact** 1–5 estimates effect on verified matches, trust, or retention; **Effort** is rough cross-functional person-weeks; **Confidence** 0.5–1.0 reflects evidence quality. A simple planning index is `(Impact × Confidence) / Effort`. It is directional—not a delivery estimate.

### High Impact / Low Effort — Quick Wins

| Initiative | Impact | Effort | Confidence | Planning index | Why now |
|---|---:|---:|---:|---:|---|
| Correct misleading shelf/presence copy until real data exists | 5 | 1 | 1.0 | 5.00 | Protects trust immediately. |
| Add explicit pending/accepted/declined proposal state in local prototype | 5 | 2 | 0.9 | 2.25 | Aligns scheduling copy and behavior. |
| Require result confirmation before local Elo settlement | 5 | 2 | 0.9 | 2.25 | Closes the largest integrity inconsistency. |
| Increase minimum caption sizes and audit contrast | 4 | 2 | 1.0 | 2.00 | Immediate accessibility/usability gain. |
| Add icon/pattern/initial ownership cues to availability | 4 | 2 | 0.9 | 1.80 | Makes You/Priya distinction robust beyond color. |
| Replace hard-coded widget preview with honest placeholder/empty state | 4 | 1 | 1.0 | 4.00 | Prevents deceptive prototype behavior. |
| Unify manual scheduling/report Forms with Court Glass components | 3 | 2 | 0.8 | 1.20 | Resolves visible design inconsistency. |
| Add empty/stale availability prompts and expiry copy | 4 | 2 | 0.8 | 1.60 | Improves the core scheduling loop. |
| Add analytics event taxonomy to specification | 4 | 1 | 0.9 | 3.60 | Makes future pilots measurable before implementation. |
| Add deterministic mock seeds | 3 | 1 | 1.0 | 3.00 | Stabilizes demos, screenshots, and testing. |

### High Impact / High Effort — Major Strategic Bets

| Initiative | Impact | Effort | Confidence | Planning index | Strategic reason |
|---|---:|---:|---:|---:|---|
| Production backend, auth, sync, and event/state model | 5 | 20–30 | 1.0 | 0.17–0.25 | Prerequisite for a real network. |
| Real-time chat, push, read/delivery state, and deep links | 5 | 12–18 | 1.0 | Required to coordinate asynchronously. |
| Privacy-safe presence and geospatial recommendation service | 5 | 14–22 | 0.8 | Powers the map while managing safety. |
| Availability engine with recurrence, timezone, expiry, and calendar sync | 5 | 12–20 | 0.9 | Core differentiation and repeat-use utility. |
| Match acceptance, cancellation, no-show, dispute, and audit workflow | 5 | 12–18 | 0.9 | Protects trust and reliable ratings. |
| Provisional/doubles-aware rating service with anti-collusion | 5 | 12–20 | 0.8 | Makes the competitive layer credible. |
| Moderation, identity verification, reporting, and support console | 5 | 16–24 | 1.0 | Launch-blocking for stranger meetups. |
| Venue inventory/booking integration | 4 | 16–30 | 0.7 | Converts player demand into transactional value. |
| Hyperlocal launch and ambassador/club seeding playbook | 5 | ongoing | 0.8 | Marketplace liquidity cannot be solved by code alone. |

### Low Impact / Low Effort — Fill-ins / Minor Tweaks

| Initiative | Impact | Effort | Confidence | Recommendation |
|---|---:|---:|---:|---|
| Rename legacy `Sorbet*` component names to Court Glass | 2 | 1 | 1.0 | Do during nearby refactors. |
| Add more wager suggestion copy | 2 | 1 | 0.7 | Only after safety rules and observed demand. |
| Expand avatar selection presentation height | 2 | 1 | 0.9 | Small polish. |
| Add alternate empty-state illustrations | 2 | 1–2 | 0.8 | Useful after truthful state taxonomy exists. |
| Restore deeper Stats drill-down from Profile | 2 | 2–3 | 0.7 | Appropriate once real history exists. |
| Add map clustering visual prototype | 3 | 2–3 | 0.8 | Helpful before real high-density data. |
| Refine celebration copy/particles | 2 | 1–2 | 0.8 | Preserve but do not prioritize above integrity. |

### Low Impact / High Effort — Thankless Tasks / Avoid for now

| Initiative | Impact | Effort | Confidence | Why avoid now |
|---|---:|---:|---:|---|
| Rebuild the legacy swipe deck as a second full discovery paradigm | 2 | 8–12 | 0.8 | Duplicates Home/map and fragments learning. |
| Launch pickleball and badminton nationally at once | 2 | very high | 0.9 | Splits local liquidity across geography and sport. |
| Cash wager settlement/payment | 1 | 20+ | 1.0 | Legal, safety, payments, and brand risk overwhelm value. |
| Spectator live-stream/video analysis in v1 | 2 | 20–30 | 0.7 | Far from core time-to-play problem. |
| Full tournament/bracket suite before consumer liquidity | 2 | 16–24 | 0.8 | Crowded organizer category; delays core proof. |
| Build proprietary maps or court database from scratch | 2 | 20+ | 0.9 | Partner/import first; focus on compatibility and availability. |
| Complex collectible/gamified avatar economy | 2 | 12–20 | 0.6 | Monetization distraction before network trust. |

### Recommended v1 cut line

The launchable v1 is not “everything already visible.” It is: authenticated profile + one launch sport/market + privacy-safe player discovery + real chat + persistent availability + mutually accepted scheduling + notifications + safe live scoring + mutually verified result + credible rating + block/report/moderation + truthful Home/widget. Advanced analytics, multiple sports in every market, venue transactions, leagues, and tournament operations follow proof of local liquidity.

---

# SECTION 7: SCALABILITY & NEAR-FUTURE ROADMAP

## 1. Scope of Scaling

### Architecture scaling

Replace the monolithic local `AppState` with event-backed domain services:

- **Identity/Profile:** account, age eligibility, visibility, avatars, sport enrollment, privacy.
- **Presence/Geo:** explicit availability-to-play session, coarse geohash, expiry, venue association, search radius.
- **Recommendation:** candidate generation, compatibility scoring, exposure/fairness controls, experiment assignment.
- **Conversation:** direct/group channels, membership, message/attachment delivery, block graph, notification preferences.
- **Availability:** recurring rules, exceptions, timezone, calendar imports, intersection queries, freshness.
- **Match:** proposal, acceptance, venue, participant roster, cancellation, no-show, score, verification, dispute.
- **Rating:** immutable result events, versioned algorithm, confidence, recalculation, singles/doubles partitions, anti-abuse.
- **Safety/Moderation:** reports, evidence, risk signals, cases, decisions, appeals, transparency.
- **Analytics:** privacy-conscious event pipeline, funnel metrics, liquidity cohorts, experiment outcomes.
- **Widget/notification projection:** shared app-group cache and deep-link routes derived from server truth.

Use immutable event records for match and rating changes so corrections can be replayed. Every rating output should store algorithm version, inputs, expected score, delta, verification source, and superseding correction. Do not directly mutate a number without an audit event.

### Geographic scaling

Scale city by city, then neighborhood by neighborhood. A market is not “launched” because the app is downloadable. Define operational readiness by compatibility coverage and time-to-match.

Recommended sequence:

1. One dense Austin micro-market, one primary sport, evening/weekend windows.
2. Seed through 3–5 anchor venues or communities and 20–40 organizers/ambassadors.
3. Reach a target of ≥70% compatibility-qualified users with five candidates and two shared windows in seven days.
4. Demonstrate median first confirmed match under seven days and schedule-to-play above 60%.
5. Expand adjacent neighborhoods, then add the second sport only where its independent density passes threshold.

Use invite waitlists and city heatmaps to aggregate demand before activation. Avoid displaying fake pins in low-supply markets.

### User-tier scaling

- **Free player:** core matching, scheduling, chat, safety, basic score/rating.
- **Plus player:** advanced filters, travel mode, deeper stats, recurring availability intelligence, priority alerts—not pay-to-win rating.
- **Organizer:** groups, recurring sessions, waitlists, substitutions, result verification, leaderboards.
- **Venue/club:** inventory, booking, payments, member CRM, utilization, certified ratings, promotional slots.
- **Association/enterprise:** regional administration, compliance, APIs, reporting, sanctioned events.

Core safety, communication, and rating integrity cannot be paywalled.

### Business scaling

Consumer subscription scales with retained player value; organizer SaaS scales with managed participants; venue transactions scale with GMV; partnerships scale through verified demand. The strongest blended model avoids dependence on ads, which would conflict with recommendation trust.

Marketplace math to monitor by micro-market:

`Available compatible pairs = N(N−1)/2 × p_sport × p_geo × p_skill × p_time × p_intent × p_trust`

Even with 1,000 registered users, if weekly active rate is 25%, sport fit .6, geography .5, skill .5, time overlap .25, intent .6, and trust .8, effective compatible pair density is dramatically smaller than registrations imply. This is why availability freshness and compact launches matter more than vanity MAU.

### Enterprise and ecosystem scaling

- Integrate external rating providers rather than demanding immediate replacement.
- Import venue inventory and court availability before building proprietary booking infrastructure.
- Offer club-verified results as a stronger trust class than peer-only results.
- Give organizers APIs/export so PickleMatch does not become another data silo.
- Apply regional privacy, minor-safety, gambling, messaging, and location rules before geographic rollout.
- Localize sports terminology, scoring formats, distance units, week starts, date/time formats, and gender/privacy norms.

## 2. Phase 2 & Phase 3 Roadmap (Near-Future Features)

### Phase 2 — Make the loop real, safe, and repeatable

#### 1. Production identity, trust, and moderation

**Scope:** Apple/email/phone sign-in, age eligibility, account recovery, optional verification, privacy controls, server-side block graph, structured reports, support case console, audit log, appeals, and safety education.

**Why after prototype but before public scale:** the UI proves the intended flow, but stranger meetups cannot launch on simulated local identities and a nonfunctional report button. This is infrastructure, not polish.

#### 2. Real chat, notification, and deep-link infrastructure

**Scope:** direct/group transport, delivery/read state, offline queue, push, notification preferences, challenge/proposal/result actions, universal routes into chat/match/live mode.

**Why Phase 2:** coordination fails without asynchronous reliability; however, it should be built against a finalized match state machine rather than the current simulated model.

#### 3. Availability 2.0 and external calendar integration

**Scope:** weekly recurring rules, date exceptions, “available now,” freshness/expiry, timezone support, travel, iOS/Google/Outlook free-busy import with privacy-preserving granularity, group intersection, and suggestions ranked by acceptance probability.

**Why Phase 2:** it is the clearest differentiation, but calendar permissions and recurrence semantics require trust, backend identity, and privacy design first.

#### 4. Match contract and verified-result engine

**Scope:** pending/accepted/declined/expired proposals, all-participant confirmation, reschedule/cancel/no-show, score formats, offline recovery, opponent verification, dispute evidence, immutable rating events, provisional ratings, singles/doubles models, anti-collusion.

**Why Phase 2:** the prototype demonstrates the desired UX but contains integrity contradictions. This is the core transaction and must be correct before rating has reputational value.

#### 5. Privacy-safe live presence and production recommendation

**Scope:** expiring opt-in presence, coarse venue/neighborhood location, clustering, server geospatial search, compatibility ranking, exposure controls, hide/block effects, explanation labels, and honest low-liquidity states.

**Why Phase 2:** map delight depends on real supply, but precise-presence risk and cold-start quality make it inappropriate as a simple database migration.

#### 6. App/widget shared data and match-day reliability

**Scope:** App Group projection, next-match timeline, targeted Start Game deep link/App Intent, lock-screen privacy controls, notifications, Live Activity, pause/background/recovery, and offline score sync.

**Why Phase 2:** the widget already proves demand, but hard-coded content is not a feature. It becomes valuable only when backed by confirmed server state.

### Phase 3 — Monetize and deepen the network

#### 7. Venue booking, payments, and fill-the-court marketplace

**Scope:** court search/availability, reservation referral or native booking, split court cost, cancellation policy, open spot filling, venue verification, off-peak offers. Exclude cash wager settlement.

**Why Phase 3:** high revenue potential and stronger transaction completion, but requires supply partnerships, payments compliance, refunds, and enough consumer demand to interest venues.

#### 8. Organizer/club operating system

**Scope:** recurring sessions, rosters, waitlists, substitutions, attendance, round robins, team balancing, organizer-confirmed results, ladders, facility dashboards, APIs, and external rating export.

**Why Phase 3:** provides B2B revenue and distribution, but building it before the consumer completion loop is proven would place PickleMatch directly into a mature scheduling/tournament category without a wedge.

### Roadmap success gates

- **End of prototype validation:** ≥80% task success in moderated tests for find player → message → identify shared time → propose match → start/score game; zero critical accessibility blockers.
- **End of Phase 2 pilot:** median first confirmed match <7 days; proposal acceptance ≥50%; schedule-to-play ≥60%; result verification ≥85%; dispute <5%; D30 retention materially higher for users completing a first match than those who do not.
- **Before Phase 3:** at least one micro-market meets local liquidity target for eight consecutive weeks; organizer cohorts demonstrate lower coordination time; verified matches grow without rising safety incidents per 1,000 matches.
- **Monetization gate:** test willingness to pay only after retained value is demonstrated. Subscription conversion should not be optimized at the expense of match completion or fair exposure.

### Final investor assessment

PickleMatch has progressed beyond a superficial UI concept into a coherent, buildable product thesis with a distinctive end-to-end loop. The most investable insight is the persistent availability and commitment graph embedded in local player discovery—not the existence of ratings, maps, chat, or scoring individually. The current design work is unusually complete for a prototype and makes the transaction legible from onboarding through result celebration.

The opportunity is credible but not yet defensible. Adjacent competitors already own major pieces of the stack and several increasingly claim all-in-one positioning. The venture case depends on proving three things quickly in one dense market: (1) availability-aware recommendations materially reduce time-to-match, (2) verified completed matches cause retention, and (3) the safety/trust system supports stranger coordination without unacceptable incident or moderation cost. If those are proven, the product can expand from a consumer coordination wedge into a local sports network, organizer platform, and venue demand marketplace. If they are not, additional features will not compensate for insufficient liquidity.

