import 'package:flutter/material.dart';

enum GamePhase { night, dayDiscussion, voting }

class PlayerModel {
  final String id;
  final String name;
  final Color avatarColor;
  bool isAlive;
  bool isVampire;

  double? posX;
  double? posY;

  PlayerModel({
    required this.id,
    required this.name,
    required this.avatarColor,
    this.isAlive = true,
    this.isVampire = false,
  });
}