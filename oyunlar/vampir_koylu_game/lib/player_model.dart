import 'package:flutter/material.dart';
import 'screens/entry_screen.dart'; // Gender enum'ı buradan geliyor
import 'screens/game_screen.dart';

enum GamePhase { night, dayDiscussion, voting }

class PlayerModel {
  final String id;
  final String name;
  final Color avatarColor;
  final Gender gender;
  final String role;
  final bool isVampire;
  bool isAlive;

  double? posX;
  double? posY;

  PlayerModel({
    required this.id,
    required this.name,
    required this.avatarColor,
    required this.gender,
    required this.role,
    this.isVampire = false,
    this.isAlive = true,
  });
}
