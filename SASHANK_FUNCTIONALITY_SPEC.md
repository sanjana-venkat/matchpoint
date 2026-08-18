# Match Point — Functional Inventory for the Next Redesign

**Purpose:** Preserve the complete product behavior while replacing the current visual style.

**Audited implementation:** `feature/swiftui-web-port` at commit `df90c63`, August 17, 2026.

**Primary routed experience:** `SashankMainView.swift`, supported by the shared onboarding, models, state engine, chat, availability, challenge, scoring, profile, and statistics modules.

This document is the behavioral source of truth for the redesign. Layout, color, typography, illustration style, card shape, animation treatment, and navigation presentation may change. The user capabilities, data relationships, state transitions, safeguards, and empty/populated states described here must remain available.

## 1. Implementation-status legend

Every feature is assigned one of these statuses:

- **Routed and interactive:** Reachable in the current Sashank-based app and performs an observable interaction.
- **Implemented in the shared product engine:** Working SwiftUI or state logic exists elsewhere in the project and must be carried into the redesigned routed experience.
- **Prototype presentation only:** The current interface demonstrates the intended control or content, but its final action is not yet connected to state.
- **Production dependency:** Requires a backend, device service, moderation service, or other real infrastructure that the local prototype does not provide.

The redesign must not silently remove an implemented capability simply because its current Sashank screen exposes only a lighter-weight version of it.

## 2. Product foundation

Match Point is a multi-sport social network for finding nearby players, coordinating availability, creating challenges, recording scores, verifying results, and building a sport-specific performance history.

The core loop is:

1. Create one social identity.
2. Select up to four sports.
3. Configure rating participation or peer-rated skills per sport.
4. Save recurring or date-specific availability.
5. Discover nearby players and communities.
6. Connect and converse.
7. Find a shared play window.
8. Create and confirm a challenge or fixture.
9. Play and record one or more game scores.
10. Have the opponent verify the result.
11. Update match history, statistics, and—when eligible—the numerical rating.
12. Use the improved history and network to arrange the next game.

### 2.1 Supported sports

The data model supports ten sports:

- Individual or dual: Pickleball, Badminton, Tennis, Ping Pong, Squash.
- Group: Volleyball, Cricket, Soccer, Baseball, Football.

Sport selection is limited to four sports per user. One sport is always the active app mode after onboarding.

### 2.2 Sport-specific behavior

Individual sports use the Match Point numerical rating unless the user opts out. Group sports do not use a public numerical player rating; they use verified peer skill evaluations.

Peer skill categories are sport-specific:

| Sport | Categories |
|---|---|
| Volleyball | Serving, Setting, Defense |
| Cricket | Batting, Bowling, Fielding |
| Soccer | Passing, Finishing, Defense |
| Baseball | Hitting, Fielding, Throwing |
| Football | Offense, Defense, Game IQ |

### 2.3 One identity, separate sport contexts

The following are shared across sports:

- Name, username, age, gender, avatar, biography, city, and social graph.
- General saved availability.
- Access to chats and profile identity.

The following are sport-specific:

- Active home experience and recommendations.
- Numerical rating or peer-skill ratings.
- Play-style answers and home court.
- Match history and statistics.
- Challenges, fixtures, conversations, map results, and communities.

Switching sports must refresh the displayed content without creating a second user identity.

## 3. Prototype states

The first screen lets a reviewer choose one of two complete demo states.

### 3.1 New user

**Routed and interactive.**

The new-user state begins onboarding with:

- An initialized but incomplete profile.
- No selected sports.
- Zero friends and friend requests.
- Zero conversations and message requests.
- Zero challenges or fixtures.
- Zero match records.
- Zero rating history and performance statistics.

Completing onboarding creates the user's selected sport profiles, seeds an initial rating-history point only for rated individual sports, persists availability, selects the first sport as active, and opens the main application.

### 3.2 Established player

**Routed and interactive.**

