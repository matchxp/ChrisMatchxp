// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Models
// ─────────────────────────────────────────────────────────────

enum RPSMove { rock, paper, scissors }

enum RPSResult { win, lose, draw }

extension RPSMoveExt on RPSMove {
  String get emoji {
    switch (this) {
      case RPSMove.rock:     return '✊';
      case RPSMove.paper:    return '🖐️';
      case RPSMove.scissors: return '✌️';
    }
  }

  String get label {
    switch (this) {
      case RPSMove.rock:     return 'Rock';
      case RPSMove.paper:    return 'Paper';
      case RPSMove.scissors: return 'Scissors';
    }
  }

  String get labelUpper => label.toUpperCase();

  RPSMove get beats {
    switch (this) {
      case RPSMove.rock:     return RPSMove.scissors;
      case RPSMove.paper:    return RPSMove.rock;
      case RPSMove.scissors: return RPSMove.paper;
    }
  }

  String get beatsLabel {
    switch (this) {
      case RPSMove.rock:     return 'ROCK BEATS SCISSORS';
      case RPSMove.paper:    return 'PAPER BEATS ROCK';
      case RPSMove.scissors: return 'SCISSORS BEATS PAPER';
    }
  }
}

RPSResult computeResult(RPSMove mine, RPSMove theirs) {
  if (mine == theirs) return RPSResult.draw;
  return mine.beats == theirs ? RPSResult.win : RPSResult.lose;
}
