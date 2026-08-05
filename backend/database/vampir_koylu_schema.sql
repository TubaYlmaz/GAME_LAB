-- Yeni/boş kurulum için şema.
-- Mevcut ekran görüntüsündeki eski `players` tablon varsa bu dosya yerine
-- `vampir_koylu_migration_from_legacy.sql` dosyasını BİR KEZ çalıştır.

CREATE DATABASE IF NOT EXISTS vampir_koylu_game
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_turkish_ci;
USE vampir_koylu_game;

CREATE TABLE IF NOT EXISTS rooms (
    room_code VARCHAR(10) NOT NULL,
    game_status ENUM('waiting', 'playing', 'finished') NOT NULL DEFAULT 'waiting',
    game_mode VARCHAR(50) NOT NULL DEFAULT 'Klasik',
    winner_team VARCHAR(50) DEFAULT NULL,
    vampire_count TINYINT UNSIGNED NOT NULL DEFAULT 1,
    doctor_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    serial_killer_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (room_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_turkish_ci;

-- Oyuncunun global kimliği. Aynı isim, uygulamadaki aynı kişiyi temsil eder.
CREATE TABLE IF NOT EXISTS players (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_players_player_name (player_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_turkish_ci;

-- O anki oyun/lobi durumu. Her oda-oyuncu çifti için yalnızca tek kayıt vardır.
CREATE TABLE IF NOT EXISTS room_players (
    room_code VARCHAR(10) NOT NULL,
    player_id BIGINT UNSIGNED NOT NULL,
    current_role VARCHAR(50) NOT NULL DEFAULT 'Köylü 🧑‍🌾',
    is_host BOOLEAN NOT NULL DEFAULT FALSE,
    is_alive BOOLEAN NOT NULL DEFAULT TRUE,
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (room_code, player_id),
    CONSTRAINT fk_room_players_room
      FOREIGN KEY (room_code) REFERENCES rooms(room_code) ON DELETE CASCADE,
    CONSTRAINT fk_room_players_player
      FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_turkish_ci;

-- İstenen kalıcı özet: aynı oda kodu + aynı kişi = tek satır.
CREATE TABLE IF NOT EXISTS room_player_stats (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    room_code VARCHAR(10) NOT NULL,
    player_id BIGINT UNSIGNED NOT NULL,
    koylu_count INT UNSIGNED NOT NULL DEFAULT 0,
    vampir_count INT UNSIGNED NOT NULL DEFAULT 0,
    doktor_count INT UNSIGNED NOT NULL DEFAULT 0,
    serial_killer_count INT UNSIGNED NOT NULL DEFAULT 0,
    total_games INT UNSIGNED NOT NULL DEFAULT 0,
    first_played_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_played_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_room_player_stats (room_code, player_id),
    KEY idx_room_player_stats_player (player_id),
    CONSTRAINT fk_room_player_stats_room
      FOREIGN KEY (room_code) REFERENCES rooms(room_code) ON DELETE CASCADE,
    CONSTRAINT fk_room_player_stats_player
      FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_turkish_ci;

-- Workbench'te okunması kolay, doğrudan istediğin görünüm.
CREATE OR REPLACE VIEW v_room_player_statistics AS
SELECT
    s.id,
    s.room_code,
    p.player_name,
    s.koylu_count,
    s.vampir_count,
    s.doktor_count,
    s.serial_killer_count,
    s.total_games,
    s.first_played_at,
    s.last_played_at
FROM room_player_stats AS s
INNER JOIN players AS p ON p.id = s.player_id;
