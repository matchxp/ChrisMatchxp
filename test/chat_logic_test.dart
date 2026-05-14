// ignore_for_file: prefer_function_declarations_over_variables

/// chat_logic_test.dart
///
/// Unit tests for the pure-logic functions used in ChatsScreen and
/// ChatConversationScreen.  No Supabase / Flutter widget context is needed —
/// these tests exercise only the data-transformation helpers that can be
/// extracted from the screen classes.
///
/// Run with:  flutter test test/chat_logic_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// =============================================================================
// ── Logic under test (copied verbatim from chats_screen.dart) ─────────────
// =============================================================================

/// Mirrors ChatsScreen._profileName
String profileName(Map<String, dynamic> profile) =>
    profile['first_name'] as String? ?? 'Match';

/// Mirrors ChatsScreen._lastMessagePreview
String lastMessagePreview(Map<String, dynamic>? lastMsg) {
  if (lastMsg == null) return 'Say hello 👋';
  return lastMsg['content'] as String? ?? '';
}

/// Mirrors ChatsScreen._lastMessageTime
String lastMessageTime(Map<String, dynamic>? lastMsg) {
  if (lastMsg == null) return '';
  final raw = lastMsg['created_at'] as String?;
  if (raw == null) return '';
  final dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

/// Mirrors ChatsScreen._isUnread (fixed — BUG-02 resolved)
bool isUnread(Map<String, dynamic>? lastMsg, String currentUserId) {
  if (lastMsg == null) return false;
  final senderId = lastMsg['sender_id'] as String?;
  final isRead = lastMsg['is_read'];
  // FIX BUG-02: != true treats null is_read as unread (correct behaviour).
  return senderId != null &&
      senderId != currentUserId &&
      isRead != true;
}

/// Mirrors ChatsScreen._filtered (search logic only)
List<Map<String, dynamic>> filterMatches(
  List<Map<String, dynamic>> matches,
  String searchQuery,
) {
  if (searchQuery.isEmpty) return matches;
  final q = searchQuery.toLowerCase().trim();
  return matches.where((m) {
    final profile = m['profile'] as Map<String, dynamic>;
    final name = profileName(profile).toLowerCase();
    final preview =
        lastMessagePreview(m['last_message'] as Map<String, dynamic>?)
            .toLowerCase();
    return name.contains(q) || preview.contains(q);
  }).toList();
}

/// Mirrors ChatConversationScreen._findClosestOptimistic (fixed — BUG-01 resolved)
///
/// When multiple identical-content placeholders exist, returns the index of
/// the one whose [created_at] is closest to [realCreatedAt].  Falls back to
/// first-match (FIFO) when timestamps are unavailable.
int findClosestOptimistic({
  required List<Map<String, dynamic>> messages,
  required String senderId,
  required String content,
  String? realCreatedAt,
}) {
  final candidates = messages
      .asMap()
      .entries
      .where((e) =>
          e.value['id'] == null &&
          e.value['sender_id'] == senderId &&
          e.value['content'] == content)
      .toList();

  if (candidates.isEmpty) return -1;
  if (candidates.length == 1 || realCreatedAt == null) {
    return candidates.first.key;
  }

  final realTs = DateTime.tryParse(realCreatedAt);
  if (realTs == null) return candidates.first.key;

  int bestIdx = candidates.first.key;
  Duration bestDiff = const Duration(days: 999);

  for (final entry in candidates) {
    final optTs = DateTime.tryParse(
        entry.value['created_at'] as String? ?? '');
    if (optTs == null) continue;
    final diff = realTs.difference(optTs).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      bestIdx = entry.key;
    }
  }
  return bestIdx;
}

// =============================================================================
// ── Tests ─────────────────────────────────────────────────────────────────────
// =============================================================================

