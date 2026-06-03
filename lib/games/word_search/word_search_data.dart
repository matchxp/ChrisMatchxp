import 'dart:math';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// CATEGORY MODEL
// ═══════════════════════════════════════════════════════════════

class WSCategory {
  final String key;
  final String label;
  final String emoji;
  final Color accent;
  final Color bg;

  const WSCategory({
    required this.key,
    required this.label,
    required this.emoji,
    required this.accent,
    required this.bg,
  });

  String get findLabel {
    switch (key) {
      case 'animals': return 'AN ANIMAL';
      case 'sport':   return 'A SPORT';
      case 'food':    return 'A FOOD';
      case 'hobbies': return 'A HOBBY';
      default:        return key.toUpperCase();
    }
  }

  String get errorLabel {
    switch (key) {
      case 'animals': return 'an animal';
      case 'sport':   return 'a sport';
      case 'food':    return 'a food';
      case 'hobbies': return 'a hobby';
      default:        return key;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// GRID MODEL
// ═══════════════════════════════════════════════════════════════

class GridResult {
  final List<List<String>> grid;
  final List<List<int>> wc; // word cell coordinates [[row,col], ...]
  const GridResult({required this.grid, required this.wc});
}

// ═══════════════════════════════════════════════════════════════
// GAME STATE (immutable)
// ═══════════════════════════════════════════════════════════════

enum WSStep { welcome, category, enterWord, preview, wait, solve, waitPartner, done }

class WSState {
  final WSStep step;
  final bool showTut;
  final int catIdx;
  final String word;
  final List<List<String>>? grid;
  final List<List<int>> wc;
  final bool submitted;
  final bool solved;
  final bool skipped;
  final List<List<int>> tapCells;

  const WSState({
    this.step = WSStep.welcome,
    this.showTut = false,
    this.catIdx = 0,
    this.word = '',
    this.grid,
    this.wc = const [],
    this.submitted = false,
    this.solved = false,
    this.skipped = false,
    this.tapCells = const [],
  });

  factory WSState.fresh() => const WSState();

  WSState copyWith({
    WSStep?           step,
    bool?             showTut,
    int?              catIdx,
    String?           word,
    List<List<String>>? grid,
    bool              clearGrid = false,
    List<List<int>>?  wc,
    bool?             submitted,
    bool?             solved,
    bool?             skipped,
    List<List<int>>?  tapCells,
  }) {
    return WSState(
      step:      step      ?? this.step,
      showTut:   showTut   ?? this.showTut,
      catIdx:    catIdx    ?? this.catIdx,
      word:      word      ?? this.word,
      grid:      clearGrid  ? null : (grid ?? this.grid),
      wc:        wc        ?? this.wc,
      submitted: submitted  ?? this.submitted,
      solved:    solved    ?? this.solved,
      skipped:   skipped   ?? this.skipped,
      tapCells:  tapCells  ?? this.tapCells,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WORD SEARCH DATA — lists, categories, helpers
// ═══════════════════════════════════════════════════════════════

class WordSearchData {
  WordSearchData._();

  static const List<WSCategory> categories = [
    WSCategory(key: 'animals', label: 'Animals', emoji: '🐾',
        accent: Color(0xFF00E5FF), bg: Color(0x1400E5FF)),
    WSCategory(key: 'sport',   label: 'Sport',   emoji: '⚽',
        accent: Color(0xFF3B82F6), bg: Color(0x143B82F6)),
    WSCategory(key: 'food',    label: 'Food',    emoji: '🍕',
        accent: Color(0xFFFFB800), bg: Color(0x14FFB800)),
    WSCategory(key: 'hobbies', label: 'Hobbies', emoji: '🎨',
        accent: Color(0xFFAB5CF5), bg: Color(0x14AB5CF5)),
  ];

  static const Map<String, List<String>> _lists = {
    'animals': [
      'DOG','CAT','COW','PIG','HEN','RAT','MOUSE','DUCK','GOAT','LAMB','FISH','GOOSE','CHICK',
      'HORSE','SHEEP','RABBIT','PARROT','TURTLE','DONKEY','HAMSTER','GOLDFISH','BUDGIE',
      'EMU','KOALA','DINGO','POSSUM','WOMBAT','WALLABY','ECHIDNA','BILBY','KANGAROO',
      'PLATYPUS','BANDICOOT','KOOKABURRA','CASSOWARY',
      'LION','TIGER','HIPPO','RHINO','ZEBRA','PANDA','CAMEL','LLAMA','MOOSE','BISON',
      'GORILLA','MONKEY','BABOON','BUFFALO','HYENA','CHEETAH','LEOPARD','MEERKAT',
      'WARTHOG','ELEPHANT','GIRAFFE','REINDEER',
      'BEAR','WOLF','DEER','FOX','OTTER','SKUNK','BEAVER','BADGER','RACCOON','SQUIRREL','HEDGEHOG',
      'OWL','CROW','SWAN','WREN','ROBIN','RAVEN','EAGLE','FINCH','STORK','CRANE','HERON',
      'SWIFT','QUAIL','MAGPIE','FALCON','PIGEON','TOUCAN','PELICAN','PEACOCK','OSTRICH',
      'PENGUIN','SPARROW','FLAMINGO','COCKATOO',
      'FROG','SNAKE','GECKO','COBRA','IGUANA','LIZARD','PYTHON','TORTOISE','CROCODILE',
      'CRAB','SEAL','SQUID','SHARK','WHALE','PRAWN','WALRUS','DOLPHIN','LOBSTER',
      'OCTOPUS','STINGRAY','SEAHORSE','JELLYFISH','CLOWNFISH',
      'BEE','ANT','WASP','FLEA','SNAIL','WORM','HORNET','SPIDER','BEETLE','MANTIS',
      'LADYBUG','MOSQUITO','SCORPION','BUTTERFLY','DRAGONFLY',
    ],
    'sport': [
      'SKI','ROW','BOX','RUN','GYM','SWIM','GOLF','SURF','DIVE','YOGA','JUDO','JUMP','KICK',
      'POLO','RUGBY','CHESS','DARTS','TENNIS','SOCCER','HOCKEY','SQUASH','NETBALL','CRICKET',
      'HANDBALL','LACROSSE','BASEBALL','SOFTBALL','FOOTBALL','DODGEBALL','WATERPOLO',
      'VOLLEYBALL','BASKETBALL','BADMINTON','PINGPONG',
      'HIKING','SKIING','ROWING','DIVING','RACING','CAVING','CYCLING','SAILING','FISHING',
      'SURFING','RUNNING','SKATING','CLIMBING','KAYAKING','CANOEING','MARATHON',
      'TRIATHLON','ARCHERY','FENCING','SHOOTING',
      'BOXING','KARATE','WRESTLING','TAEKWONDO','MMA','CROSSFIT','PILATES',
      'RELAY','VAULT','HURDLES','JAVELIN','DISCUS','SHOTPUT','SPRINTING','LONGJUMP',
      'BOWLING','SNOOKER','FRISBEE','PARKOUR','SKYDIVING',
    ],
    'food': [
      'PIE','BUN','ROLL','WRAP','TACO','GYRO','PITA','NAAN','ROTI','CHIP',
      'CHIPS','PIZZA','SUSHI','RAMEN','KEBAB','NACHO','HOTDOG','BURGER','BAGUETTE',
      'BURRITO','DUMPLING','SCHNITZEL','EMPANADA',
      'RICE','BEEF','PORK','LAMB','FISH','TOFU','PASTA','STEAK','CURRY','SATAY','LAKSA',
      'TIKKA','KORMA','CONGEE','WONTON','HOTPOT','RISOTTO','GNOCCHI','PAELLA','CHICKEN',
      'BIRYANI','RENDANG','MOUSSAKA','STIRFRY','NOODLE','SALMON',
      'EGG','RYE','OAT','EGGS','BACON','BREAD','TOAST','WAFFLE','CREPE','BAGEL','SCONE',
      'MUFFIN','GRANOLA','PANCAKE','AVOCADO','VEGEMITE','PORRIDGE','CROISSANT',
      'FIG','JAM','NUT','CAKE','DONUT','LOLLY','COOKIE','BROWNIE','CHURRO','MACARON',
      'PAVLOVA','LAMINGTON','ANZAC','TIRAMISU','CARAMEL','CHEESECAKE','CHOCOLATE',
      'SOUP','SALAD','GRAVY','COFFEE','SLAW','HUMMUS','SMOOTHIE','MILKSHAKE','GUACAMOLE',
    ],
    'hobbies': [
      'DRAW','BLOG','CODE','DRUM',
      'DRAWING','SINGING','DANCING','COOKING','WRITING','POTTERY','ORIGAMI','PAINTING',
      'CARVING','WEAVING','BEADING','BREWING','CANNING','BIRDING','HUNTING','KARAOKE',
      'JUGGLING','KNITTING','QUILTING','SPINNING','DOODLING','PRINTING','FORAGING',
      'VLOGGING','TABLETOP','ROLEPLAY','MIXOLOGY','ROASTING','PICKLING','SCULPTING',
      'GARDENING','ANIMATION','FILMMAKING','PHOTOGRAPHY',
      'DJ','PIANO','GUITAR','VIOLIN','DRUMS',
      'HIKING','SURFING','FISHING','CAMPING','CYCLING','RUNNING','STARGAZING',
      'CODING','GAMING','BLOGGING','PODCASTING','STREAMING','ROBOTICS',
      'SEWING','WOODWORK','JEWELLERY','CANDLES','BAKING','CRAFTING',
      'YOGA','CHESS','READING','PUZZLES','TRIVIA','MEDITATION','JOURNALING',
      'MAGIC','COMEDY','THEATER','TRAVELLING','VOLUNTEERING',
    ],
  };

  // Remove duplicates at runtime (matches JS dedup behaviour)
  static final Map<String, List<String>> wordLists = {
    for (final e in _lists.entries) e.key: e.value.toSet().toList(),
  };

  static bool isValid(String word, String categoryKey) {
    final list = wordLists[categoryKey];
    if (list == null) return false;
    return list.contains(word.toUpperCase().trim());
  }

  // 4×4 snake-path grid generation (matches JS logic exactly)
  static GridResult generateGrid(String word) {
    const gs = 4;
    const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final w = word.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final rng = Random();

    final g = List.generate(gs, (_) =>
        List.generate(gs, (_) => String.fromCharCode(alpha.codeUnitAt(rng.nextInt(26)))));

    const dirs = [
      [0, 1], [1, 0], [0, -1], [-1, 0],
      [1, 1], [1, -1], [-1, 1], [-1, -1],
    ];

    List<List<int>> wc = [];

    for (int att = 0; att < 500; att++) {
      final vis = <String>{};
      final path = <List<int>>[];
      int r = rng.nextInt(gs), c = rng.nextInt(gs);
      path.add([r, c]);
      vis.add('$r,$c');
      bool ok = true;

      for (int i = 1; i < w.length; i++) {
        final shuffled = List.of(dirs)..shuffle(rng);
        bool moved = false;
        for (final d in shuffled) {
          final nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr >= gs || nc < 0 || nc >= gs || vis.contains('$nr,$nc')) continue;
          r = nr; c = nc;
          path.add([r, c]);
          vis.add('$r,$c');
          moved = true;
          break;
        }
        if (!moved) { ok = false; break; }
      }

      if (ok && path.length == w.length) {
        wc = path;
        for (int i = 0; i < w.length; i++) {
          g[wc[i][0]][wc[i][1]] = w[i];
        }
        break;
      }
    }

    return GridResult(grid: g, wc: wc);
  }

  static bool isAdjacent(List<int> a, List<int> b) {
    return (a[0] - b[0]).abs() <= 1 &&
        (a[1] - b[1]).abs() <= 1 &&
        !(a[0] == b[0] && a[1] == b[1]);
  }

  // Shared font size for done-screen word display
  static double doneWordFontSize(String w1, String w2) {
    final maxLen = [w1.length, w2.length].reduce((a, b) => a > b ? a : b);
    if (maxLen <= 3) return 26;
    if (maxLen <= 5) return 22;
    if (maxLen <= 7) return 18;
    if (maxLen <= 9) return 15;
    if (maxLen <= 11) return 12;
    return 10;
  }
}
