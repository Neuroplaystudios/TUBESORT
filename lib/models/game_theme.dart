import 'package:flutter/material.dart';

class GameTheme {
  final String name;
  final Color backgroundColor;
  final Color tubeColor;
  final Color textColor;
  final List<Color> colorPalette;
  final String backgroundImage;

  GameTheme({
    required this.name,
    required this.backgroundColor,
    required this.tubeColor,
    required this.textColor,
    required this.colorPalette,
    this.backgroundImage = '',
  });
}