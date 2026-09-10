# Match Point backend

This directory is the source of truth for the Supabase database. Never make a
production-only schema change in the dashboard: add a migration here first.

## Project setup

1. Create `matchpoint-dev` at <https://database.new>.
2. Install the Supabase CLI (`brew install supabase/tap/supabase`).
3. Authenticate with `supabase login`.
4. Link this repository with `supabase link --project-ref YOUR_PROJECT_REF`.
5. Review the migration, then apply it with `supabase db push`.

For the hosted beta project in this repository, the project reference is
`cdipgccbwwaojqkubbuj`. Link it from your own authenticated terminal session;
do not share the database password or an access token in chat:

```sh
supabase login
supabase link --project-ref cdipgccbwwaojqkubbuj
supabase db push
```

The initial migration creates identity, sports, availability, social graph,
chat, challenges, matches, immutable rating events, moderation, notification,
and account-deletion tables. Every client-facing table has Row Level Security.

The first external beta enables Pickleball and Badminton only. Later sport
profiles remain decodable but inactive. Courts discovered through Apple Maps
are cached in `courts`; users can create a club at a court, join its membership
roster, and create or join groups inside that club.

## Closed-beta verification

`tests/closed_beta_integrity.sql` exercises the highest-risk multi-account
flows in one rolled-back transaction: accepting a chat request, enforcing a
shared active sport and accepted connection for challenges, uploading a match,
agreeing on its result from two accounts, and settling exactly one immutable
rating event per participant.

Run the complete migration chain against a disposable local database before
every hosted push. After pushing, repeat the core flows with at least two real
test accounts because local SQL tests do not exercise email delivery, deep
links, device permissions, or network failures.

## Authentication redirects

In **Authentication → URL Configuration**, set both the Site URL and an exact
allowed Redirect URL to:

```text
com.picklematch.app://auth-callback
```

The iOS target registers that URL scheme and passes the callback to Supabase
Auth. Keep the dashboard value and `BackendConfiguration.authCallbackURL` in
sync. Use a verified universal link instead before adding a web authentication
surface.

## Security rules

- Only the project URL and publishable key belong in the iOS app.
- Never place a `service_role` or secret key in Xcode, Git, CI logs, or chat.
- Rating settlement, moderation actions, notification delivery, and final
  account deletion must run in trusted server/Edge Function code.
- Test all RLS policies with two or more separate test accounts before release.

## Environments

Use separate Supabase projects for development and production. A staging project
is recommended before the external TestFlight beta. Apply identical migrations
to every environment rather than cloning dashboard state manually.