The populated account is Alex Morgan, username `alexplaysall`, age 32, non-binary, with 42 displayed friends and saved recurring availability.

Alex has three sport profiles:

- Pickleball: MP Rating 125, established rating history, partnered, tournament experience, Zilker Courts home court.
- Badminton: MP Rating 121, established rating history, seeking a partner, tournament experience, Austin Recreation Center home court.
- Cricket: no numerical rating; peer scores for Batting 4.7 from 28 ratings, Bowling 4.4 from 24 ratings, and Fielding 4.8 from 31 ratings.

The established state contains populated conversations across sports, active challenges and fixtures, scheduled and manually uploaded match records, rating trends, recommendations, connection content, notifications, and nearby communities.

## 4. Onboarding

### 4.1 Welcome story

**Routed and interactive.**

Three introductory pages explain:

- Finding people nearby to play with.
- Comparing schedules and making a plan.
- Playing, tracking results, and choosing whether a match affects rating.

Each page has illustration content, progress, a back action after the first page, and a consistent bottom call to action.

### 4.2 Sport selection

**Routed and interactive.**

- Displays individual/dual and group sports as separate categories.
- Allows one to four selections.
- Shows the current selection count.
- Prevents a fifth selection.
- Allows selected sports to be removed before continuing.
- Disables continuation until at least one sport is selected.

### 4.3 Consolidated sport setup

**Routed and interactive.**

All selected sports appear on one scrollable page as separate cards.

For each individual sport:

- Display the starting MP Rating of 80.
- Provide exactly one rating opt-out toggle.
- Explain that only verified rated matches change the rating.
- Explain that games involving an unrated opponent stay unrated for everyone.

For each group sport:

- Explain that the sport has no numerical player rating.
- Explain that verified peers can evaluate sport-specific skills after play.
- Provide a “Read more” action.
- Open a sport-specific explanation showing all peer-skill categories, the one-to-five scale, averages, and reviewer counts.

### 4.4 Availability setup

**Routed and interactive.**

- Uses a visual day-and-time schedule editor rather than free-form text.
- Supports recurring weekly availability and one-off dates.
- Supports six named time windows: Early morning (6–8 AM), Morning (9–11 AM), Midday (11 AM–2 PM), Afternoon (3–5 PM), Evening (6–8 PM), and Night (8–10 PM).
- Allows multiple windows on the same day.
- Requires at least one window in the currently selected schedule mode before continuing.
- Uses larger, readable, left-aligned availability labels.
- Saves the schedule to the user's shared profile and local persistence.

### 4.5 Identity setup

**Routed and interactive, with device-service caveats.**

- Photo-library entry point.
- Camera entry point; the simulator currently shows a camera-prototype explanation.
- Avatar library containing 20 supplied watercolor people plus 44 symbol/cartoon/animal/abstract alternatives.
- Required full name.
- Required unique username with a minimum of three characters in the prototype.
- Required age from 13 through 99.
- Gender choices: Male, Female, and Non-binary. There is no “Prefer not to say” choice.
- A consistent final “Create profile” action that remains disabled until required fields are valid.

Actual photo ingestion, camera capture, username uniqueness validation, and remote profile persistence are production dependencies.

### 4.6 Welcome transition

**Routed and interactive.**

After profile creation, a short loading animation displays “Welcome to Match Point, [First Name]!” and prepares the home experience before onboarding completes.

## 5. Global application shell

### 5.1 Active-sport switcher

**Routed and interactive.**

- Always communicates the current sport.
- Shows only sports belonging to the current user.
- Changes the content context for every primary destination.
- Shows the numerical rating for individual sports and a peer-rated indicator for group sports.
- Provides sport-specific iconography.

The current Sashank shell presents a top-left menu. A compact tap-to-cycle version also exists in the project. The redesign may choose either interaction pattern, but sport switching must remain immediate, obvious, and accessible.

**Implemented in the shared product engine:** If a challenge, score upload, or other form has unsaved changes, attempting to switch sports can trigger an exit warning and require the user to keep editing or discard changes.

