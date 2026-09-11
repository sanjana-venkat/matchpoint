# Matchpoint push-notification setup

The iOS client, device-token RPC, delivery audit table, and `send-push` Edge
Function are implemented. Apple credentials and one database webhook remain
account-owner setup because the APNs private key is downloadable only once.

## 1. Enable the App ID

In Apple Developer → Certificates, Identifiers & Profiles → Identifiers, create
or open the explicit App ID `com.sashanksanjana.matchpoint` and enable **Push
Notifications**. Keep Xcode automatic signing enabled and select the active team
for the PickleMatch target.

## 2. Create the APNs key

In Apple Developer → Keys, create a key named `Matchpoint Push`, enable Apple
Push Notifications service, and download the `.p8` file. Record the Key ID and
Team ID. The file is downloadable only once.

Never commit the `.p8` file, paste it into chat, or place it inside the Xcode
project. Keep it in a private local folder until it has been uploaded directly
to Supabase secrets.

## 3. Configure Supabase secrets

Set these Edge Function secrets:

- `APNS_PRIVATE_KEY`: complete contents of the downloaded `.p8`
- `APNS_KEY_ID`: Apple key identifier
- `APNS_TEAM_ID`: Apple developer team identifier
- `APNS_TOPIC`: `com.sashanksanjana.matchpoint`
- `PUSH_WEBHOOK_SECRET`: a random 32-byte secret

## 4. Connect notification inserts to APNs

Create a Supabase Database Webhook named `send-push` for the `public.notifications`
table and the `INSERT` event. Point it to:

`https://cdipgccbwwaojqkubbuj.supabase.co/functions/v1/send-push`

Add the header `x-matchpoint-webhook-secret` with the same value as
`PUSH_WEBHOOK_SECRET`.

## 5. Physical-device smoke test

Use two real iPhones and two accounts. Accept notifications on both. Send a
connection request and message from one account, then verify that the other
device receives the alert while the app is backgrounded. Test both a Debug
build (APNs sandbox) and TestFlight build (APNs production).