void main() {
  const myUserId = 'user-aaa-111';
  const otherUserId = 'user-bbb-222';

  // ---------------------------------------------------------------------------
  // TC-01: Search by name
  // ---------------------------------------------------------------------------
  test('TC-01 · filterMatches returns only name-matching entry', () {
    final matches = [
      {
        'profile': {'first_name': 'Alex'},
        'last_message': {'content': 'Hey!', 'created_at': ''},
      },
      {
        'profile': {'first_name': 'Jordan'},
        'last_message': {'content': 'What\'s up?', 'created_at': ''},
      },
    ];

    final result = filterMatches(matches, 'alex');
    expect(result.length, equals(1));
    expect(
        (result.first['profile'] as Map<String, dynamic>)['first_name'],
        equals('Alex'));
  });

  // ---------------------------------------------------------------------------
  // TC-02: Search by message preview
  // ---------------------------------------------------------------------------
  test('TC-02 · filterMatches returns only preview-matching entry', () {
    final matches = [
      {
        'profile': {'first_name': 'Sam'},
        'last_message': {'content': 'Say hello 👋', 'created_at': ''},
      },
      {
        'profile': {'first_name': 'Taylor'},
        'last_message': {'content': 'Let\'s meet', 'created_at': ''},
      },
    ];

    final result = filterMatches(matches, 'hello');
    expect(result.length, equals(1));
    expect(
        (result.first['profile'] as Map<String, dynamic>)['first_name'],
        equals('Sam'));
  });

  // ---------------------------------------------------------------------------
  // TC-03: isUnread → true when message is from other user and unread
  // ---------------------------------------------------------------------------
  test('TC-03 · isUnread returns true for unread message from other user', () {
    final msg = {'sender_id': otherUserId, 'is_read': false};
    expect(isUnread(msg, myUserId), isTrue);
  });

  // ---------------------------------------------------------------------------
  // TC-04: isUnread → false when message is from current user
  // ---------------------------------------------------------------------------
  test('TC-04 · isUnread returns false when current user sent the message', () {
    final msg = {'sender_id': myUserId, 'is_read': false};
    expect(isUnread(msg, myUserId), isFalse);
  });

  // ---------------------------------------------------------------------------
  // TC-05: lastMessageTime → 'now' for message under 1 minute old
  // ---------------------------------------------------------------------------
  test('TC-05 · lastMessageTime returns "now" for sub-minute message', () {
    final ts = DateTime.now()
        .subtract(const Duration(seconds: 30))
        .toUtc()
        .toIso8601String();
    final result = lastMessageTime({'created_at': ts});
    expect(result, equals('now'));
  });

  // ---------------------------------------------------------------------------
  // TC-06: lastMessageTime → '2h' for message 2 hours old
  // ---------------------------------------------------------------------------
  test('TC-06 · lastMessageTime returns "2h" for message 2 hours ago', () {
    final ts = DateTime.now()
        .subtract(const Duration(hours: 2))
        .toUtc()
        .toIso8601String();
    final result = lastMessageTime({'created_at': ts});
    expect(result, equals('2h'));
  });

  // ---------------------------------------------------------------------------
  // TC-07: BUG-01 FIXED — timestamp-proximity matching picks the right placeholder
  // ---------------------------------------------------------------------------
  test(
      'TC-07 · findClosestOptimistic matches by created_at proximity when '
      'two identical-content placeholders exist (BUG-01 fixed)', () {
    const t1 = '2026-05-14T10:00:00.000Z';
    const t2 = '2026-05-14T10:00:01.000Z';

    final messages = <Map<String, dynamic>>[
      {'id': null, 'sender_id': myUserId, 'content': 'ok', 'created_at': t1},
      {'id': null, 'sender_id': myUserId, 'content': 'ok', 'created_at': t2},
    ];

    // Real event whose server timestamp matches the SECOND optimistic (t2).
    final idx = findClosestOptimistic(
      messages: messages,
      senderId: myUserId,
      content: 'ok',
      realCreatedAt: t2,
    );

    // Now correctly returns 1 (closest timestamp match).
    expect(idx, equals(1));
  });

  test(
      'TC-07b · findClosestOptimistic falls back to first match (FIFO) '
      'when no realCreatedAt is provided', () {
    const t1 = '2026-05-14T10:00:00.000Z';
    const t2 = '2026-05-14T10:00:01.000Z';

    final messages = <Map<String, dynamic>>[
      {'id': null, 'sender_id': myUserId, 'content': 'ok', 'created_at': t1},
      {'id': null, 'sender_id': myUserId, 'content': 'ok', 'created_at': t2},
    ];

    final idx = findClosestOptimistic(
      messages: messages,
      senderId: myUserId,
      content: 'ok',
      realCreatedAt: null, // no timestamp → FIFO
    );

    expect(idx, equals(0));
  });

  // ---------------------------------------------------------------------------
  // TC-08: BUG-02 FIXED — isUnread returns true when is_read is null
  // ---------------------------------------------------------------------------
  test(
      'TC-08 · isUnread returns true when is_read is null (BUG-02 fixed)', () {
    // is_read field absent from DB row → Dart receives null.
    // With the fix (isRead != true), null is correctly treated as unread.
    final msg = {'sender_id': otherUserId, 'is_read': null};
    expect(isUnread(msg, myUserId), isTrue);
  });
}
