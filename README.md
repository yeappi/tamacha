# tamacha (こちゃ) — online MVP

Live app: https://tamacha.vercel.app

## Two experiences
- `/` — Online MVP connected to Supabase (real accounts / shared content / real-time conversations).
- `/demo.html` — The original fully local prototype with scripted conversations and simulated lock/key purchases.

## Online MVP functionality
- Email/password sign-up and sign-in; Supabase email verification may be enabled.
- Shared mood balls (1–5 characters) and post balls with the original falling-ball canvas UI.
- Free daily ball budgets: 100pt for mood balls, 100pt for post balls (Tokyo time, resets at 04:00). Enforcement is in PostgreSQL RPC, not browser state.
- Public posts and likes, user profiles and follows.
- Up to 15 ball-originated conversations per day per account (server-enforced).
- Only two room participants can send; all signed-in users can read conversations (public-by-design).
- Reusing a room for the same pair, with new ball sections. 3-day pause enforced by the server.
- Realtime change subscriptions plus a periodic refresh fallback.

## Latest online features
- Public browsing without an account: guests can view balls, posts, and unlocked/public portions of conversations.
- Registration is requested only when the visitor tries to post, throw a ball, start a chat, like, follow, or purchase.
- Supabase email registration uses `emailRedirectTo: https://tamacha.vercel.app/`; the Supabase Auth URL Configuration must permit this URL, otherwise confirmations can still redirect incorrectly.
- 04:00 JST morning ball, once per signed-in user per day.
- Server-side test item purchases for points/locks/keys (no actual payments).
- Live lock/key mechanics: messages written under a lock are protected with message-level RLS and become readable to authorized participants and purchasers of a higher-ranked key.
- Original standalone local demo remains at `/demo.html`.

## Not production-ready
- Real-money billing, push notifications, moderation, reporting/blocking, account deletion.
- Real browser two-device end-to-end testing; database function smoke tests passed but the entire UI flow still needs human testing.
- This is a **test** of publicly browseable conversations. Don't send personal or sensitive information; messages outside lock periods are public.

## Current infrastructure
- GitHub: yeappi/tamacha
- Vercel: tamacha (production from main)
- Supabase: project tamacha (public RLS-enabled tables and server-validated RPC)

## Testing from two devices
1. Open the live app in two separate browsers.
2. Sign up with different email accounts; if confirmation is required, confirm via email and then sign in.
3. Create a mood ball in browser A.
4. Refresh world in browser B and open A's ball.
5. Send a message from B. In A's chat tab, reply.
6. Open the same room while signed in with a third account to verify view-only access.
7. Optionally test likes, follows, 04:00 daily counter and 3-day DM pause later.

## Security notes
- The only frontend credential is Supabase's **publishable** key; no secret/service-role key is committed.
- The API uses RLS on every exposed table.
- All three RPC functions intentionally run with elevated DB rights but explicitly validate `auth.uid()`, allowed participants, daily quota, and sender identity.
- No row in the MVP database represents a private or locked message.
