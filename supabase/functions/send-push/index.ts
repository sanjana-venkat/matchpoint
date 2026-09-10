import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@6";

type NotificationRow = {
  id: string;
  user_id: string;
  kind: string;
  payload: Record<string, unknown>;
};

type WebhookPayload = {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: NotificationRow | null;
};

const required = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
};

const copyFor = (notification: NotificationRow, actor: string) => {
  switch (notification.kind) {
    case "connection_request": return { title: "New connection request", body: `${actor} wants to connect.` };
    case "connection_accepted": return { title: "Connection accepted", body: `${actor} accepted your connection request.` };
    case "message": return { title: actor, body: "Sent you a new message." };
    case "challenge": return { title: "New challenge", body: `${actor} challenged you to a match.` };
    case "challenge_accepted": return { title: "Challenge accepted", body: `${actor} accepted your challenge.` };
    case "verification": return { title: "Verify a result", body: `${actor} submitted a match result for you to review.` };
    case "rating_update":
    case "rating_updated": return { title: "Rating updated", body: "Your verified match changed your MP rating." };
    case "peer_review_received": return { title: "New peer review", body: "A player reviewed your recent match." };
    default: return { title: "Match Point", body: "You have new activity." };
  }
};

const makeProviderToken = async () => {
  const privateKey = required("APNS_PRIVATE_KEY").replace(/\\n/g, "\n");
  const key = await importPKCS8(privateKey, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: required("APNS_KEY_ID") })
    .setIssuer(required("APNS_TEAM_ID"))
    .setIssuedAt()
    .sign(key);
};

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
    if (request.headers.get("x-matchpoint-webhook-secret") !== required("PUSH_WEBHOOK_SECRET")) {
      return new Response("Unauthorized", { status: 401 });
    }

    const webhook = await request.json() as WebhookPayload;
    if (webhook.type !== "INSERT" || webhook.table !== "notifications" || !webhook.record) {
      return Response.json({ skipped: true });
    }

    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? required("SUPABASE_SECRET_KEY");
    const admin = createClient(required("SUPABASE_URL"), serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const notification = webhook.record;
    const { data: tokens, error } = await admin
      .from("device_tokens")
      .select("id,token,environment")
      .eq("user_id", notification.user_id)
      .eq("platform", "ios");
    if (error) throw error;
    if (!tokens?.length) return Response.json({ sent: 0 });

    const payload = notification.payload ?? {};
    const actorID = [payload.from_user_id, payload.user_id].find((value) => typeof value === "string") as string | undefined;
    let actor = "Someone";
    if (actorID) {
      const { data: profile } = await admin.from("profiles").select("display_name").eq("id", actorID).maybeSingle();
      if (profile?.display_name) actor = profile.display_name;
    }

    const jwt = await makeProviderToken();
    const topic = Deno.env.get("APNS_TOPIC") ?? "com.picklematch.PickleMatch";
    const copy = copyFor(notification, actor);
    let sent = 0;

    for (const token of tokens) {
      const host = token.environment === "development"
        ? "https://api.sandbox.push.apple.com"
        : "https://api.push.apple.com";
      const response = await fetch(`${host}/3/device/${token.token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          aps: { alert: copy, sound: "default", "thread-id": notification.kind },
          notification_id: notification.id,
          kind: notification.kind,
        }),
      });
      const responseBody = await response.text();
      const invalid = response.status === 410 || responseBody.includes("BadDeviceToken") || responseBody.includes("Unregistered");
      await admin.from("push_deliveries").upsert({
        notification_id: notification.id,
        device_token_id: token.id,
        status: response.ok ? "sent" : invalid ? "invalid_token" : "failed",
        apns_status: response.status,
        error: response.ok ? null : responseBody.slice(0, 500),
        attempted_at: new Date().toISOString(),
      }, { onConflict: "notification_id,device_token_id" });
      if (invalid) await admin.from("device_tokens").delete().eq("id", token.id);
      if (response.ok) sent += 1;
    }

    return Response.json({ sent, attempted: tokens.length });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : "Unknown error" }, { status: 500 });
  }
});
