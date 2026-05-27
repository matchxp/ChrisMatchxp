import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Keeps active broadcast channels so sendMessage can fire instantly
  final Map<String, RealtimeChannel> _chatChannels = {};

  /// Get profiles for swiping.
  /// [onlyExcludeMatched] = true → only exclude already-matched users (used for refresh reset).
  /// [onlyExcludeMatched] = false (default) → also exclude liked + passed users.
  Future<List<Map<String, dynamic>>> getDiscoverProfiles({
    int limit = 20,
    bool onlyExcludeMatched = false,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      if (currentUserId == null) {
        debugPrint('❌ No authenticated user');
        return [];
      }

      debugPrint('\n🔍 ========== FETCHING DISCOVER PROFILES ==========');
      debugPrint('📋 User ID: $currentUserId');
      debugPrint('📋 Limit: $limit | resetMode: $onlyExcludeMatched');

      // Get user's own profile to filter by preferences
      final myProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUserId)
          .single();

      debugPrint('👤 My profile: ${myProfile['first_name']}');

      // Always exclude already matched users
      List<String> matchedIds = [];
      try {
        matchedIds = await getMatchedUserIds();
      } catch (_) {}

      List<String> excludedIds = [currentUserId, ...matchedIds];

      // In normal mode also exclude liked + passed profiles
      if (!onlyExcludeMatched) {
        List<String> likedIds = [];
        List<String> passedIds = [];
        try {
          likedIds = await _getInteractedUserIds(currentUserId, 'likes');
        } catch (_) {}
        try {
          passedIds = await _getInteractedUserIds(currentUserId, 'passes');
        } catch (_) {}
        excludedIds = [currentUserId, ...matchedIds, ...likedIds, ...passedIds];
      }

      debugPrint('🚫 Excluded user count: ${excludedIds.length}');

      var query = _supabase
          .from('profiles')
          .select()
          .eq('profile_completed', true)
          .neq('id', currentUserId);

      if (excludedIds.length > 1) {
        query = query.filter('id', 'not.in', '(${excludedIds.join(',')})');
      }

      final profiles = await query
          .limit(limit)
          .timeout(const Duration(seconds: 10), onTimeout: () => []);

      debugPrint('✅ Found ${profiles.length} profiles');
      debugPrint('==========================================\n');

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      debugPrint('❌ Error fetching discover profiles: $e');
      return [];
    }
  }

  /// Get user IDs that the current user has already matched with
  Future<List<String>> getMatchedUserIds() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final matches = await _supabase
          .from('matches')
          .select('user_id_1, user_id_2')
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId')
          .timeout(const Duration(seconds: 8), onTimeout: () => []);

      return matches.map<String>((m) {
        return m['user_id_1'] == currentUserId
            ? m['user_id_2'] as String
            : m['user_id_1'] as String;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching matched user IDs: $e');
      return [];
    }
  }

  /// Get user IDs that have been liked or passed
  Future<List<String>> _getInteractedUserIds(
    String userId,
    String tableName,
  ) async {
    try {
      final columnName = tableName == 'likes' ? 'liked_id' : 'passed_id';
      final userColumnName = tableName == 'likes' ? 'liker_id' : 'passer_id';

      final results = await _supabase
          .from(tableName)
          .select(columnName)
          .eq(userColumnName, userId)
          .timeout(const Duration(seconds: 8), onTimeout: () => []);

      return results.map<String>((row) => row[columnName] as String).toList();
    } catch (e) {
      debugPrint('❌ Error getting $tableName: $e');
      return [];
    }
  }

  /// Like a profile.
  /// Returns the new matchId (String) if this like created a mutual match,
  /// or null if it was a one-way like.
  Future<String?> likeProfile(String likedUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      if (currentUserId == null) return null;

      debugPrint('❤️ Liking profile: $likedUserId');

      // Insert like — ignore if already exists (re-swipe after data reset)
      await _supabase.from('likes').upsert(
        {'liker_id': currentUserId, 'liked_id': likedUserId},
        onConflict: 'liker_id,liked_id',
        ignoreDuplicates: true,
      );

      // Check if it's a match (they also liked us)
      final mutualLike = await _supabase
          .from('likes')
          .select()
          .eq('liker_id', likedUserId)
          .eq('liked_id', currentUserId)
          .maybeSingle();

      if (mutualLike != null) {
        // It's a match! Create match record and return the matchId.
        // currentUserId is User B (second liker who completed the match).
        final matchId = await _createMatch(currentUserId, likedUserId,
            matchedBy: currentUserId);
        debugPrint('🎉 IT\'S A MATCH! matchId=$matchId');
        // Notify User A (the first liker) — they missed the popup when they swiped
        if (matchId != null) {
          _notifyUserOfNewMatch(likedUserId, matchId: matchId, partnerId: currentUserId);
        }
        return matchId;
      }

      debugPrint('✅ Like recorded');
      return null;
    } catch (e) {
      debugPrint('❌ Error liking profile: $e');
      return null;
    }
  }

  /// Pass on a profile
  Future<void> passProfile(String passedUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      
      if (currentUserId == null) return;

      debugPrint('👎 Passing profile: $passedUserId');

      await _supabase.from('passes').upsert(
        {'passer_id': currentUserId, 'passed_id': passedUserId},
        onConflict: 'passer_id,passed_id',
        ignoreDuplicates: true,
      );

      debugPrint('✅ Pass recorded');
    } catch (e) {
      debugPrint('❌ Error passing profile: $e');
    }
  }

  /// Super like a profile — returns matchId if it triggered a match, else null.
  Future<String?> superLikeProfile(String likedUserId) async {
    // For now, treat super like as a regular like
    // TODO: Add super_like column to likes table to differentiate
    return await likeProfile(likedUserId);
  }

  /// Create a match between two users. Returns the new match's ID.
  /// [matchedBy] is the user who completed the match (the second liker, User B).
  Future<String?> _createMatch(String userId1, String userId2,
      {String? matchedBy}) async {
    try {
      // Ensure consistent ordering (smaller ID first)
      final ids = [userId1, userId2]..sort();

      final row = await _supabase.from('matches').insert({
        'user_id_1': ids[0],
        'user_id_2': ids[1],
        if (matchedBy != null) 'matched_by': matchedBy,
      }).select('id').single();

      final matchId = row['id'] as String;
      debugPrint('✅ Match created: $matchId (${ids[0]} ↔ ${ids[1]})');
      return matchId;
    } catch (e) {
      debugPrint('❌ Error creating match: $e');
      return null;
    }
  }

  /// Broadcast a new_match event to User A (first liker) so they see the popup.
  /// Subscribes to the channel first — sendBroadcastMessage requires an active subscription.
  void _notifyUserOfNewMatch(String userId, {required String matchId, required String partnerId}) {
    final channel = _supabase.channel('user_notif_$userId');
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        channel.sendBroadcastMessage(event: 'new_match', payload: {
          'match_id': matchId,
          'partner_id': partnerId,
        });
        Future.delayed(const Duration(seconds: 2), () {
          _supabase.removeChannel(channel);
        });
      }
    });
  }

  /// Subscribe to personal match notifications for [userId].
  /// Fires when another user likes back and creates a match.
  RealtimeChannel subscribeToMatchNotifications(
    String userId,
    void Function(String matchId, String partnerId) onNewMatch,
  ) {
    return _supabase
        .channel('user_notif_$userId')
        .onBroadcast(
          event: 'new_match',
          callback: (payload) {
            final matchId = payload['match_id'] as String?;
            final partnerId = payload['partner_id'] as String?;
            if (matchId != null && partnerId != null) {
              onNewMatch(matchId, partnerId);
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Match notif channel ready for: $userId');
          }
        });
  }

  /// Get all matches for current user
  Future<List<Map<String, dynamic>>> getMatches() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      
      if (currentUserId == null) return [];

      debugPrint('💑 Fetching matches for: $currentUserId');

      final matches = await _supabase
          .from('matches')
          .select('*, user_id_1(*), user_id_2(*)')
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId')
          .order('matched_at', ascending: false);

      debugPrint('✅ Found ${matches.length} matches');
      return List<Map<String, dynamic>>.from(matches);
    } catch (e) {
      debugPrint('❌ Error fetching matches: $e');
      return [];
    }
  }

  /// Get profile by ID
  Future<Map<String, dynamic>?> getProfileById(String profileId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', profileId)
          .single();

      return profile;
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      return null;
    }
  }

  /// Get matches with the other person's profile info
  Future<List<Map<String, dynamic>>> getMatchesWithProfiles() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final matches = await _supabase
          .from('matches')
          .select()
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId')
          .order('matched_at', ascending: false)
          .timeout(const Duration(seconds: 10), onTimeout: () => []);

      List<Map<String, dynamic>> result = [];
      for (final match in matches) {
        final otherUserId = match['user_id_1'] == currentUserId
            ? match['user_id_2']
            : match['user_id_1'];
        final profile = await getProfileById(otherUserId);
        if (profile != null) {
          result.add({
            'match_id': match['id'],
            'matched_at': match['matched_at'],
            'matched_by': match['matched_by'], // who completed the match (User B)
            'profile': profile,
          });
        }
      }
      debugPrint('💑 Loaded ${result.length} matches with profiles');
      return result;
    } catch (e) {
      debugPrint('❌ Error fetching matches with profiles: $e');
      return [];
    }
  }

  /// Get messages for a match (oldest first)
  Future<List<Map<String, dynamic>>> getMessages(String matchId) async {
    try {
      final messages = await _supabase
          .from('messages')
          .select()
          .eq('match_id', matchId)
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 10), onTimeout: () => []);
      return List<Map<String, dynamic>>.from(messages);
    } catch (e) {
      debugPrint('❌ Error fetching messages: $e');
      return [];
    }
  }

  /// Send a message — broadcasts instantly over WebSocket for real-time delivery,
  /// then persists to DB in the background for message history.
  Future<bool> sendMessage(
    String matchId,
    String content, {
    String? replyToContent,
    String? replyToSender,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      final payload = <String, dynamic>{
        'match_id': matchId,
        'sender_id': currentUserId,
        'content': content,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        if (replyToContent != null) 'reply_to_content': replyToContent,
        if (replyToSender  != null) 'reply_to_sender':  replyToSender,
      };

      // 1️⃣ Broadcast instantly over WebSocket (~50ms) so the other person
      //    sees the message in real-time without waiting for the DB write.
      final channel = _chatChannels[matchId];
      if (channel != null) {
        channel.sendBroadcastMessage(event: 'msg', payload: payload);
      }

      // 2️⃣ Persist to DB (including reply metadata)
      final dbRow = <String, dynamic>{
        'match_id': matchId,
        'sender_id': currentUserId,
        'content': content,
        if (replyToContent != null) 'reply_to_content': replyToContent,
        if (replyToSender  != null) 'reply_to_sender':  replyToSender,
      };
      _supabase.from('messages').insert(dbRow)
          .catchError((e) => debugPrint('❌ DB persist error: $e'));

      return true;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }

  /// Get the most recent message for a match
  Future<Map<String, dynamic>?> getLastMessage(String matchId) async {
    try {
      final message = await _supabase
          .from('messages')
          .select()
          .eq('match_id', matchId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      return message;
    } catch (e) {
      debugPrint('❌ Error fetching last message: $e');
      return null;
    }
  }

  /// Mark all incoming messages in a match as read by the current user.
  /// Also broadcasts a `read_receipt` event so the sender's screen updates
  /// the double-tick immediately without waiting for a postgres_changes event
  /// (messages table is not in the realtime publication).
  Future<void> markMessagesAsRead(String matchId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('match_id', matchId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);

      // Notify the sender's device via broadcast so their double-tick updates
      // instantly — postgres_changes UPDATEs never fire for messages.
      _chatChannels[matchId]?.sendBroadcastMessage(
        event: 'read_receipt',
        payload: {'match_id': matchId},
      );

      debugPrint('✅ Marked messages as read for match: $matchId');
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  /// Subscribe to broadcast messages on a specific match channel.
  /// Used by the global notification listener — piggybacks on the same
  /// Broadcast topic as the chat screen so no extra Realtime config is needed.
  RealtimeChannel subscribeToMatchBroadcast(
      String matchId,
      void Function(Map<String, dynamic>) onBroadcast) {
    return _supabase
        .channel('chat_$matchId')
        .onBroadcast(
          event: 'msg',
          callback: (payload) =>
              onBroadcast(Map<String, dynamic>.from(payload)),
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Notif broadcast ready for match: $matchId');
          } else if (error != null) {
            debugPrint('❌ Notif broadcast error: $error');
          }
        });
  }

  /// Broadcast a typing event on the chat channel (best-effort, no-op if not connected).
  void sendTypingEvent(String matchId) {
    _chatChannels[matchId]
        ?.sendBroadcastMessage(event: 'typing', payload: {});
  }

  /// Broadcast a raw message payload on the chat channel so the partner's
  /// client receives it instantly via WebSocket (used for game challenges).
  void broadcastMessage(String matchId, Map<String, dynamic> payload) {
    _chatChannels[matchId]
        ?.sendBroadcastMessage(event: 'msg', payload: payload);
  }

  /// Subscribe to new messages using Supabase Broadcast (WebSocket, ~50ms latency).
  /// Falls back to postgres_changes as a safety net for messages missed during
  /// a brief disconnect. Also listens for read_receipt broadcast events.
  RealtimeChannel subscribeToMessages(
      String matchId,
      void Function(Map<String, dynamic>) onMessage, {
      void Function()? onTyping,
      void Function()? onReadReceipt,
  }) {
    late RealtimeChannel channel;

    channel = _supabase
        .channel('chat_$matchId')
        // Primary: Broadcast — instant WebSocket delivery (~50ms)
        .onBroadcast(
          event: 'msg',
          callback: (payload) {
            onMessage(Map<String, dynamic>.from(payload));
          },
        )
        // Typing indicator
        .onBroadcast(
          event: 'typing',
          callback: (_) { if (onTyping != null) onTyping(); },
        )
        // Read receipt broadcast — fires when the partner opens/reads the chat.
        // postgres_changes UPDATEs never fire for messages (not in publication),
        // so we use broadcast as the delivery mechanism.
        .onBroadcast(
          event: 'read_receipt',
          callback: (_) { if (onReadReceipt != null) onReadReceipt(); },
        )
        // Fallback: postgres_changes INSERT — catches messages if broadcast missed
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: matchId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe((status, error) {
          // Only store the channel once it's fully connected and ready to broadcast
          if (status == RealtimeSubscribeStatus.subscribed) {
            _chatChannels[matchId] = channel;
            debugPrint('✅ Chat channel ready for: $matchId');
          } else if (error != null) {
            debugPrint('❌ Channel error: $error');
          }
        });

    return channel;
  }

  /// Clean up when leaving a chat screen
  void unsubscribeFromChat(String matchId) {
    _chatChannels.remove(matchId);
  }

  /// Permanently delete a match (and all related messages / game data via CASCADE).
  /// Returns normally on success; throws on error (unauthorized or DB failure).
  Future<void> deleteMatch(String matchId) async {
    await _supabase.rpc('delete_match', params: {'p_match_id': matchId});
    // Clean up any open broadcast channel for this match
    _chatChannels.remove(matchId);
  }

  /// Undo last swipe (if you want this feature)
  Future<bool> undoLastSwipe() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      
      if (currentUserId == null) return false;

      // Get last like or pass
      final lastLike = await _supabase
          .from('likes')
          .select()
          .eq('liker_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final lastPass = await _supabase
          .from('passes')
          .select()
          .eq('passer_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // Determine which was more recent
      if (lastLike != null && lastPass != null) {
        final likeTime = DateTime.parse(lastLike['created_at']);
        final passTime = DateTime.parse(lastPass['created_at']);
        
        if (likeTime.isAfter(passTime)) {
          await _supabase.from('likes').delete().eq('id', lastLike['id']);
        } else {
          await _supabase.from('passes').delete().eq('id', lastPass['id']);
        }
      } else if (lastLike != null) {
        await _supabase.from('likes').delete().eq('id', lastLike['id']);
      } else if (lastPass != null) {
        await _supabase.from('passes').delete().eq('id', lastPass['id']);
      } else {
        return false; // Nothing to undo
      }

      debugPrint('↩️ Undid last swipe');
      return true;
    } catch (e) {
      debugPrint('❌ Error undoing swipe: $e');
      return false;
    }
  }
}