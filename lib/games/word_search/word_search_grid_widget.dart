// lib/games/word_search/word_search_grid_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'word_search_models.dart';

typedef OnSelectionComplete = void Function(List<GridPosition> selected);

class WordSearchGridWidget extends StatefulWidget {
  final List<List<String>> grid;
  final String targetWord;
  final bool isInteractive;
  final OnSelectionComplete? onCorrect;
  final VoidCallback? onWrong;

  const WordSearchGridWidget({
    super.key,
    required this.grid,
    required this.targetWord,
    this.isInteractive = true,
    this.onCorrect,
    this.onWrong,
  });

  @override
  State<WordSearchGridWidget> createState() => _WordSearchGridWidgetState();
}

class _WordSearchGridWidgetState extends State<WordSearchGridWidget> {
  final List<GridPosition> _selected = [];
  Set<GridPosition> _correctCells   = {};
  bool _solved     = false;
  bool _wrongFlash = false;

  static const _cBg      = Color(0xFF0A0A0A);
  static const _cCell    = Color(0xFF1A1A1A);
  static const _cBorder  = Color(0x406C3FE8);
  static const _cPurple  = Color(0xFF6C3FE8);
  static const _cPurpleL = Color(0xFFBB8DFF);
  static const _cGreen   = Color(0xFF4ADE80);
  static const _cRed     = Color(0xFFF87171);

  bool _isSel(int r, int c) => _selected.contains(GridPosition(r, c));
  bool _isOk (int r, int c) => _correctCells.contains(GridPosition(r, c));
  String get _built => _selected.map((p) => widget.grid[p.row][p.col]).join();

  void _onTap(int r, int c) {
    if (!widget.isInteractive || _solved || _wrongFlash) return;
    final pos = GridPosition(r, c);
    if (_isSel(r, c)) {
      final idx = _selected.indexOf(pos);
      setState(() => _selected.removeRange(idx, _selected.length));
      return;
    }
    if (_selected.isNotEmpty && !_selected.last.isAdjacentTo(pos)) {
      _doWrong(); return;
    }
    setState(() => _selected.add(pos));
    final built  = _built;
    final target = widget.targetWord.toUpperCase();
    if (built == target)             _doCorrect();
    else if (built.length >= target.length) _doWrong();
  }

  void _doCorrect() {
    HapticFeedback.mediumImpact();
    setState(() { _correctCells = Set.from(_selected); _solved = true; });
    widget.onCorrect?.call(List.from(_selected));
  }

  void _doWrong() {
    HapticFeedback.lightImpact();
    setState(() { _wrongFlash = true; _selected.clear(); });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _wrongFlash = false);
    });
    widget.onWrong?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _buildGrid(),
      const SizedBox(height: 12),
      _buildProgress(),
    ]);
  }

  Widget _buildGrid() {
    Color bc = _cBorder; Color gc = _cPurple; double bw = 1.5;
    if (_solved)     { bc = _cGreen; gc = _cGreen; bw = 2.5; }
    else if (_wrongFlash) { bc = _cRed;   gc = _cRed;   bw = 2.5; }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _cBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bc, width: bw),
        boxShadow: [BoxShadow(
          color: gc.withOpacity(_solved || _wrongFlash ? 0.35 : 0.12),
          blurRadius: _solved || _wrongFlash ? 24 : 12, spreadRadius: 1)],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (r) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (c) => _buildCell(r, c)),
        )),
      ),
    );
  }

  Widget _buildCell(int r, int c) {
    final isSel = _isSel(r, c); final isOk = _isOk(r, c);
    Color bg = _cCell, brd = _cBorder, txt = Colors.white; double bw = 1.5;
    if (isOk)         { bg = _cGreen.withOpacity(0.18); brd = _cGreen;   txt = _cGreen;   bw = 2; }
    else if (isSel)   { bg = _cPurple.withOpacity(0.22); brd = _cPurpleL; txt = _cPurpleL; bw = 2; }
    else if (_wrongFlash) { bg = _cRed.withOpacity(0.07); brd = _cRed.withOpacity(0.25); txt = _cRed.withOpacity(0.5); }

    return GestureDetector(
      onTap: widget.isInteractive ? () => _onTap(r, c) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 62, height: 62,
        margin: const EdgeInsets.all(3),
        transform: isSel ? (Matrix4.identity()..scale(1.06)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: brd, width: bw),
        ),
        child: Center(child: Text(widget.grid[r][c], style: TextStyle(
          color: txt, fontSize: isSel ? 21 : 19,
          fontWeight: FontWeight.w700, fontFamily: 'Fredoka One'))),
      ),
    );
  }

  Widget _buildProgress() {
    final target = widget.targetWord.toUpperCase();
    final built  = _built;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(target.length, (i) {
        final has = i < built.length;
        final col = _solved ? _cGreen : has ? _cPurpleL : _cBorder;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28, height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: col, width: 2.5))),
          child: Center(child: Text(
            has ? built[i] : '_',
            style: TextStyle(color: col, fontSize: 17,
              fontWeight: FontWeight.w700, fontFamily: 'Fredoka One'))),
        );
      }),
    );
  }
}
