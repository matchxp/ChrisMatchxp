# Rock Paper Scissors — Integration Guide
## MatchX App · Sprint 5

---

## 1. File Structure

Drop the entire folder into your project:

```
lib/features/rock_paper_scissors/
├── rock_paper_scissors.dart          ← barrel export (import this)
├── rps_theme.dart                    ← colours, fonts, gradients
├── data/
│   ├── rps_models.dart               ← RPSMove, RPSResult, helpers
│   └── rps_local_match_store.dart    ← singleton game state store
├── widgets/
│   └── rps_widgets.dart              ← RPSBackground, RPSPillButton,
│                                        RPSNavBar, RPSMoveCard,
│                                        RPSGlowBlobs, RPSPulsingDot
└── screens/
    ├── rps_intro_screen.dart         ← ROCK / PAPER / SCISSORS landing
    ├── rps_tutorial_sheet.dart       ← bottom-sheet "How to play"
    ├── rps_pick_screen.dart          ← choose your move
    ├── rps_waiting_screen.dart       ← waiting for opponent
    ├── rps_reveal_screen.dart        ← countdown 3-2-1-0 + reveal
    └── rps_result_screen.dart        ← You Win / You Lose / It's a Draw
```

---

## 2. Font Setup

The game uses **Fredoka One** (titles) and **Fredoka** (body text).

Add to `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: FredokaOne
      fonts:
        - asset: assets/fonts/FredokaOne-Regular.ttf
    - family: Fredoka
      fonts:
        - asset: assets/fonts/Fredoka-Regular.ttf
          weight: 400
        - asset: assets/fonts/Fredoka-SemiBold.ttf
          weight: 600
```

Download from Google Fonts:
- https://fonts.google.com/specimen/Fredoka+One
- https://fonts.google.com/specimen/Fredoka

Place the `.ttf` files in `assets/fonts/`.

---

## 3. Opening the Game

From your chat screen or match screen button:

```dart
import 'features/rock_paper_scissors/rock_paper_scissors.dart';

Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => RPSIntroScreen(
    currentUserId:   currentUser.id,
    currentUserName: currentUser.displayName,
    opponentId:      match.userId,
    opponentName:    match.displayName,
  ),
));
```

---

## 4. Screen Flow

```
RPSIntroScreen
  │  (Play now)
  ▼
RPSPickScreen
  │  (Lock in move)
  ▼
RPSWaitingScreen          ← polls RPSLocalMatchStore every 500 ms
  │  (both submitted)
  ▼
RPSRevealScreen           ← countdown 3→2→1→0, then reveal
  │  (auto after 2.2 s)
  ▼
RPSResultScreen           ← You Win / You Lose / It's a Draw
  ├── Start Chatting      ← popUntil(isFirst)
  └── Play Again          ← store.reset() → RPSIntroScreen
```

---

## 5. Replacing LocalMatchStore with Supabase

`RPSLocalMatchStore` is a singleton that holds moves in memory.
For real online play, swap two things:

### A. Submitting a move (rps_pick_screen.dart)

Replace:
```dart
_store.submitMove(widget.currentUserId, _selected!);
```

With a Supabase upsert:
```dart
await supabase.from('rps_games').upsert({
  'match_id': matchId,
  '${isPlayer1 ? "player1" : "player2"}_move': _selected!.name,
});
```

### B. Polling for opponent (rps_waiting_screen.dart)

Replace the `Timer.periodic` poll with a Supabase stream:
```dart
supabase
  .from('rps_games')
  .stream(primaryKey: ['match_id'])
  .eq('match_id', matchId)
  .listen((rows) {
    if (rows.first['player1_move'] != null &&
        rows.first['player2_move'] != null) {
      _goReveal();
    }
  });
```

### Suggested Supabase table schema

```sql
create table rps_games (
  id           uuid primary key default gen_random_uuid(),
  match_id     text not null,
  player1_id   text not null,
  player2_id   text not null,
  player1_move text,           -- 'rock' | 'paper' | 'scissors'
  player2_move text,
  created_at   timestamptz default now()
);
```

---

## 6. Design Decisions

| Decision | Value |
|---|---|
| Fonts | Fredoka One (titles), Fredoka SemiBold (body) |
| Background | Dark-purple radial gradient (#3b1580 → #040210) |
| Primary colour | #7C3AED (purple) |
| Pill button | Linear gradient #5B2FCE → #B07CFF |
| Loser label | "You Lose" (not opponent name) — keeps layout consistent |
| Confetti | Win only, canvas-based, colours match app palette |
| Outcome font size | 44px — single line for all 3 outcomes |
| Status row | 80 px bottom margin on waiting screen |

---

## 7. Testing on One Device

To simulate a 2-player game without 2 devices:

1. Open the app and play as Player 1 — choose a move and lock in.
2. In debug mode, call `RPSLocalMatchStore.instance.submitMove(opponentId, RPSMove.scissors)` from the Flutter console or add a temporary debug button.
3. The waiting screen will auto-advance within 500 ms.

---

*Developed as part of Sprint 5 · MatchX App*
