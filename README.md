# Matchpoint — SwiftUI iOS App

For the complete behavior-preservation inventory used for redesign work, see [`SASHANK_FUNCTIONALITY_SPEC.md`](SASHANK_FUNCTIONALITY_SPEC.md).

A SwiftUI sports matchmaking app with onboarding, player discovery, chats, challenges, score verification, per-sport Elo ratings, nearby courts and clubs, and a Supabase backend. The current beta focuses on **Pickleball** and **Badminton**; the remaining sports are visible as coming soon.

Public pages: [Matchpoint](https://website-mu-ivory-jxjijloosj.vercel.app/), [Privacy](https://website-mu-ivory-jxjijloosj.vercel.app/privacy/), and [Support](https://website-mu-ivory-jxjijloosj.vercel.app/support/).

## Fastest way to preview it (no account or API keys)

1. Install **Xcode 16 or newer** on a Mac.
2. Clone this branch and open `PickleMatch.xcodeproj`.
3. In Xcode's scheme menu, select **PickleMatch Fake Data**.
4. Pick an iPhone simulator and press **⌘R**.

The fake-data scheme needs no Supabase account. It includes populated profiles, chats, notifications, challenges, verifications, matches, ratings, courts, and clubs so the complete interface can be reviewed immediately.

```bash
git clone --branch codex/fake-data-preview --single-branch https://github.com/sanjana-venkat/matchpoint.git
cd matchpoint
open PickleMatch.xcodeproj
```

## Run against Supabase

1. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig`.
2. Add the project's Supabase URL and **publishable** key. Never add a service-role key.
3. Select the **PickleMatch** scheme and press **⌘R**.
4. Apply the versioned database migrations by following [`supabase/README.md`](supabase/README.md).

`Config/Secrets.xcconfig` is intentionally ignored by Git, so each developer keeps local credentials outside the repository.

The project uses an Xcode "synchronized" file group, so every `.swift` file in the `PickleMatch/` folder is compiled automatically — no manual target membership needed. Minimum deployment target is **iOS 17**.

## What's implemented

**Onboarding (first launch)**
- Basic details: name, gender, age, and avatar picker (12 illustrated avatars)
- Sport selection: pickleball, badminton, or both, with future sports marked coming soon
- Rating intro: explains the 1–100 scale, assigns everyone a starting **50**, shows how points are won/lost
- Sport questions: doubles-partner status, home court, equipment, tournament history, self-assessment

**Discover (the main screen)**
- Tinder-style swipe deck of illustrated player summary cards (rating, tier, distance, partner status, tags)
- Swipe right / ♥ to start a conversation, left / ✕ to pass, tap for a full profile
- Filters: distance, skill-rating range (two-thumb slider), partner status, has-equipment, tournaments-only

**Messaging**
- Conversation inbox + 1:1 chat
- Unified, sport-neutral chats with sport-aware challenges. The composer offers only Pickleball and/or Badminton when both people play them.
- Challenges support a **free-form wager** with suggestion hints (a beer, a meal, cash, a pickleball…)
- Attach a photo or location; **block** and **report** from the chat menu

**Face-off & rating**
- Schedule a face-off (date, time, venue, wager) to "make it official" → lands on the Calendar
- After a match, **report who won**; the opponent must **confirm** before anything changes
- Ratings only settle on agreement; the swing follows Elo — big win vs. a stronger player = more points, beating a much weaker player = very little (see `EloRating.swift`)

**Calendar** — upcoming scheduled matches grouped by day, with opponent, venue, and wager.

**Stats** — current rating, W/L, win %, an interactive rating chart with **1W / 1M / 1Y / 2Y** ranges (Swift Charts), peak & lowest rating, and the full match log with per-match rating deltas.

**Profile** — your identity, per-sport rating & answers, a **sport mode switcher** (when you have both), and **add another sport** (re-runs the rating intro + questions).

## Project layout

```
PickleMatch/
├─ PickleMatchApp.swift        App entry + root router
├─ Models/                     Data models + Elo rating engine
├─ State/                      AppState (single source of truth) + MockData
├─ Onboarding/                 Welcome → basics → sports → rating → questions
├─ Main/                       Tab bar + sport-mode toggle
├─ Discover/                   Swipe deck, cards, profile detail, filters
├─ Messages/                   Inbox, chat, challenge & face-off composers, result reporting
├─ Calendar/                   Scheduled matches
├─ Stats/                      Analytics + rating chart
├─ Profile/                    Your profile + add-sport flow
└─ Support/                    Theme, reusable components
```

## How the rating math works

On a 1–100 scale (`EloRating.swift`), expected score is the standard Elo logistic curve with a divisor tuned for the compressed range, and the new rating is `R + K·(actual − expected)`. Because `expected` is high when you're favored, beating a much stronger opponent produces a large gain and beating a much weaker one produces almost nothing — mirroring chess.com. Values are clamped to 1–100.

## Backend status

The production scheme includes Supabase authentication and repositories for profiles, sport profiles, availability, social connections, chat, challenges, matches, rating events, notifications, moderation, courts, clubs, and groups. Location permission and nearby-player syncing are wired into the authenticated app flow. Before public release, use the [`TESTFLIGHT_CHECKLIST.md`](TESTFLIGHT_CHECKLIST.md), configure production secrets, apply every migration, and test Row Level Security with multiple accounts.

Native APNs registration and server delivery are included. The account owner
must complete the one-time Apple key and Supabase webhook steps in
[`PUSH_NOTIFICATIONS_SETUP.md`](PUSH_NOTIFICATIONS_SETUP.md).
