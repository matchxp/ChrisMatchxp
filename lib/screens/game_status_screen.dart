// lib/screens/game_status_screen.dart
//
// A dedicated page showing every match's current game phase, grouped into
// UNLOCKED, IN PROGRESS, and LOCKED sections.  Accessible via the 🎮 button
// on the Chats screen.

import 'package:flutter/material.dart';
import '../games/word_search/word_search_models.dart';
import 'chat_conversation_screen.dart';
import '../games/game_hub_screen.dart';

class GameStatusScreen extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final String currentUserId;
  final void Function(Map<String, dynamic>) onOpenMatch;

  const GameStatusScreen({
    super.key,
    required this.matches,
    required this.currentUserId,
    required this.onOpenMatch,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _section(Map<String, dynamic> m) {
    final phase = m['game_phase'] as MatchGamePhase?;
    if (phase == MatchGamePhase.bothSolved) return 'unlocked';
    if (phase == null || phase == MatchGamePhase.setup) return 'locked';
    return 'inProgress';
  }

  String? _badgeLabel(Map<String, dynamic> m) {
    final phase = m['game_phase'] as MatchGamePhase?;
    switch (phase) {
      case MatchGamePhase.setup:                return 'LOCKED';
      case MatchGamePhase.waitingPartnerSetup:
      case MatchGamePhase.waitingPartnerSolve:  return 'WAITING';
      case MatchGamePhase.solving:              return 'SOLVING';
      case MatchGamePhase.bothSolved:           return null;
      case null:                                return 'LOCKED';
    }
  }

  Color _badgeColor(String label) {
    switch (label) {
      case 'SOLVING': return const Color(0xFFF59E0B);
      case 'WAITING': return const Color(0xFF6C3FE8);
      default:        return const Color(0xFF6B7280);
    }
  }

  String _phaseDescription(Map<String, dynamic> m, String name) {
    final phase = m['game_phase'] as MatchGamePhase?;
    switch (phase) {
      case MatchGamePhase.setup:
        return 'Create your puzzle — $name is waiting';
      case MatchGamePhase.waitingPartnerSetup:
        return 'Waiting for $name to create their puzzle 🧩';
      case MatchGamePhase.solving:
        return '$name made a puzzle for you — go solve it! 🔐';
      case MatchGamePhase.waitingPartnerSolve:
        return 'You solved it! ✅  Waiting for $name to solve yours…';
      case MatchGamePhase.bothSolved:
        return 'Chat unlocked! Start messaging!';
      case null:
        return 'No game started yet — challenge $name!';
    }
  }

  String _profileName(Map<String, dynamic> profile) =>
      profile['first_name'] as String? ?? 'Match';

  String _profilePhoto(Map<String, dynamic> profile) {
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) return photos[0] as String;
    return '';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unlocked   = matches.where((m) => _section(m) == 'unlocked').toList();
    final inProgress = matches.where((m) => _section(m) == 'inProgress').toList();
    final locked     = matches.where((m) => _section(m) == 'locked').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            // ── Summary chips ───────────────────────────────────────────────
            _buildSummaryRow(
              unlocked: unlocked.length,
              inProgress: inProgress.length,
              locked: locked.length,
            ),
            const SizedBox(height: 8),
            // ── Sections ────────────────────────────────────────────────────
            Expanded(
              child: matches.isEmpty
                  ? _buildEmpty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      children: [
                        if (inProgress.isNotEmpty) ...[
                          _SectionHeader(
                            icon: Icons.sports_esports_rounded,
                            label: 'IN PROGRESS',
                            color: const Color(0xFFF59E0B),
                            subtitle: 'Games you need to action',
                          ),
                          const SizedBox(height: 6),
                          ...inProgress.map((m) => _MatchCard(
                                match: m,
                                name: _profileName(
                                    m['profile'] as Map<String, dynamic>),
                                photo: _profilePhoto(
                                    m['profile'] as Map<String, dynamic>),
                                badgeLabel: _badgeLabel(m),
                                badgeColor: _badgeLabel(m) != null
                                    ? _badgeColor(_badgeLabel(m)!)
                                    : null,
                                description: _phaseDescription(
                                    m,
                                    _profileName(m['profile']
                                        as Map<String, dynamic>)),
                                phase: m['game_phase'] as MatchGamePhase?,
                                currentUserId: currentUserId,
                                onOpenChat: () {
                                  Navigator.pop(context);
                                  onOpenMatch(m);
                                },
                                onOpenGame: () {
                                  final profile = m['profile']
                                      as Map<String, dynamic>;
                                  final partnerUserId =
                                      profile['id'] as String? ?? '';
                                  final partnerName = _profileName(profile);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameHubScreen(
                                        matchId:
                                            m['match_id'] as String,
                                        currentUserId: currentUserId,
                                        partnerUserId: partnerUserId,
                                        partnerName: partnerName,
                                        onChatUnlocked: () {},
                                      ),
                                    ),
                                  );
                                },
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (unlocked.isNotEmpty) ...[
                          _SectionHeader(
                            icon: Icons.chat_bubble_rounded,
                            label: 'UNLOCKED',
                            color: const Color(0xFF22C55E),
                            subtitle: 'Chat is open!',
                          ),
                          const SizedBox(height: 6),
                          ...unlocked.map((m) => _MatchCard(
                                match: m,
                                name: _profileName(
                                    m['profile'] as Map<String, dynamic>),
                                photo: _profilePhoto(
                                    m['profile'] as Map<String, dynamic>),
                                badgeLabel: null,
                                badgeColor: null,
                                description: _phaseDescription(
                                    m,
                                    _profileName(m['profile']
                                        as Map<String, dynamic>)),
                                phase: m['game_phase'] as MatchGamePhase?,
                                currentUserId: currentUserId,
                                onOpenChat: () {
                                  Navigator.pop(context);
                                  onOpenMatch(m);
                                },
                                onOpenGame: null,
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (locked.isNotEmpty) ...[
                          _SectionHeader(
                            icon: Icons.lock_rounded,
                            label: 'LOCKED',
                            color: const Color(0xFF6B7280),
                            subtitle: 'No game started yet',
                          ),
                          const SizedBox(height: 6),
                          ...locked.map((m) => _MatchCard(
                                match: m,
                                name: _profileName(
                                    m['profile'] as Map<String, dynamic>),
                                photo: _profilePhoto(
                                    m['profile'] as Map<String, dynamic>),
                                badgeLabel: 'LOCKED',
                                badgeColor: const Color(0xFF6B7280),
                                description: _phaseDescription(
                                    m,
                                    _profileName(m['profile']
                                        as Map<String, dynamic>)),
                                phase: m['game_phase'] as MatchGamePhase?,
                                currentUserId: currentUserId,
                                onOpenChat: () {
                                  Navigator.pop(context);
                                  onOpenMatch(m);
                                },
                                onOpenGame: () {
                                  final profile = m['profile']
                                      as Map<String, dynamic>;
                                  final partnerUserId =
                                      profile['id'] as String? ?? '';
                                  final partnerName = _profileName(profile);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameHubScreen(
                                        matchId:
                                            m['match_id'] as String,
                                        currentUserId: currentUserId,
                                        partnerUserId: partnerUserId,
                                        partnerName: partnerName,
                                        onChatUnlocked: () {},
                                      ),
                                    ),
                                  );
                                },
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Track your match progress',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_esports_rounded,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required int unlocked,
    required int inProgress,
    required int locked,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SummaryChip(
              label: 'Unlocked', count: unlocked,
              color: const Color(0xFF22C55E)),
          const SizedBox(width: 8),
          _SummaryChip(
              label: 'In Progress', count: inProgress,
              color: const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _SummaryChip(
              label: 'Locked', count: locked,
              color: const Color(0xFF6B7280)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_esports_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(
            'No matches yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start swiping to find someone to play with!',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary chip ───────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '—  $subtitle',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Match card ─────────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final String name;
  final String photo;
  final String? badgeLabel;
  final Color? badgeColor;
  final String description;
  final MatchGamePhase? phase;
  final String currentUserId;
  final VoidCallback onOpenChat;
  final VoidCallback? onOpenGame;

  const _MatchCard({
    required this.match,
    required this.name,
    required this.photo,
    required this.badgeLabel,
    required this.badgeColor,
    required this.description,
    required this.phase,
    required this.currentUserId,
    required this.onOpenChat,
    required this.onOpenGame,
  });

  // Label + icon for the action button
  ({String label, IconData icon, List<Color> gradient})? get _actionButton {
    switch (phase) {
      case MatchGamePhase.setup:
        return (
          label: 'Create Puzzle',
          icon: Icons.extension_rounded,
          gradient: [const Color(0xFF6C3FE8), const Color(0xFF9D50BB)],
        );
      case MatchGamePhase.solving:
        return (
          label: 'Solve Now',
          icon: Icons.search_rounded,
          gradient: [const Color(0xFFD97706), const Color(0xFFF59E0B)],
        );
      case MatchGamePhase.bothSolved:
        return (
          label: 'Open Chat',
          icon: Icons.chat_bubble_rounded,
          gradient: [const Color(0xFF059669), const Color(0xFF22C55E)],
        );
      case MatchGamePhase.waitingPartnerSetup:
      case MatchGamePhase.waitingPartnerSolve:
      case null:
        return null; // no action — just waiting
    }
  }

  @override
  Widget build(BuildContext context) {
    final btn = _actionButton;

    return GestureDetector(
      onTap: onOpenChat,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: avatar + name + badge ──────────────────────────
              Row(
                children: [
                  // Avatar
                  ClipOval(
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: photo.isNotEmpty
                          ? Image.network(photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initial())
                          : _initial(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge pill
                  if (badgeLabel != null && badgeColor != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor!.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: badgeColor!.withValues(alpha: 0.4),
                            width: 0.8),
                      ),
                      child: Text(
                        badgeLabel!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // ── Action button (only when there's something to do) ────────
              if (btn != null && onOpenGame != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: phase == MatchGamePhase.bothSolved
                      ? onOpenChat
                      : onOpenGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: btn.gradient),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: btn.gradient.first.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(btn.icon, color: Colors.white, size: 16),
                        const SizedBox(width: 7),
                        Text(
                          btn.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _initial() => Container(
        color: const Color(0xFF2A2A2A),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18),
          ),
        ),
      );
}
