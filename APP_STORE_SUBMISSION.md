# Match Point App Store submission pack

This document is the working source for the first external TestFlight beta and
eventual App Store submission. Fields marked **OWNER INPUT** cannot be completed
from the codebase.

## App identity

- App Store listing name: **Match Point: Play Nearby**
- Installed display name: **Match Point**
- App Store Connect Apple ID: **6810871341**
- Platform: **iOS**
- Primary language: **English (U.S.)**
- Version: **1.0**
- Build: **1** (increment for every uploaded archive)
- Bundle ID: **`com.sashanksanjana.matchpoint`** — confirmed for the beta
- SKU: **`matchpoint-ios-2026`**
- Primary category: **Sports**
- Secondary category: **Social Networking**
- Price: **Free** for the beta
- Copyright: **2026 Sanjana Venkat**

## Localized product-page copy

### Subtitle

Play nearby. Compete. Connect.

### Promotional text

Find nearby pickleball and badminton players, plan matches, verify results, and
build your local sports community.

### Description

Match Point helps pickleball and badminton players turn “we should play” into a
real match.

Discover players near you or explore another area on the map. Compare
sport-specific ratings, connect with people you want to play, and keep every
conversation in one unified inbox.

When you are ready to play, send a challenge with up to three possible times.
After the match, record each game and ask the other player to verify the result.
Verified results update each player’s rating and make future matches easier to
balance.

With Match Point you can:

• Discover pickleball and badminton players
• Explore privacy-conscious approximate player locations
• Connect and chat with other players
• Propose match times and coordinate a venue
• Record singles and doubles results
• Verify or dispute submitted scores
• Track a separate rating and history for each sport
• Find nearby courts, clubs, and community groups
• Block or report another player when needed

Pickleball and badminton are available during this beta. Additional sports are
shown as coming soon.

Location access is optional. Exact device location is used to calculate nearby
results but is not displayed to other players; map pins use an approximate
neighborhood location.

### Keywords

pickleball,badminton,sports,matchmaking,players,courts,matches,rating,clubs,local

### What’s New

Welcome to the first Match Point beta: discover players, connect and chat,
schedule matches, verify scores, and build separate pickleball and badminton
ratings.

## URLs

- Privacy policy URL: **https://website-mu-ivory-jxjijloosj.vercel.app/privacy/**
- Support URL: **https://website-mu-ivory-jxjijloosj.vercel.app/support/**
- Marketing URL: **https://website-mu-ivory-jxjijloosj.vercel.app/**
- User privacy choices URL: optional; recommended to link directly to account
  deletion and privacy instructions

Draft page content is available in `legal/PRIVACY_POLICY_DRAFT.md` and
`legal/SUPPORT_PAGE_DRAFT.md`. These documents must be reviewed, completed, and
published at public HTTPS URLs before submission.

## App icon and screenshots

- The supplied Match Point artwork is installed as the 1024 × 1024 app icon.
- Do not pre-round the icon or add transparent corners.
- Capture final screenshots from the production-signed UI after the icon,
  display name, and production backend are confirmed.
- Recommended first screenshot story:
  1. Find nearby players
  2. Compare verified sport ratings
  3. Send a challenge with several times
  4. Chat and coordinate
  5. Verify a result
  6. Track rating progress

## App Privacy working answers

Choose **Yes, we collect data from this app**. The following is a conservative
draft based on the current code and Supabase schema; re-audit it immediately
before submission if analytics, crash reporting, photo uploads, payments, ads,
or additional SDKs are added.

All listed data is used for **App Functionality**, is **linked to the user**, and
is **not used for tracking** unless noted otherwise.

| App Store data type | Why it is collected |
| --- | --- |
| Email Address | Account creation, confirmation, recovery, and support |
| Name | Player profile and social features |
| User ID | Authentication, ownership, security, and account relationships |
| Precise Location | Nearby discovery and court search; stored privately |
| Contacts | Match Point friendship and connection graph; not the device address book |
| Other User Content | Profile biography, username, availability, challenges, scores, reviews, reports, clubs, and groups |
| Emails or Text Messages | Direct-message content sent inside Match Point |
| Device ID | APNs device token used to route push notifications |
| Other Data | Age, gender, and other player-profile fields |

Do **not** declare advertising, cross-app tracking, contacts/address-book access,
health data, payment information, or diagnostics unless those capabilities are
added. Revisit **Photos or Videos** before submission if user photo or chat image
uploads become functional; bundled avatar selection alone is not a user photo
upload.

## Age rating working position

- The app is not in the Kids category.
- Onboarding currently enforces a minimum age of 13.
- Answer the questionnaire truthfully for unrestricted web/social communication,
  user-generated content, location sharing, and moderation controls.
- Match Point includes direct messages, profiles, block, and report controls.
- The app does not implement real-money wagering or gambling. Any social wager
  language must remain non-cash and optional for this beta.
- Use Apple’s calculated rating unless legal review or the final Terms require a
  higher minimum.

## App Review notes

Match Point is a sports matchmaking app for pickleball and badminton. Reviewers
can create an account with email/password, but a pre-confirmed review account is
recommended so they can reach populated production flows without waiting for an
email.

Review account — **OWNER INPUT BEFORE SUBMISSION**

- Email:
- Password:

Suggested review path:

1. Sign in with the supplied review account.
2. Allow location while using the app, or continue without it.
3. Use Home to view challenges and recommendations.
4. Open the map to view neighborhood-level sample/discovery pins.
5. Open Chats from the paper-airplane button.
6. Open Matches to view pending and completed results.
7. Open Profile to review sport ratings, privacy settings, block/report access,
   and account deletion.

The app requires network access to its Supabase backend. Location is optional;
denying it leaves profiles, chat, challenges, matches, and settings usable.

## Export compliance working position

The app uses standard operating-system and HTTPS/TLS encryption through Apple
platform APIs and Supabase dependencies. It does not intentionally implement a
proprietary cryptographic algorithm. Confirm the export-compliance answers in
App Store Connect against the final dependency list; do not make a permanent
declaration from this draft alone.

## Information still needed from the owner

1. Final app icon verification in a signed archive (artwork supplied September
   10, 2026).
2. App Review contact phone number.
3. A dedicated pre-confirmed App Review account and password.
4. Owner confirmation of the App Privacy publishing attestation in App Store
   Connect. The answers are complete but intentionally not published by an
   automated agent.
5. Owner completion of the age-rating and content-rights declarations.
6. Final App Store screenshots.
7. Two physical iPhones and two separate test accounts for the first end-to-end
   production APNs and multiplayer smoke test.

## Push notification production configuration

- App ID: **`com.sashanksanjana.matchpoint`** with Push Notifications enabled
- Apple Team ID: **`5GV64S6S7C`**
- Active APNs Key ID: **`WNVU9X6P88`** (team-scoped, sandbox and production)
- Supabase Edge Function: **`send-push`**
- Database webhook: **`dispatch_notification_push`** on
  `public.notifications` inserts
- APNs credentials and the webhook secret are stored as Supabase secrets and
  are not committed to Git.
- The authenticated webhook health check returns HTTP 200. Final delivery still
  requires a production-signed build on a physical iPhone so APNs can issue and
  register a real device token.

Support email: **matchpoint.app.support@gmail.com**