### 5.2 Primary navigation

The five destinations are:

- Home.
- Map.
- Matches for individual sports, or Calendar for group sports.
- Chats.
- Profile.

The current Sashank shell visually orders them Map, Matches/Calendar, Home, Chats, Profile. Navigation order and styling may change in the redesign, but all five destinations must remain one-tap reachable.

### 5.3 Persistent quick action

**Routed and interactive at presentation level.**

The persistent floating action control expands and collapses secondary actions.

For individual sports:

- Add a challenge.
- Upload scores.

For group sports:

- Submit a review.
- Add to calendar.

The control must not obscure primary navigation or essential content. Its expanded state must close when a primary destination is selected.

### 5.4 Notifications

**Routed and interactive at presentation level.**

- Notification bell with unread count.
- Sheet with connection-request, score-verification, challenge-time, and rating-change notifications.
- Compact custom close action.

Notification read state, deep links, and push delivery are production dependencies.

## 6. Home

### 6.1 Personalized sport hero

**Routed and interactive.**

- Greets the user by first name.
- Displays the active sport.
- For individual sports, shows the current MP Rating.
- For group sports, communicates peer-rated status.
- Shows a sport-specific hero illustration.
- Badminton can select a male, female, or neutral illustration based on the profile's gender.

### 6.2 Verifications

**Routed presentation.**

- Horizontal player/result cards.
- Distinguishes singles and doubles examples.
- Shows match date and a verification-needed badge.
- Selecting a player opens that player's profile.

The shared engine contains the real incoming-result verification and dispute logic described in Section 13.

### 6.3 Connection requests

**Routed presentation with implemented shared state actions.**

- Displays requesters, distance, and recent activity.
- Opens the full player profile.
- Shared logic supports send, accept, and decline friend requests.
- Accepting a request also promotes the related message request into the main inbox.

### 6.4 Challenges or fixtures

**Routed presentation.**

- Individual sports show challenges.
- Group sports show upcoming fixtures.
- Cards show opponent, date and time, venue, and status such as “Needs a reply” or “Confirmed.”
- Data is filtered to the active sport.

### 6.5 Recommended players

**Routed and interactive.**

- Individual sports show recommended opponents.
- Group sports show players in the area.
- Cards include player identity, distance, and rating or peer-rated status.
- Selecting a card opens the player profile.
- A section-level map entry point is represented.

### 6.6 Clubs, leagues, facilities, and community recommendations

**Routed presentation.**

Sport-specific nearby recommendations include:

- Clubs.
- Leagues.
- Facilities or courts.
- Ladders or cups where relevant.
- Member or court count.
- Distance.
- Contextual action: Join community, Join league, or View facility.

These recommendations are currently mock data. Membership, booking, and venue-detail flows are production dependencies.

## 7. Map and nearby discovery

### 7.1 Map content

**Routed and interactive.**

- Light-mode map.
- Current-user location marker.
- Nearby player markers generated around Austin in the prototype.
- Each player marker uses an avatar and active-sport rating.
- Selecting a marker opens a player profile sheet.
- Results change with the active sport.

Real location authorization, accurate distance calculation, privacy-safe location precision, and live presence are production dependencies.

### 7.2 Filters

**Routed and interactive.**

Only these map filters are presented:

- Gender: Any, Male, Female, or Non-binary.
- Rating: Any, Under 80, 80–110, or Above 110.

“Clear filters” remains visible. It is disabled when no filters are applied and resets both filters when active. There is no “Active” filter.

### 7.3 Player profile from map

**Routed and interactive.**

Selecting a marker opens the shared player-profile surface. Earlier product intent also specifies an on-map quick-information popover with name, availability, rating, distance, sports, Add as friend, and Create a challenge. The current Sashank route uses a sheet instead. Preserve the underlying information and actions; the redesign may decide whether the first layer is a popover, sheet, or progressive combination.

