# Vampir Köylü veritabanı

Uygulamadaki roller için iki farklı veri tipi tutulur:

- `room_players`: oyuncunun o andaki rolü, hayatta olup olmadığı ve muhtarlığı.
- `room_player_stats`: aynı `room_code` ve aynı oyuncu için tek satırlık, kalıcı rol sayaçları.

Örneğin Esmanur, `VK-000001` odasında önce vampir sonra seri katil olduysa görünümde tek satır vardır: `vampir_count = 1`, `serial_killer_count = 1`, `total_games = 2`.

## Mevcut proje için geçiş

Mevcut veritabanı kontrol edildi: `players` tablosu eski yapıdadır (`room_code`, `player_name`, `role` vb.). Bu nedenle MySQL Workbench'te önce veritabanının yedeğini al, ardından yalnızca bir defa [vampir_koylu_migration_from_legacy.sql](vampir_koylu_migration_from_legacy.sql) dosyasının tamamını çalıştır.

Bu betik eski tabloyu silmez; `players_legacy_20260805` adıyla saklar ve eski rol satırlarını yeni sayaçlara toplar. Başarılı sonuçtan sonra sunucuyu yeniden başlat.

İstatistikleri görmek için:

```sql
SELECT *
FROM v_room_player_statistics
ORDER BY room_code, player_name;
```

[vampir_koylu_schema.sql](vampir_koylu_schema.sql) sadece yeni, boş bir veritabanı kurulumu içindir. Mevcut veritabanında bunu tek başına çalıştırmak eski `players` tablosunu dönüştürmez.
