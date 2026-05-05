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

/// Mirrors ChatsScreen._isUnread
bool isUnread(Map<String, dynamic>? lastMsg, String currentUserId) {
  if (lastMsg == null) return false;
  final senderId = lastMsg['sender_id'] as String?;
  final isRead = lastMsg['is_read'];
  return senderId != null &&
      senderId != currentUserId &&
      isRead == false; // ← BUG-02: null is_read is silently treated as read
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

/// Mirrors the deduplication branch inside ChatConversationScreen._subscribeToMessages
///
/// Returns the index of the optimistic placeholder that would be upgraded.
/// If two identical content+sender placeholders exist and a real message arrives,
/// indexWhere always matches the FIRST one — demonstrating BUG-01.
int findOptimisticIndex(
  List<Map<String, dynamic>> messages,
  String senderId,
  String content,
) {
  return messages.indexWhere((m) =>
      m['id'] == null &&
      m['sender_id'] == senderId &&
      m['content'] == content);
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
  // TC-07: BUG-01 — duplicate content deduplication matches wrong placeholder
  // ---------------------------------------------------------------------------
  test(
      'TC-07 · findOptimisticIndex always returns FIRST match when two '
      'identical-content placeholders exist (BUG-01)', () {
    // Simulate two optimistic 'ok' messages queued before realtime events arrive
    final messages = <Map<String, dynamic>>[
      {'id': null, 'sender_id': myUserId, 'content': 'ok', 'created_at': '1'},
      {'id': null, 'sender_id': myUserId, 'content': 'ok', 'created_at': '2'},
    ];

    // First real event arrives for the SECOND 'ok' (index 1)
    // Correct behaviour: match index 1. Actual behaviour: always returns 0.
    final idx = findOptimisticIndex(messages, myUserId, 'ok');

    // This assertion FAILS, exposing BUG-01:
    // indexWhere returns 0, not 1.
    expect(idx, equals(1));
  });

  // ---------------------------------------------------------------------------
  // TC-08: BUG-02 — isUnread returns false when is_read is null
  // ---------------------------------------------------------------------------
  test(
      'TC-08 · isUnread returns false when is_read is null (BUG-02 — '
      'should return true)', () {
    // is_read field absent from DB row → Dart receives null
    final msg = {'sender_id': otherUserId, 'is_read': null};

    // Expected (correct): true — message has not been confirmed read
    // Actual: false — because null == false evaluates to false in Dart
    expect(isUnread(msg, myUserId), isTrue); // ← this FAILS (BUG-02)
  });
}
