-- Bu dosya yalnızca ekran görüntüsündeki ESKİ `players` yapısı için hazırlanmıştır:
-- id, room_code, player_name, role, is_host, is_alive, joined_at.
-- Çalıştırmadan önce veritabanını yedekle. Bu betik eski tabloyu silmez;
-- `players_legacy_20260805` adıyla saklar.

USE vampir_koylu_game;

-- Aynı isimde bir yedek tablo varsa bu betiği tekrar çalıştırma.
RENAME TABLE players TO players_legacy_20260805;

-- Yeni kalıcı oyuncu profilleri.
CREATE TABLE players (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_players_player_name (player_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Anlık lobi/oyun durumu; ilk yeni oyunda uygulama tarafından doldurulur.
CREATE TABLE room_players (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE room_player_stats (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE OR REPLACE VIEW v_room_player_statistics AS
SELECT
    s.id, s.room_code, p.player_name,
    s.koylu_count, s.vampir_count, s.doktor_count, s.serial_killer_count,
    s.total_games, s.first_played_at, s.last_played_at
FROM room_player_stats AS s
INNER JOIN players AS p ON p.id = s.player_id;

-- Eski kayıtların oyuncu profillerini oluşturur.
INSERT INTO players (player_name)
SELECT DISTINCT TRIM(player_name)
FROM players_legacy_20260805
WHERE player_name IS NOT NULL AND TRIM(player_name) <> '';

-- Eski bir kayıt için rooms satırı eksikse dış anahtar hatası oluşmasın.
INSERT INTO rooms (room_code, game_status)
SELECT DISTINCT room_code, 'finished'
FROM players_legacy_20260805
WHERE room_code IS NOT NULL AND TRIM(room_code) <> ''
ON DUPLICATE KEY UPDATE room_code = VALUES(room_code);

-- Her eski oyun satırını role göre toplayarak tek oda-oyuncu satırına indirger.
INSERT INTO room_player_stats
    (room_code, player_id, koylu_count, vampir_count, doktor_count, serial_killer_count,
     total_games, first_played_at, last_played_at)
SELECT
    l.room_code,
    p.id,
    SUM(CASE WHEN LOWER(l.role) LIKE '%vampir%' THEN 0
             WHEN LOWER(l.role) LIKE '%doktor%' THEN 0
             WHEN LOWER(l.role) LIKE '%seri%' OR LOWER(l.role) LIKE '%katil%' THEN 0
             ELSE 1 END),
    SUM(CASE WHEN LOWER(l.role) LIKE '%vampir%' THEN 1 ELSE 0 END),
    SUM(CASE WHEN LOWER(l.role) LIKE '%doktor%' THEN 1 ELSE 0 END),
    SUM(CASE WHEN LOWER(l.role) LIKE '%seri%' OR LOWER(l.role) LIKE '%katil%' THEN 1 ELSE 0 END),
    COUNT(*),
    MIN(l.joined_at),
    MAX(l.joined_at)
FROM players_legacy_20260805 AS l
INNER JOIN players AS p
  ON p.player_name COLLATE utf8mb4_0900_ai_ci = TRIM(l.player_name)
WHERE l.room_code IS NOT NULL AND l.player_name IS NOT NULL AND TRIM(l.player_name) <> ''
GROUP BY l.room_code, p.id;