### 7.4 Alternative card discovery

**Implemented in the shared product UI but not a primary Sashank destination.**

The project also contains a swipeable player-discovery deck:

- Shows up to three candidate cards as a stack.
- Swipe right or use the positive action to create/open a conversation.
- Swipe left or use the pass action to remove the candidate for the current session.
- Tap the card or message action to inspect the full profile.
- Shows temporary feedback after a positive action.
- Filters candidates by active sport, maximum distance, numerical rating range, partner status, equipment ownership, and tournament experience.
- Applies or resets filters and resets the deck.
- Provides caught-up, no-results, and clear-filter states.

This discovery mode is optional in the next information architecture because Sashank's Home shelves and Map currently serve discovery. If it is omitted visually, its filtering and pass/connect capabilities should still be considered when designing a complete discovery experience.

## 8. Player profile

**Routed and interactive.**

The redesigned shared profile must include, without duplication:

- Avatar.
- Full name and age.
- Distance and city.
- Active-sport rating, tier, and partner status.
- Biography.
- Home court when available.
- Playing style/self-assessment.
- What the player is seeking.
- Message action.
- Create challenge action.
- Compact custom close action when presented modally.

The same profile surface is reachable from Home, Map, Discover, and avatar taps in Chats. The redesign must not return to the previous card-inside-a-card sheet or repeat the same biography and location in multiple sections.

## 9. Matches and calendar

### 9.1 Individual-sport Matches destination

**Routed and interactive.**

Contains two segments:

- Past.
- Upcoming.

Past match behavior:

- Combines scheduled Match Point matches with manually uploaded scores.
- Filters records to the active sport.
- Shows win/loss, opponent, score summary, rating change, date, venue, and record source.
- Distinguishes “Uploaded score” from “Scheduled match.”
- Selecting a record opens a quick-detail sheet.

Upcoming behavior:

- Shows a week calendar.
- Shows confirmed and tentative events.
- Shows a legend for the active sport, awaiting-reply state, and another user sport.
- Presents an Add a Challenge action.

The shared `MatchesView` also implements detailed per-game scores and a shortcut to the full statistics breakdown. Those behaviors must be retained in the redesign even if the current Sashank quick-detail sheet is simpler.

### 9.2 Group-sport Calendar destination

**Routed and interactive at presentation level.**

Contains:

- Week segment.
- Past matches segment.
- Hourly week grid from 7 AM to 10 PM.
- Date row, current-day state, confirmed fixtures, and tentative fixtures.
- Multi-sport legend.
- Add to calendar action.

Group sports do not use challenge-style rating changes or Elo score uploads. They use fixtures, calendar coordination, verified peer reviews, and past match records.

### 9.3 Calendar navigation status

**Prototype presentation only in the Sashank shell.**

Previous month/week, Today, next month/week, Add a Challenge, and Add to Calendar are visually represented but some callbacks are currently no-ops. The redesign should connect them to actual date navigation and creation flows rather than remove them.

## 10. Chats and social graph

### 10.1 Inbox

**Routed and interactive.**

- Separate Chats and Requests segments.
- Filters conversations to the active sport.
- Search by name or username.
- Each row shows avatar, name, and the latest-message preview.
- Empty conversations show a blank preview rather than city or distance.
- Preview copy adapts to text, challenge, scheduled match, photo, location, and system events.
- Selecting a row opens the conversation full-screen.
- Selecting the avatar opens the full player profile.

### 10.2 Message requests

**Implemented in the shared product engine.**

- Non-friends enter the Requests inbox.
- A request can be accepted before normal friend conversation behavior.
- Acceptance moves the thread into Chats and establishes friendship.
- A request-state notice can explain that the user should converse before challenging.

### 10.3 Conversation

**Routed and interactive at presentation level, with a richer shared implementation available.**

- Back navigation.
- Partner avatar, name, and username.
- Incoming and outgoing message alignment.
- Message types: text, photo placeholder, location, challenge, face-off, and system event.
- Text composer and send action.
- Individual-sport challenge shortcut.

