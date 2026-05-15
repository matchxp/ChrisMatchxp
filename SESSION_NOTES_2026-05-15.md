# MatchXP Session Notes — 2026-05-15

## Fixes Applied This Session

### FIX 1 — Duplicate game guard (verified, no change needed)
**File:** `lib/games/game_hub_screen.dart`
`_duplicateGuard()` already queries with `.neq('status', 'completed')`, so it correctly
blocks re-launching a game that is pending, submitted, or active.

---

### FIX 2 — "Solve Now" routes directly to WordSearchSupabaseWrapper
**File:** `lib/screens/chat_conversation_screen.dart`
When the locked bar shows `MatchGamePhase.solving`, tapping "Solve Now!" now navigates
directly to `WordSearchSupabaseWrapper` instead of going through `GameHubScreen`.
This removes one extra navigation step for the solver.

---

### FIX 3 — Game challenge card status labels corrected
**File:** `lib/screens/chat_conversation_screen.dart`
`liveStatusText()` now switches on the raw DB status string
(`pending / submitted / active / completed`) and produces human-readable labels:
- `completed` → "Solved ✓"
- `active` → "In Progress"
- `submitted` → "Waiting for [partner] to submit" / "Submit your puzzle to continue!"
- default → "Waiting for [partner] to accept…"

Also removed unused variables (`aSubmitted`, `bSubmitted`, `aSolved`, `bSolved`) that
caused compiler warnings after the status-text rewrite.

---

### FIX 4 — game_sessions.status updated on word search puzzle submission
**File:** `lib/games/word_search/word_search_supabase_wrapper.dart`
After a puzzle is submitted to `word_search_games`, the wrapper now looks up the active
`game_sessions` row and updates `player_a_submitted` / `player_b_submitted` flags plus
`status` (`submitted` when one player done, `active` when both done). This keeps the
chat card status in sync without any schema changes.

---

### FIX 5 — "It's a Match" popup helper text updated
**File:** `lib/screens/home_screen.dart`
Changed helper text from:
> "Play a quick icebreaker to unlock your chat — it's interactive!"

To:
> "Play a mini icebreaker game to unlock chat — it's interactive & fun!"

---

### FIX 6 — matches.chat_unlocked persisted to Supabase on game completion
**Files:** `lib/screens/chat_conversation_screen.dart`,
           `lib/games/game_hub_screen.dart`,
           `lib/games/word_search/word_search_supabase_wrapper.dart`

All three `onChatUnlocked` call sites now write `{'chat_unlocked': true}` to the
`matches` table so the partner's client (listening via `_matchUnlockChannel`) sees
the unlock immediately on their next poll/realtime event.

---

### FIX 7 — Replaced one-shot fetch with Supabase .stream() for messages & game sessions
**File:** `lib/screens/chat_conversation_screen.dart`

**Messages** (`_subscribeMessages()`):
- Opens a `.stream(primaryKey: ['id'])` subscription on `messages` filtered by `match_id`.
- Optimistic messages (id == null) are preserved across stream updates by comparing
  `sender_id + content` before evicting them.
- Auto-scroll logic: scroll on first load; scroll on new partner messages unless user
  has scrolled up (in which case increment `_unreadWhileScrolled` badge).

**Game sessions** (`_subscribeSessionStream()`):
- Opens a `.stream(primaryKey: ['id'])` subscription on `game_sessions` filtered by
  `match_id`, replacing the old one-shot `_loadSessionStates()` + postgres_changes listener.
- `_sessionStates` map is rebuilt on every emission.

**dispose()** cancels both `StreamSubscription`s before the parent dispose.

---

### Game Challenge Optimistic Insert
**File:** `lib/screens/chat_conversation_screen.dart` — `_sendGameChallenge()`

Game invitation cards now appear instantly (like text/voice/image messages) using an
optimistic insert pattern:
1. Add a placeholder message `{id: null, message_type: 'game_challenge', meta: {game_type, status: 'pending'}}` to `_messages` and scroll to bottom immediately.
2. Call `create_game_challenge` RPC in the background.
3. On success → call `_loadMessages()` to replace the placeholder with the real server row.
4. On failure → remove the placeholder and show a SnackBar error.

The existing `_buildGameChallengeBubble()` renders optimistic cards correctly:
- `isMe == true` → "You sent a challenge"
- `sessionId == null` (id is null) → no Accept button
- `liveStatus == 'pending'` → "Waiting for [partner] to accept…"

---

### FIX 8 — Game challenge card evicted prematurely by stream dedup
**File:** `lib/screens/chat_conversation_screen.dart` — `_subscribeMessages()` merge logic

**Root cause:** Game challenge messages always have `content == ''`. The stream merge
logic deduped optimistic messages by `sender_id + content`. When the stream fired after
an optimistic insert, any *old* game_challenge message already in the DB (same sender,
same empty content) would match the new optimistic and evict it — making the card
disappear immediately after tapping Send.

**Fix:** Added a 30-second timestamp window to the dedup check. A server message is
only treated as the server-confirmed counterpart of an optimistic if its `created_at`
is within 30 seconds of the optimistic's `created_at`. Old messages (created minutes or
days ago) are ignored, so the optimistic card stays visible until the RPC completes and
`_loadMessages()` replaces it with the real row.

