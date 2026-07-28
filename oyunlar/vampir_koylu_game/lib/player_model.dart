import 'package:flutter/material.dart'; // Düzeltilen kısım
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
    this.posX,
    this.posY,
  });

  // Rol atanırken nesneyi güvenle kopyalayıp güncelleyen metot
  PlayerModel copyWith({
    String? id,
    String? name,
    Color? avatarColor,
    Gender? gender,
    String? role,
    bool? isVampire,
    bool? isAlive,
    double? posX,
    double? posY,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarColor: avatarColor ?? this.avatarColor,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      isVampire: isVampire ?? this.isVampire,
      isAlive: isAlive ?? this.isAlive,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
    );
  }
}

// Lobide seçtiğin rol sayılarını taşıyan yardımcı sınıf
class LobbyRoleConfig {
  final int vampireCount;
  final int doctorCount;
  final int serialKillerCount;

  LobbyRoleConfig({
    required this.vampireCount,
    required this.doctorCount,
    this.serialKillerCount = 0,
  });
}