The Sashank composer currently clears its draft without appending the message. The shared `ChatView` and `AppState.send` path do append messages and simulate a reply; that working behavior must be used in the redesign.

### 10.4 Group chat

**Implemented in the shared product engine.**

- Create a group with at least two other participants.
- Optional group name, defaulting to “Court crew.”
- Store all participant identifiers.
- Compare availability across every participant.
- Schedule a multi-player face-off from a shared opening.

### 10.5 Attachments and conversation tools

**Implemented in the shared product UI.**

- Send photo placeholder.
- Send location.
- Create challenge.
- View full profile.
- View head-to-head match history across shared sports.
- Report a conversation.
- Block and unblock a player.

Reporting and blocking are local prototype behavior; real moderation, evidence retention, escalation, and enforcement are production dependencies.

## 11. Availability matching and scheduling

**Implemented in the shared product engine and UI.**

- Users own and edit their recurring and one-off play windows.
- Availability persists locally between app sessions.
- The app expands recurring windows across a future horizon.
- One-to-one chats can compare both players' calendars.
- Group chats can calculate the intersection across all members.
- The app can surface the next shared opening or up to four aligned openings.
- Calendar comparison distinguishes “You,” the other player, and overlapping windows using labels as well as color.
- A shared opening can be selected, paired with a venue, and sent as a match proposal.
- Confirmed proposals become face-offs and appear in scheduling surfaces.

The redesign must preserve ownership labels and non-color state cues for accessibility.

## 12. Challenges, fixtures, and wagers

### 12.1 Challenge creation

**Routed at presentation level; full creation logic is implemented in shared modules.**

- Select an opponent who plays the active sport.
- Select or propose date and time.
- Enter or select a venue.
- Include a note.
- Send the challenge into the opponent conversation.
- Create a proposed face-off record.
- Disable submission until required selections are present.

The current Sashank challenge sheet offers example day/time chips and closes after submission, but does not mutate state. The redesign must connect it to `createChallenge` or the richer challenge composer.

### 12.2 Challenge lifecycle

**Implemented in the shared product engine.**

States:

- Proposed.
- Confirmed.
- Awaiting result.
- Result disputed.
- Completed.
- Cancelled.

Actions:

- Accept an incoming challenge.
- Decline an incoming challenge.
- Cancel an existing challenge.
- Edit date or venue.
- Increment a revision number after edits.
- Return the edited challenge to proposed state for reconfirmation.
- Add accepted challenges to both schedules.
- Show active challenges within the related conversation.

### 12.3 Rating-exempt safeguard

**Implemented in the shared product engine and UI.**

If either participant in an individual-sport match has opted out of rating, the match is rating-exempt. Before sending or logging it, the interface can warn that the game will not affect Elo or rated statistics.

### 12.4 Wagers

**Implemented in the shared product engine and UI.**

- Wagers are optional and free-form.
- Suggested social wagers include a drink, meal, coffee, court time, equipment, cash example, or bragging rights.
- A wager is proposed in chat after a challenge rather than forced into the first challenge form.
- The other player can accept it.
- Either side can choose no wager.
- States are proposed by me, proposed by them, agreed, or no wager.
- Only an agreed wager is carried into the match.

Any real-money or regulated wagering would require separate legal, safety, age, geographic, and payment review and is not production functionality.

## 13. Score recording, live match, and verification

### 13.1 Manual score upload

**Routed at presentation level; full recording is implemented in shared modules.**

- Supports matches played inside or outside Match Point.
- Supports Singles and Doubles.
- Doubles includes partner selection and two-opponent selection.
- Supports one through five matches/games in one session.
- Records a winner or numerical score for every game.
- Supports deuce-style scores and prevents tied final game scores.
- Supports adding and removing games.
- Creates an unscheduled face-off when necessary.
- Identifies “Your team” and “Opponents” for multi-player formats.

