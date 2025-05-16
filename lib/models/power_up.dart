import 'package:flutter/material.dart';

enum PowerUpType { addTube, rewind, hint }

class PowerUp {
  final PowerUpType type;
  int remainingUses;
  final IconData icon;
  final Color color;

  PowerUp({
    required this.type,
    required this.remainingUses,
    required this.icon,
    required this.color,
  });
}