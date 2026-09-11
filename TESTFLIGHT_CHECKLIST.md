# Match Point external beta checklist

The codebase and Supabase project are ready for a small Pickleball/Badminton
beta. Uploading to TestFlight still requires the account-owned Apple steps
below.

## Required from the app owner

- Apple Developer Program membership is active.
- The App Store Connect app exists as **Match Point: Play Nearby** (Apple ID
  `6810871341`) with bundle identifier `com.sashanksanjana.matchpoint`.
- The app and widget targets use Apple team `5GV64S6S7C`; Xcode still needs the
  account owner to sign in locally so automatic signing can create/download the
  distribution profiles.
- Public privacy, support, and marketing URLs are live on Vercel.
- App Store metadata, categories, TestFlight description, and App Privacy
  answers are filled in. The owner must publish the privacy answers because the
  final action includes a legal accuracy attestation.
- Add final App Store screenshots, complete age rating and content rights, and
  add the App Review phone number and review-account credentials.

The drafted listing copy, privacy answers, review notes, and exact remaining
owner inputs are in [`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md).

## Supabase beta checks

- In Authentication → URL Configuration, allow
  `com.picklematch.app://auth-callback` as a redirect URL.
- Keep email confirmation enabled for external testers.
- Create at least two real tester accounts and verify connection request, chat,
  challenge, score agreement, Elo update, block, and account deletion across
  separate devices/accounts.
- The current live project contained one auth user at the final backend audit;
  multi-account behavior therefore still needs real-user acceptance testing.
- Apply every migration in `supabase/migrations` to any separate staging or
  production Supabase project before pointing a build at it.

## Upload steps

1. In Xcode, update the version/build number and select **Any iOS Device**.
2. Choose **Product → Archive**.
3. In Organizer, run **Validate App**, resolve signing/privacy warnings, then
   choose **Distribute App → App Store Connect → Upload**.
4. In App Store Connect → TestFlight, answer export-compliance questions, add
   internal testers first, then submit the build for external beta review.

## Intentional beta limitations

- Pickleball and Badminton are live. Ping Pong, Volleyball, Cricket, and Soccer
  remain visible only as “Coming soon.”
- Nearby courts use Apple Maps search and are cached in Supabase. Search results
  depend on Apple Maps coverage and location permission.
- Notifications are visible and persisted in-app. Remote APNs infrastructure is
  configured: the app registers device tokens, Supabase stores them, a database
  webhook invokes `send-push`, and the Edge Function is configured with the
  active APNs key. Real delivery must still be smoke-tested using a signed build
  on physical iPhones.
- The player map can request up to a 3,000-mile result set and displays only
  neighborhood-rounded coordinates. Home recommendations remain local.
- Android is out of scope for this TestFlight beta.

Use [`BETA_TEST_PLAN.md`](BETA_TEST_PLAN.md) for the tester allocation,
end-to-end acceptance runs, and proposed notification copy.