The current Sashank upload sheet demonstrates format, count, and per-game winner selection but only dismisses on save. The redesign must use `LogGameSheet`, `createUnscheduledMatch`, and score submission so saved data appears in history.

### 13.2 Live match mode

**Implemented in the shared product UI.**

- Match-ready countdown.
- Live-match state.
- Per-game score controls.
- Add another game.
- Display current game totals for both sides.
- Show the agreed wager.
- Mark rating-exempt games as unrated.
- Produce a result summary with winner, games won, opponent, wager, rating before, predicted rating after, and delta.
- Honor Reduce Motion for celebratory effects.

### 13.3 Opponent verification

**Implemented in the shared product engine and UI.**

- Submitting scores does not immediately change ratings or statistics.
- The match moves to Awaiting result.
- The opponent receives a verification request.
- Matching reports settle the match.
- Disagreement moves the match to Result disputed.
- A disputed result can be reviewed and re-reported.
- Only settled results create completed match records and rating changes.

### 13.4 Rating settlement

**Implemented in the shared product engine.**

- Numerical rating starts at 80.
- There is no upper ceiling; the minimum is zero.
- Rating changes are deliberately small, generally one to five points.
- Upset wins gain more; expected wins gain less.
- Unexpected losses lose more; expected losses lose less.
- Both rated players' histories update after verification.
- Rating-exempt matches do not change either rating.

Rating tiers currently map to:

| Rating | Tier |
|---|---|
| Below 60 | Developing |
| 60–79 | Club |
| 80–99 | Competitive |
| 100–119 | Advanced |
| 120+ | Elite |

## 14. Profile and statistics

### 14.1 Own profile

**Routed and interactive at presentation level.**

- Avatar, name, username, age, gender, and friend count.
- Active-sport selector.
- Sport-specific rating or peer-rating card.
- Match/fixture count, wins, and win rate.
- Account-configuration section.

### 14.2 Individual-sport profile

- MP Rating or “Unrated.”
- Explanation that the initial rating is 80 and moves gradually.
- Match count, wins, losses, and win rate.
- Rating trend chart.
- Recent matches.
- Sport-specific profile answers.
- Clear indication when the rating system was opted out.

### 14.3 Group-sport profile

- Peer-skill category averages.
- One-to-five star representation.
- Reviewer count for every category.
- Peer testimonials.
- No public numerical player rating.

### 14.4 Statistics details

**Implemented in the shared product UI.**

- Current rating.
- Wins, losses, and win percentage.
- Rating over time.
- Time ranges: one week, one month, one year, and two years.
- Peak and lowest rating points.
- Complete sport-specific match history.
- Opponent rating at match time.
- Per-match rating delta.
- Empty state before any matches are recorded.
- Shortcut from match detail to the full statistics breakdown.

### 14.5 Profile configuration

The current Sashank profile presents entries for:

- Edit profile details.
- Manage sports.
- Privacy and visibility.
- Notification preferences.
- Reset account.

These rows are prototype presentation only in the Sashank route. Shared code supports changing the avatar, editing availability, switching sport mode, and adding another sport up to the four-sport limit. The redesign should expose working destinations or clearly mark unavailable production settings.

### 14.6 Next-match home-screen widget

**Compiled extension with mock data; production synchronization is not implemented.**

- Supports small and medium widget families.
- Shows the next opponent, sport, date/time, venue, and rating.
- Changes to a “Start game” state from one hour before the match until six hours after its scheduled start.
- Refreshes its timeline every 15 minutes.
- Marks its content privacy-sensitive.
- Provides one combined VoiceOver summary.

The widget currently uses hard-coded sample data and an older visual treatment. The redesign may restyle it completely, but a production version should derive its next confirmed match and rating from shared app data and deep-link into match detail or live scoring.

## 15. Empty, loading, error, and edge states

The redesign must preserve distinct experiences for:

