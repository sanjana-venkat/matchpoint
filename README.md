# Match Point — Dual-State iOS Prototype

For the complete behavior-preservation inventory used for redesign work, see [`SASHANK_FUNCTIONALITY_SPEC.md`](SASHANK_FUNCTIONALITY_SPEC.md).

A production-grade SwiftUI prototype for sports matchmaking and social play. Choose the **New user** state to complete onboarding with an empty account, or the **Established player** state to explore a populated three-sport account with ratings, peer-reviewed cricket skills, friends, chats, challenges, matches, and statistics.

Everything runs on in-memory mock data — no backend, no accounts, no network.

## Run it

1. You need a Mac with **Xcode 16 or newer**.
2. Open `PickleMatch.xcodeproj`.
3. Pick an iPhone simulator (e.g. iPhone 15) and press **⌘R**.

The project uses an Xcode "synchronized" file group, so every `.swift` file in the `PickleMatch/` folder is compiled automatically — no manual target membership needed. Minimum deployment target is **iOS 17**.

## What's implemented

**Onboarding (first launch)**
- Basic details: name, gender, age, and avatar picker (12 illustrated avatars)
- Sport selection: pickleball, badminton, or both (both unlocks an in-app mode toggle)
- Rating intro: explains the 1–100 scale, assigns everyone a starting **50**, shows how points are won/lost
- Sport questions: doubles-partner status, home court, equipment, tournament history, self-assessment

**Discover (the main screen)**
- Tinder-style swipe deck of illustrated player summary cards (rating, tier, distance, partner status, tags)
- Swipe right / ♥ to start a conversation, left / ✕ to pass, tap for a full profile
- Filters: distance, skill-rating range (two-thumb slider), partner status, has-equipment, tournaments-only

**Messaging**
- Conversation inbox + 1:1 chat
- Two message types: **start a conversation** or **send a challenge**
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

## Notes & next steps

This is a front-end prototype. To make it real you'd add: a backend + auth, real geolocation/distance, push notifications for challenges and result confirmations, photo uploads, and persistence (the models already conform to `Codable`). Badminton is wired as a full second "mode" but shares pickleball's UI; sport-specific tuning can come later.
