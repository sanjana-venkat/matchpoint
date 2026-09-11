# Matchpoint — Sashank 8/17 Functional Parity Audit

## Authoritative baseline

- GitHub commit: `96bfaa6300799a0aa41b0c44344b87ee9fefab89`
- Commit date: August 17, 2026
- Commit author: Sashank Mullapudi
- Source artifact: `Matchpoint 8:17.zip`
- Git artifact SHA-256: `b4b3cd20698d29077673d0482eb80d633c8f50b4834505f16e0ff766c16328b9`
- Local audit artifact SHA-256: `b4b3cd20698d29077673d0482eb80d633c8f50b4834505f16e0ff766c16328b9`

The archived React prototype in this exact commit is the behavior and information-architecture baseline. The SwiftUI application keeps the Rally visual language while preserving those flows.

## Screen and workflow parity

| Sashank 8/17 area | SwiftUI implementation | Status |
| --- | --- | --- |
| New and established demo states | `AppState.loadNewUserPrototype` and `loadEstablishedPrototype` | Implemented |
| Three editorial introduction screens | `OnboardingFlowView` | Implemented |
| Identity setup | Photo/camera, name, username, age, and gender | Implemented |
| Four-sport selection | Individual/group sections and four-sport limit | Implemented |
| Consolidated sport setup | Starting rating, opt-out, group peer-rating explanation, and read-more content | Implemented |
| Welcome transition | Personalized welcome animation before Home | Implemented |
| Sport switching | Branded switcher, sport state, and unsaved-change warning | Implemented |
| Home verifications | State-backed cards, score detail, rating projection, confirm, and dispute | Implemented |
| Home connection requests | State-backed cards, detail, accept, and delete | Implemented |
| Home challenges | Incoming/outgoing/confirmed states, multiple proposed times, accept, decline, and withdraw | Implemented |
| Recommended players | Sport-filtered player rail and full player drawer | Implemented |
| Nearby communities | Sport-specific clubs, leagues, facilities, imagery, and calls to action | Implemented |
| Map | Pan, pinch zoom, sport-filtered markers, rating/gender filters, and player drawer | Implemented |
| Individual matches | Past/upcoming tabs, weekly calendar, score-source labels, match detail, and statistics shortcut | Implemented |
| Score upload | Singles/doubles, partner/opponent selection, multiple games, and verification lifecycle | Implemented |
| Group calendar | Saved fixtures, week/past views, fixture detail, add/remove, result entry, and peer review | Implemented |
| Chats | Search, previews, requests, accept/delete, full conversation, and player drawer | Implemented |
| Challenge in chat | Conversation gate, one-to-three proposed times, venue, response states, and calendar sync | Implemented |
| Group chat | Group naming, multi-player selection, and shared-availability conversation | Implemented |
| Player profile drawer | About, age, gender, sport ratings, other sports, media, mutual connections, connect/chat, and block | Implemented |
| Notifications | Live request/verification/challenge items, actions, player drawer, and mark-all-read | Implemented |
| Own profile | Sport-specific rating/peer skills, statistics, trends, results, and settings | Implemented |
| Profile settings | Edit details, manage sports, privacy, notifications, and reset account | Implemented |
| Global action button | Branded expanding action control for challenge/fixture and score/review | Implemented |
| Empty states | Zero messages, friends, challenges, match history, and statistics for a new user | Implemented |

## Intentional product-owner overrides

These differences are deliberate instructions received after the 8/17 build and must not be “corrected” back to the source:

- Rally light visual language replaces Sashank's earlier styling.
- Native Apple menus, pickers, toggles, and selector sheets are replaced by branded controls.
- Onboarding uses uploaded/camera photos only; the avatar library is removed.
- The separate onboarding “When can you play?” page is removed.
- The map adds an Everyone/Friends filter and a gold ring around friends.
- The calendar legend is status-only: filled means confirmed and outlined means awaiting reply.
- Challenge creation is available through the persistent action button and chat composer instead of an extra calendar button.
- Chat challenge entry is a plus button beside the message field.

## State integrity checks

- Accepting a connection request removes it from Requests and moves its conversation to Chats.
- Deleting a request removes both the request and its pending conversation.
- Confirming or disputing a verification updates the underlying `FaceOff` used across Home, Chats, Matches, and Profile statistics.
- Accepting a challenge changes it from tentative to confirmed in the shared calendar.
- Withdrawing or declining a challenge removes it from active surfaces.
- Adding, removing, or completing a group fixture updates Home and Calendar from one shared record.
- Blocking a player works even when no prior conversation exists.
- Switching sports filters every surface and warns before abandoning an unsaved draft.

