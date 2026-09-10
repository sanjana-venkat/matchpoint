# Match Point 20-person beta plan

## Current testable scope

- Email sign-up, confirmation callback, sign-in, sign-out, and account deletion
- Profile and avatar editing
- Pickleball and Badminton profiles; other sports remain marked Coming soon
- Foreground location permission and local home recommendations
- Country-scale player map (up to 3,000 miles) using neighborhood-rounded pins
- Connection requests, acceptance, deletion, blocking, and reporting
- Unified conversations and unread state
- Singles and doubles challenges with one to three proposed times
- Uploaded scores, two-party verification/dispute, and immutable per-sport Elo
- Nearby courts, clubs, memberships, and community groups
- Persistent in-app notifications and read state

## Not complete until Apple credentials are available

- APNs push entitlement and physical-device token registration
- Supabase Edge Function/provider connection to APNs
- Production push credentials and delivery testing
- App Store signing, archive validation, TestFlight upload, and external beta review
- Final app icon, screenshots, privacy policy URL, support URL, and privacy answers

## Proposed push notification copy

| Event | Title | Body |
| --- | --- | --- |
| Connection request | New connection request | `{name} wants to connect.` |
| Connection accepted | You’re connected | `{name} accepted your request. Say hello.` |
| New message | `{name}` | `{message preview}` |
| Challenge received | New {sport} challenge | `{name} offered some times. Choose what works.` |
| Challenge accepted | Match confirmed | `{name} accepted {date and time}.` |
| Challenge reminder | Match coming up | `Your match with {name} starts {relative time}.` |
| Score verification | Verify the result | `{name} submitted a score from your match.` |
| Result verified | Rating updated | `Your {sport} rating is now {rating} ({change}).` |
| Incomplete profile | Finish setting up | `Add your sports and location to find players near you.` |
| Inactive user | Ready for a game? | `See who is available near you this week.` |

Inactivity notifications should be opt-in, limited to one per week, suppressed
after any meaningful activity, and never include another user’s precise location.

## Tester allocation

- 10 Pickleball-first testers
- 6 Badminton-first testers
- 4 testers active in both sports
- At least 4 doubles groups
- At least 4 testers outside the primary city to validate wide-map discovery
- At least 2 testers who deny location and later enable it in Settings

## Required acceptance runs

1. Two new accounts confirm email and finish onboarding on separate devices.
2. Both allow location; each sees the other at an approximate, not exact, pin.
3. One sends a connection request; the other accepts; both can chat.
4. Run Pickleball singles and Badminton singles through challenge, acceptance,
   score submission, verification, and Elo change.
5. Run doubles with a partner and two opponents; verify all participant choices.
6. Submit conflicting results and confirm the match is disputed without an Elo change.
7. Join a club, create/join a group, and confirm membership on another account.
8. Block one account and confirm discovery, challenges, and messages are unavailable.
9. Deny location and confirm the app remains usable without map discovery.
10. Delete a disposable account and confirm its private data is no longer accessible.

Record device model, iOS version, account email, action, expected result, actual
result, screenshot, and timestamp for every failure.