- Brand-new account with no sports configured.
- No friends or incoming requests.
- No chats.
- Message request with no prior messages.
- No challenges or upcoming fixtures.
- No past matches.
- No rating history.
- Individual sport with rating opt-out.
- Group sport with no peer reviews yet.
- No map results after filters.
- No shared availability.
- Rating-exempt opponent.
- Awaiting opponent verification.
- Disputed result.
- Blocked conversation.
- Unsaved form while switching sports.
- Loading/welcome transition after onboarding.

Empty states should explain the next useful action rather than only state that data is absent.

## 16. Accessibility and interaction requirements

These requirements are behavioral and must survive the style redesign:

- Light mode is the current required color scheme.
- Minimum interactive target is approximately 44 by 44 points.
- Text must remain readable with Dynamic Type and avoid clipping at accessibility sizes.
- Every control needs an accessible name and, where useful, a hint or selected trait.
- Avatar-only actions require explicit labels.
- Selected sport, navigation tab, filters, calendar ownership, tentative status, win/loss, and rating eligibility cannot rely on color alone.
- Calendar times and availability copy must remain large enough and left aligned where scanning benefits.
- Reduce Motion must be honored for repeated, spring, countdown, and celebration animation.
- Sheets use an obvious custom close icon rather than an oversized native text button.
- UI sentences begin with an uppercase letter and use consistent grammar.
- Scrollable horizontal content must not hide the only route to a critical action.
- Persistent navigation and the floating action control must not overlap each other or obscure content.

## 17. Current prototype-only wiring gaps

These are known gaps, not features to delete:

| Surface | Current Sashank behavior | Required redesign behavior |
|---|---|---|
| Chat send | Clears draft | Append message and show it in the thread |
| Chat challenge icon | No-op | Open challenge flow |
| Challenge submit | Dismisses sheet | Create proposed face-off and conversation events |
| Score upload save | Dismisses sheet | Create/update match, save games, request verification |
| Doubles participant row | Informational | Select partner and two opponents |
| Upcoming “Add a Challenge” | No-op | Open challenge creation |
| Group “Add to calendar” | No-op | Create/edit a fixture |
| Group “Submit a review” | Closes menu | Open verified peer-rating form |
| Calendar previous/Today/next | No-op | Navigate calendar dates and restore current period |
| Community actions | Presentation only | Open facility/community/league detail or join flow |
| Profile settings | Presentation only | Route to working settings |
| Notifications | Static list | Read state and deep links |

The shared project already contains working implementations for many challenge, score, chat, availability, peer-rating, and statistics operations. Reuse those data paths rather than duplicating new local state inside redesigned screens.

## 18. Production dependencies and non-functional limitations

The current prototype uses in-memory mock data. Only current-user availability persists locally. Before production, the app needs:

- Authentication and account recovery.
- Backend persistence and cross-device synchronization.
- Server-authoritative friendships, chats, challenges, fixtures, results, and ratings.
- Real-time messaging and presence.
- Push notifications and deep links.
- Media upload, storage, and moderation.
- Camera capture and permissions.
- Real geolocation, distance, privacy zones, and location permissions.
- Unique username validation.
- Result-verification delivery, dispute operations, and abuse prevention.
- Block/report enforcement and moderation tooling.
- Club, league, facility, membership, and booking data.
- Rating integrity protection and anti-collusion controls.
- Analytics, observability, privacy controls, data export, and account deletion.

## 19. Redesign acceptance checklist

A redesign is functionally complete only when all of the following pass:

