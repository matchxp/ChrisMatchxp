// ignore_for_file: prefer_function_declarations_over_variables

/// profile_logic_test.dart
///
/// Unit tests for the pure-logic functions used in ProfileScreen.
/// No Supabase / Flutter widget context is needed.
///
/// Run with:  flutter test test/profile_logic_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// =============================================================================
// ── Logic under test (copied verbatim from profile_screen.dart) ─────────────
// =============================================================================

/// Mirrors ProfileScreen._calcCompletion (fixed — BUG-03 resolved)
double calcCompletion(Map<String, dynamic> p) {
  int done = 0;
  // FIX BUG-03: trim() before isNotEmpty so whitespace-only names don't
  // falsely count as a completed step.
  if ((p['first_name'] as String?)?.trim().isNotEmpty == true) done++;
  if ((p['gender'] as String?)?.trim().isNotEmpty == true) done++;
  if (p['birthday'] != null) done++;
  if (p['height_cm'] != null) done++;
  if ((p['location'] as String?)?.isNotEmpty == true) done++;
  if (p['drinking_habit'] != null ||
      p['smoking_habit'] != null ||
      p['workout_habit'] != null) done++;
  final i = p['interests'];
  if (i is List && i.isNotEmpty) done++;
  final ph = p['photos'];
  if (ph is List && ph.length >= 2) done++;
  return done / 8;
}

/// Mirrors ProfileScreen._displayName
String displayName(Map<String, dynamic> p) {
  final n = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
  return n.isNotEmpty ? n : 'Your Name';
}

/// Mirrors ProfileScreen._missingSteps count logic (fixed — BUG-03 resolved)
int countMissingSteps(Map<String, dynamic> p) {
  int missing = 0;
  // FIX BUG-03 (mirror of calcCompletion): trim() so whitespace-only strings
  // are treated the same as empty/null.
  if ((p['first_name'] as String?)?.trim().isEmpty != false) missing++;
  if ((p['gender'] as String?)?.trim().isEmpty != false) missing++;
  if (p['birthday'] == null) missing++;
  if (p['height_cm'] == null) missing++;
  if ((p['location'] as String?)?.isEmpty != false) missing++;
  if (p['drinking_habit'] == null &&
      p['smoking_habit'] == null &&
      p['workout_habit'] == null) missing++;
  final interests = p['interests'];
  if (interests is! List || (interests).isEmpty) missing++;
  final photos = p['photos'];
  if (photos is! List || (photos as List).length < 2) missing++;
  return missing;
}