```dart
// Before (broken for empty-content messages):
return !serverMsgs.any((s) =>
    s['sender_id'] == m['sender_id'] && s['content'] == m['content']);

// After (timestamp-guarded):
final optTime = DateTime.tryParse(m['created_at'] as String? ?? '');
return !serverMsgs.any((s) {
  if (s['sender_id'] != m['sender_id'] || s['content'] != m['content']) { return false; }
  if (optTime != null) {
    final svrTime = DateTime.tryParse(s['created_at'] as String? ?? '');
    if (svrTime != null && optTime.difference(svrTime).inSeconds > 30) { return false; }
  }
  return true;
});
```

---

## Files Modified

| File | Fixes |
|------|-------|
| `lib/screens/chat_conversation_screen.dart` | FIX 2, 3, 6, 7, Game Challenge, 2026-05-16 rewrite |
| `lib/games/game_hub_screen.dart` | FIX 6 |
| `lib/games/word_search/word_search_supabase_wrapper.dart` | FIX 4, 6 |
| `lib/screens/home_screen.dart` | FIX 5 |
| `lib/services/matching_service.dart` | 2026-05-16 broadcastMessage |

## Files NOT Modified (as per rules)
- No Supabase schema changes
- No UI color/theme/font changes
- No unrelated files touched

---

# Session Notes — 2026-05-16

## In-Chat Game Invitation — Full Rewrite & Fix

### Root Cause (discovered via Supabase SQL query)

Only `emoji_charades_games` is in the `supabase_realtime` publication:
```sql
SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
-- result: only emoji_charades_games
```

`messages` and `game_sessions` are NOT in the publication. This means:
- `.stream()` subscriptions on `messages` only fire **once** (the initial HTTP fetch). They never fire again on INSERT/UPDATE.
- `onPostgresChanges` listeners on `messages` also never fire.
- The comment in code "stream handles delivery" was wrong — the stream cannot handle delivery for tables outside the publication.

Real-time delivery for text messages was already working via **WebSocket broadcast** (`sendBroadcastMessage(event: 'msg', ...)`), but the `onMessage` callback in the chat screen was set to `(_) {}` (discarded). So neither game challenges NOR partner text messages were appearing in real-time during a session.

---

### What We Tried First (didn't work)

1. **Optimistic insert + `_restartMessageStream()`** — stream restart does a fresh HTTP fetch but the dedup logic was evicting the optimistic card because old game_challenge messages share the same `sender_id + content: ''`.
2. **60-second time window in dedup** — still evicted because the user had sent other invites within 60 seconds of the new one.
3. **Smarter game_challenge dedup** (5-second window, matching by game_type) — still not working because the fundamental delivery mechanism was broken.

---

### What Actually Fixed It

**Three changes across two files:**

#### 1. `lib/services/matching_service.dart` — Added `broadcastMessage()`

```dart
void broadcastMessage(String matchId, Map<String, dynamic> payload) {
  _chatChannels[matchId]
      ?.sendBroadcastMessage(event: 'msg', payload: payload);
}
```

Used to notify the partner's client after a game challenge is inserted into the DB.

---

#### 2. `lib/screens/chat_conversation_screen.dart` — Fixed `onMessage` handler

**Before:**
```dart
_channel = _matchingService.subscribeToMessages(
  widget.matchId,
  (_) {}, // stream handles delivery — WRONG, stream never fires after init
  ...
);
```

**After:**
```dart
_channel = _matchingService.subscribeToMessages(
  widget.matchId,
  (_) { if (mounted) _restartMessageStream(); }, // refresh on any broadcast
  ...
);
```

This also fixes partner text messages not appearing in real-time.

---

#### 3. `lib/screens/chat_conversation_screen.dart` — Rewrote `_sendGameChallenge()`

Old approach relied on `.stream()` to pick up the new message — which never worked.

New approach (completely stream-independent):

```dart
Future<void> _sendGameChallenge(String gameType) async {
  // 1. Optimistic insert — card appears immediately on sender's screen.
  setState(() => _messages.add(optimistic));
  _scrollToBottom();

  try {
    // 2. Insert game_sessions row, get back the session ID.
    final sessionRes = await db.from('game_sessions').insert({...}).select('id').single();
    final sessionId = sessionRes['id'];

    // 3. Insert messages row, get the full real row back from DB.
    final realMsg = await db.from('messages').insert({
      ..., 'meta': {'session_id': sessionId, 'game_type': gameType},
    }).select().single();

    // 4. Replace optimistic with real row (now has session_id for Accept button).
    setState(() {
      _messages.removeWhere((m) => m['id'] == null && ...);
      _messages.add(realMsg);
      _messages.sort(...);
    });

    // 5. Broadcast so partner's onMessage fires → _restartMessageStream() → card appears.
    _matchingService.broadcastMessage(widget.matchId, realMsg);
  } catch (e) {
    // Remove optimistic, show error.
  }
}
```

**Why this works:**
- **Sender**: optimistic shows card in ~0ms. Real row replaces it in ~300ms (after DB round-trip). No stream dependency.
- **Partner**: receives `msg` broadcast → `onMessage` → `_restartMessageStream()` → fresh HTTP fetch from DB → card appears.

---

### Stream Dedup Also Fixed (bonus cleanup)

The stream dedup in `_onMessageStreamRows` was using `sender_id + content` to match optimistics to server rows. For game challenges, `content: ''` made all invites indistinguishable, causing any old invite to evict a new optimistic.

Fixed by adding a special case: game_challenge messages are matched by `message_type + sender_id + game_type + 5-second timestamp window` instead of by content.
