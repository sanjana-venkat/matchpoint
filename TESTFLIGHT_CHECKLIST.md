# Match Point external beta checklist

The codebase and Supabase project are ready for a small Pickleball/Badminton
beta. Uploading to TestFlight still requires the account-owned Apple steps
below.

## Required from the app owner

- Enroll in the Apple Developer Program and accept active agreements.
- Create an App Store Connect app with the final bundle identifier. The current
  development identifier is `com.picklematch.PickleMatch`.
- Select the Apple development team in both the Match Point app and widget
  targets, then enable automatic signing.
- Supply a public privacy-policy URL and support URL.
- Finish App Store privacy answers. The app stores account/profile data,
  precise location for nearby discovery, messages, connections, memberships,
  challenges, scores, and rating history. It does not use this data for tracking.
- Add final App Store screenshots, description, age rating, category, and app
  review contact details.

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
- Notifications are visible and persisted in-app. Remote APNs push delivery is
  not enabled until the Apple Developer team, push entitlement, and APNs key are
  available.
- Android is out of scope for this TestFlight beta.