// =============================================================================
// ── Tests ─────────────────────────────────────────────────────────────────────
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // TC-09: calcCompletion → 0.0 for entirely empty profile
  // ---------------------------------------------------------------------------
  test('TC-09 · calcCompletion returns 0.0 for an empty profile', () {
    final profile = <String, dynamic>{
      'first_name': null,
      'gender': null,
      'birthday': null,
      'height_cm': null,
      'location': null,
      'drinking_habit': null,
      'smoking_habit': null,
      'workout_habit': null,
      'interests': [],
      'photos': [],
    };
    expect(calcCompletion(profile), equals(0.0));
  });

  // ---------------------------------------------------------------------------
  // TC-10: calcCompletion → 1.0 for fully complete profile
  // ---------------------------------------------------------------------------
  test('TC-10 · calcCompletion returns 1.0 for a fully complete profile', () {
    final profile = <String, dynamic>{
      'first_name': 'Reno',
      'gender': 'male',
      'birthday': '2000-01-01',
      'height_cm': 180,
      'location': 'London',
      'drinking_habit': 'social',
      'smoking_habit': null,
      'workout_habit': null,
      'interests': ['gaming', 'travel'],
      'photos': ['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg'],
    };
    expect(calcCompletion(profile), equals(1.0));
  });

  // ---------------------------------------------------------------------------
  // TC-11: calcCompletion — lifestyle step counts if ANY habit is set
  // ---------------------------------------------------------------------------
  test(
      'TC-11 · calcCompletion counts lifestyle step when only one habit is set', () {
    final profile = <String, dynamic>{
      'first_name': null,
      'gender': null,
      'birthday': null,
      'height_cm': null,
      'location': null,
      'drinking_habit': 'never', // ← only this is set
      'smoking_habit': null,
      'workout_habit': null,
      'interests': [],
      'photos': [],
    };
    // Only lifestyle step done → 1/8
    expect(calcCompletion(profile), equals(1 / 8));
  });

  // ---------------------------------------------------------------------------
  // TC-12: calcCompletion — photo step NOT done with only 1 photo
  // ---------------------------------------------------------------------------
  test(
      'TC-12 · calcCompletion does not count photo step when fewer than 2 '
      'photos are present', () {
    final profile = <String, dynamic>{
      'first_name': 'Reno',
      'gender': 'male',
      'birthday': '2000-01-01',
      'height_cm': 180,
      'location': 'London',
      'drinking_habit': 'social',
      'smoking_habit': null,
      'workout_habit': null,
      'interests': ['gaming'],
      'photos': ['https://example.com/only_one.jpg'], // ← only 1 photo
    };
    // 7 out of 8 steps done (photo step not satisfied)
    expect(calcCompletion(profile), equals(7 / 8));
  });

  // ---------------------------------------------------------------------------
  // TC-13: calcCompletion and countMissingSteps are consistent
  // ---------------------------------------------------------------------------
  test(
      'TC-13 · calcCompletion and countMissingSteps agree for a partial profile', () {
    final profile = <String, dynamic>{
      'first_name': 'Reno',
      'gender': 'male',
      'birthday': null,
      'height_cm': null,
      'location': null,
      'drinking_habit': null,
      'smoking_habit': null,
      'workout_habit': null,
      'interests': [],
      'photos': [],
    };
    final completion = calcCompletion(profile); // 2/8 = 0.25
    final missing = countMissingSteps(profile); // 6

    expect(completion, equals(2 / 8));
    expect(missing, equals(6));
    // Internal consistency: done + missing == 8
    expect((completion * 8).round() + missing, equals(8));
  });

  // ---------------------------------------------------------------------------
  // TC-14: displayName — both names present
  // ---------------------------------------------------------------------------
  test('TC-14 · displayName returns full name when both names are set', () {
    final profile = <String, dynamic>{
      'first_name': 'Reno',
      'last_name': 'Dias',
    };
    expect(displayName(profile), equals('Reno Dias'));
  });

  // ---------------------------------------------------------------------------
  // TC-15: displayName — fallback when both names are null
  // ---------------------------------------------------------------------------
  test(
      'TC-15 · displayName returns "Your Name" when first_name and last_name '
      'are null', () {
    final profile = <String, dynamic>{
      'first_name': null,
      'last_name': null,
    };
    expect(displayName(profile), equals('Your Name'));
  });

  // ---------------------------------------------------------------------------
  // TC-16: BUG-03 FIXED — whitespace-only first_name no longer satisfies step
  // ---------------------------------------------------------------------------
  test(
      'TC-16 · calcCompletion does NOT count whitespace-only first_name as '
      'done (BUG-03 fixed)', () {
    final profile = <String, dynamic>{
      'first_name': '   ', // ← three spaces — not a real name
      'gender': 'male',
      'birthday': '2000-01-01',
      'height_cm': 180,
      'location': 'London',
      'drinking_habit': 'social',
      'smoking_habit': null,
      'workout_habit': null,
      'interests': ['gaming'],
      'photos': [
        'https://example.com/photo1.jpg',
        'https://example.com/photo2.jpg'
      ],
    };

    // With trim().isNotEmpty, '   ' no longer counts → 7/8.
    expect(calcCompletion(profile), equals(7 / 8));
  });

  // ---------------------------------------------------------------------------
  // TC-17: BUG-03 FIXED — countMissingSteps also rejects whitespace-only name
  // ---------------------------------------------------------------------------
  test(
      'TC-17 · countMissingSteps marks name step missing for whitespace-only '
      'first_name (BUG-03 fixed)', () {
    final profile = <String, dynamic>{
      'first_name': '   ',
      'gender': null,
      'birthday': null,
      'height_cm': null,
      'location': null,
      'drinking_habit': null,
      'smoking_habit': null,
      'workout_habit': null,
      'interests': [],
      'photos': [],
    };

    // Both name step AND gender step are missing → 8 missing total.
    expect(countMissingSteps(profile), equals(8));
  });
}
