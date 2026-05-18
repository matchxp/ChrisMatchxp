// ============================================================
//  emoji_charades_data.dart
//  Categories, phrases and animation data for Emoji Charades.
//  lib/games/emoji_charades/
// ============================================================

import 'package:flutter/material.dart';

class EcCategory {
  final String key;
  final String icon;
  final String label;
  final Color neon;
  final Color bg;
  final Color dark;
  const EcCategory({
    required this.key,
    required this.icon,
    required this.label,
    required this.neon,
    required this.bg,
    required this.dark,
  });
}

const kEcCategories = [
  EcCategory(
    key: 'movies',
    icon: '🎬',
    label: 'Movies',
    neon: Color(0xFF00E5FF),
    bg: Color(0xFF003344),
    dark: Color(0xFF00111E),
  ),
  EcCategory(
    key: 'activities',
    icon: '🏃',
    label: 'Activities',
    neon: Color(0xFF39FF14),
    bg: Color(0xFF0A2600),
    dark: Color(0xFF060F00),
  ),
];

const kEcPhrases = {
  'movies': [
    'The Lion King',
    'Frozen',
    'Finding Nemo',
    'Toy Story',
    'Titanic',
    'Jurassic Park',
    'Spider-Man',
    'Beauty and the Beast',
    'Kung Fu Panda',
    'Pirates of the Caribbean',
    'Moana',
    'Cars',
    'The Little Mermaid',
    'Cinderella',
    'Aladdin',
  ],
  'activities': [
    'Swimming',
    'Cooking',
    'Hiking',
    'Gaming',
    'Dancing',
    'Watching Movies',
    'Road Trip',
    'Camping',
    'Shopping',
    'Photography',
    'Surfing',
    'Baking',
    'Travelling',
    'Gym Workout',
    'Rock Climbing',
  ],
};

// 3-emoji sets rotating on the welcome screen (every 3.8 s)
const kIntroSets = [
  ['🦁', '🕷️', '✈️'],
  ['👑', '🐠', '💃'],
  ['🚀', '🐼', '🏄'],
  ['🌹', '🏴‍☠️', '⛺'],
  ['🧜', '🎮', '🔥'],
  ['🥋', '🏎️', '🌊'],
  ['👠', '🌺', '🧗'],
  ['🪔', '⚓', '🏋️'],
  ['🦕', '🎬', '🌴'],
  ['❄️', '🐯', '🍳'],
  ['😂', '🤩', '😎'],
  ['😍', '🥳', '😜'],
  ['🤪', '😏', '🥰'],
];

// Floating particles rising from bottom toward title
const kParticlePool = [
  // Animals & nature
  '🦁', '👑', '🕷️', '🐠', '🐼', '🦋', '🦊', '🐺', '🦄', '🐉', '🦅', '🐬', '🦒',
  '🐸', '🦩',
  '🌹', '🌺', '🌸', '🌻', '🍀', '🌴', '🌵', '🎋', '🍄', '🌊', '❄️', '🔥', '💧',
  '🌙', '⭐',
  // Adventure & travel
  '🚀', '✈️', '🏄', '🧗', '🏎️', '⛺', '🏴‍☠️', '🪔', '⚓', '🗺️', '🏔️', '🎿',
  '🛸', '🚁', '🎠',
  // Culture & fun
  '🎬', '🎮', '🥋', '👠', '💃', '🎭', '🎪', '🎨', '🎵', '🎸', '🎺', '🎲', '🃏',
  '🎯', '🏆',
  // Food & drink
  '🍕', '🍣', '🍦', '🌮', '🍜', '🧋', '🍩', '🎂', '🍓', '🍇', '🥑', '🧃', '🍫',
  '🥐', '🍿',
  // Faces & hearts
  '😂', '🤩', '😎', '😍', '🥳', '😜', '🤪', '😏', '🥰', '😘', '🫶', '💫', '🤯',
  '🥹', '😈',
  '❤️', '💜', '💙', '🧡', '💛', '🖤', '🤍', '💥', '✨', '🌈', '🎉', '🎊', '💎',
  '🔮', '🪄',
];