- [ ] Both New user and Established player states remain selectable.
- [ ] New-user onboarding can be completed end to end.
- [ ] One to four sports can be selected and configured together.
- [ ] Individual rating opt-out uses exactly one control per sport.
- [ ] Group sports show peer-rating education and categories.
- [ ] Weekly/date-specific availability can be saved.
- [ ] Profile identity validation remains intact.
- [ ] Welcome transition populates the user's name.
- [ ] All five primary destinations are reachable.
- [ ] Active-sport switching updates every destination.
- [ ] Unsaved work is protected before switching sports.
- [ ] Established Home retains verifications, requests, challenges/fixtures, player recommendations, and community recommendations.
- [ ] Map retains player markers, Gender, Rating, and visible Clear filters.
- [ ] Player profiles expose message and challenge actions without duplicated content.
- [ ] Matches contains Past and Upcoming; group sports receive Calendar behavior.
- [ ] Scheduled and manually uploaded records both appear in history.
- [ ] Match detail includes per-game results and statistics navigation.
- [ ] Chats and Requests remain separate and searchable.
- [ ] Inbox rows show latest-message previews.
- [ ] Avatar taps open the full profile.
- [ ] Text messages actually send.
- [ ] One-to-one and group shared availability can be calculated.
- [ ] Challenges can be created, accepted, edited, declined, and cancelled.
- [ ] Wagers require explicit agreement or no-wager selection.
- [ ] Singles and doubles scores can be logged across multiple games.
- [ ] Results require opponent verification before statistics or rating changes.
- [ ] Disputes do not update ratings.
- [ ] Rating-exempt matches remain unrated.
- [ ] Individual statistics and group peer ratings remain separate.
- [ ] Notifications, profile settings, safety actions, and empty states remain represented.
- [ ] All major controls meet accessibility and light-mode requirements.

## 20. Code ownership map

Use these files when rebuilding behavior behind a new style:

| Concern | Primary source |
|---|---|
| Root routing and prototype-state chooser | `PickleMatch/PickleMatchApp.swift` |
| Current Sashank shell and primary screens | `PickleMatch/Sashank/SashankMainView.swift` |
| Global state and behavior | `PickleMatch/State/AppState.swift` |
| Demo content | `PickleMatch/State/MockData.swift` |
| Domain models | `PickleMatch/Models/Models.swift` |
| Rating rules | `PickleMatch/Models/EloRating.swift` |
| Onboarding | `PickleMatch/Onboarding/OnboardingFlowView.swift` |
| Availability editor and overlap flow | `PickleMatch/Support/AvailabilityViews.swift` |
| Full chat behavior | `PickleMatch/Messages/ChatView.swift` |
| Inbox, requests, and group composer | `PickleMatch/Messages/ConversationsView.swift` |
| Challenges, wagers, result verification, and manual logging | `PickleMatch/Messages/ChallengeAndFaceOff.swift` |
| Full match history and detail | `PickleMatch/Main/MatchesView.swift` |
| Live scoring | `PickleMatch/Main/LiveMatchView.swift` |
| Full statistics | `PickleMatch/Stats/StatsView.swift` |
| Own profile and sport management | `PickleMatch/Profile/ProfileView.swift` |
| Player profile | `PickleMatch/Discover/ProfileDetailView.swift` |
| Legacy map/discovery logic and richer filters | `PickleMatch/Main/PlayersMapView.swift`, `PickleMatch/Discover/DiscoverView.swift` |

## 21. Redesign boundary

The next design may change:

- Visual identity and illustration direction.
- Colors, typography, spacing, radii, shadows, and materials.
- Card composition and content density.
- Navigation order and visual treatment.
- Sheet versus popover versus full-screen presentation.
- Animation style.
- The exact visual representation of sport switching, calendars, charts, and filters.

The next design must not change without an explicit product decision:

- The two prototype states.
- Multi-sport identity and sport-specific data separation.
- Rating opt-out and rating-exempt behavior.
- Group-sport peer ratings.
- Availability ownership and overlap calculation.
- Friend/request/chat relationships.
- Challenge and result-verification state machines.
- Scheduled versus unscheduled match provenance.
- Singles, doubles, and multi-game score support.
- Opponent confirmation before rating/statistics changes.
- The five core destinations.
- Safety, accessibility, and unsaved-work safeguards.

This boundary lets the product adopt a completely different style without losing the working system underneath it.
