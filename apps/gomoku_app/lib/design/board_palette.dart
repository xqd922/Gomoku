import 'package:flutter/material.dart';
import 'package:gomoku_core/gomoku_core.dart';

/// Physical board colors. The board is an object, not chrome: these values are
/// constant across themes, brand changes, and dynamic color. Documented in the
/// root DESIGN.md; the board painter, stone discs, and record previews all
/// read from here so a stone looks identical everywhere it appears.
abstract final class BoardPalette {
  static const canvasLight = Color(0xfff4f0e8);
  static const canvasDark = Color(0xff27252c);
  static const gridLight = Color(0xff979087);
  static const gridDark = Color(0xff817889);

  static const stoneBlack = Color(0xff302d35);
  static const stoneBlackBorder = Color(0xff4c4752);
  static const stoneWhite = Color(0xfffffdfa);
  static const stoneWhiteBorder = Color(0xffbfb8ba);

  static Color canvas(Brightness brightness) =>
      brightness == Brightness.dark ? canvasDark : canvasLight;
  static Color grid(Brightness brightness) =>
      brightness == Brightness.dark ? gridDark : gridLight;

  static Color stoneFill(Stone stone) =>
      stone == Stone.black ? stoneBlack : stoneWhite;
  static Color stoneBorder(Stone stone) =>
      stone == Stone.black ? stoneBlackBorder : stoneWhiteBorder;
}
