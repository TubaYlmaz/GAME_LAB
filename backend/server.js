const express = require('express');
const http = require('http');
const Redis = require('ioredis');
const fs = require('fs');
const path = require('path'); // Dosya yolları için güvenli modül
const { Server } = require('socket.io'); // Canlı bağlantılar için Socket.io
const cors = require('cors'); // İşte o meşhur paketimiz burada!
const db = require('./db'); // Veri tabanı bağlantımız
const app = express();
app.use(cors()); // Flutter Web ve Mobil ağ istekleri için CORS aktif
app.use(express.json()); // HTTP POST isteklerindeki JSON gövdelerini okuyabilmek için

// =========================================================================
// 🎯 ANA BACKEND - DİNAMİK OTOMATİK OYUN TARAYICI (ORTAK SUNUCU)
// =========================================================================

// __dirname şu an: OyunLauncherProjesi/backend[cite: 2]
const anaProjeDizini = path.resolve(__dirname, '..'); // Bir üst klasör (OyunLauncherProjesi)[cite: 2]
const oyunlarDizini = path.resolve(anaProjeDizini, 'oyunlar'); // .../OyunLauncherProjesi/oyunlar[cite: 2]

// 1. Kullanıcı 'localhost:3000' yazdığında ana launcher sayfasını gönderiyoruz:[cite: 2]
app.get('/', (req, res) => {
    res.sendFile(path.join(anaProjeDizini, 'oyun_launcher.html'));
});

// 2. 'oyunlar' klasöründeki tüm oyunları tarayıp otomatik olarak sunucuya bağlıyoruz:[cite: 2]
if (fs.existsSync(oyunlarDizini)) {
    const oyunKlasorleri = fs.readdirSync(oyunlarDizini);

    oyunKlasorleri.forEach(oyunAdı => {
        const oyunBuildYolu = path.join(oyunlarDizini, oyunAdı, 'build', 'web');

        // Eğer oyun klasörünün içinde 'build/web' derleme çıktısı varsa otomatik aktif et kanka:[cite: 2]
        if (fs.existsSync(oyunBuildYolu)) {

            // Oyuna ait index.html yönlendirmesi:[cite: 2]
            app.get(`/oyunlar/${oyunAdı}/web/index.html`, (req, res) => {
                res.sendFile(path.join(oyunBuildYolu, 'index.html'));
            });

            // Oyuna ait statik dosyaların (js, assets vb.) servisi:[cite: 2]
            app.use(`/oyunlar/${oyunAdı}/web`, express.static(oyunBuildYolu));

            console.log(`🎮 [OTOMATİK AKTİF] "${oyunAdı}" oyunu başarıyla sunucuya bağlandı!`);
        }
    });
} else {
    console.log("⚠️ Uyarı: 'oyunlar' klasörü bulunamadı!");
}

const server = http.createServer(app);

// WebSocket için CORS ayarları[cite: 2]
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const redisClient = new Redis();

// 📁 dictionary.json dosyasını oyunun kendi klasöründen dinamik olarak okuyoruz kanka 🔥[cite: 2]
const dictionaryPath = path.resolve(__dirname, '../oyunlar/impostor_game/dictionary.json');
let dictionary = {};

function kelimeleriYukle() {
    try {
        if (fs.existsSync(dictionaryPath)) {
            const rawData = fs.readFileSync(dictionaryPath, 'utf8');
            dictionary = JSON.parse(rawData);
            console.log("2. Adım: dictionary.json başarıyla hafızaya alındı! Kategoriler:", Object.keys(dictionary).join(', '));
        } else {
            console.log("⚠️ Uyarı: dictionary.json dosyası bir üst klasörde bulunamadı!");
        }
    } catch (err) {
        console.error("Sözlük JSON dosyası okunurken hata oluştu kanka:", err);
    }
}

redisClient.on('connect', () => {
    console.log("1. Adım: Redis'e başarıyla bağlanıldı!");
    kelimeleriYukle();
});

redisClient.on('error', (err) => {
    console.log('Redis Hatası:', err);
});

// ==========================================
// 🚀 OYUN LOGIC VE WEBSOCKET BAĞLANTILARI
// ==========================================

io.on('connection', (socket) => {
    console.log(`🔌 Bir kullanıcı bağlandı: ${socket.id}`);

    // ➡️ 1. HOST ODA OLUŞTURDUĞUNDA[cite: 2]
    socket.on('create_room', async (data) => {
        // Flutter uygulamasından "gameMode" ve "impostorCount" değerlerinin de geldiğini varsayıyoruz. 
        // Eğer Flutter'dan henüz gelmiyorsa default olarak 'Klasik' ve 1 değerlerini yazdırıyoruz kanka.
        const { roomCode, hostName, gameMode = 'Klasik', impostorCount = 1 } = data;

        const roomData = {
            host: hostName,
            status: 'waiting',
            players: JSON.stringify([hostName])
        };

        await redisClient.hmset(`room:${roomCode}`, roomData);
        await redisClient.expire(`room:${roomCode}`, 7200);

        // 🟢 [MYSQL'E YAZMA]: Odayı ve odayı kuran Host'u ilk kez MySQL'e kaydediyoruz.
        try {
            await db.query(
                'INSERT INTO rooms (room_code, game_mode, impostor_count) VALUES (?, ?, ?)',
                [roomCode, gameMode, impostorCount]
            );

            await db.query(
                'INSERT INTO players (room_code, player_name, role, is_host) VALUES (?, ?, ?, ?)',
                [roomCode, hostName, 'PLAYER', true]
            );
            console.log(`💾 [MySQL] Oda (${roomCode}) ve Host (${hostName}) başarıyla kaydedildi.`);
        } catch (dbErr) {
            console.error("❌ [MySQL Error] Oda kurulamadı:", dbErr);
        }

        socket.join(roomCode);
        console.log(`🏠 Oda Oluşturuldu: ${roomCode} | Host: ${hostName}`);

        socket.emit('room_created', { success: true, roomCode });
    });

    // ➡️ 2. OYUNCU ODAYA KATILMAK İSTEDİĞİNDE[cite: 2]
    socket.on('join_room', async (data) => {
        const { roomCode, playerName } = data;

        const roomExists = await redisClient.exists(`room:${roomCode}`);

        if (!roomExists) {
            socket.emit('error_message', { message: '❌ OOOOPS! Böyle bir oda bulunamadı.' });
            return;
        }

        const currentRoom = await redisClient.hgetall(`room:${roomCode}`);
        let players = JSON.parse(currentRoom.players || '[]');

        if (!players.includes(playerName)) {
            players.push(playerName);

            // 🟢 [MYSQL'E YAZMA]: Odaya yeni bir oyuncu katıldığında onu players tablosuna ekliyoruz.
            // is_winner varsayılan olarak NULL kalacaktır kanka.
            try {
                await db.query(
                    'INSERT INTO players (room_code, player_name, role, is_host) VALUES (?, ?, ?, ?)',
                    [roomCode, playerName, 'PLAYER', false]
                );
                console.log(`💾 [MySQL] Oyuncu odaya eklendi: ${playerName} -> Oda: ${roomCode}`);
            } catch (dbErr) {
                console.error("❌ [MySQL Error] Oyuncu eklenemedi:", dbErr);
            }
        }

        await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(players));

        socket.join(roomCode);
        console.log(`🏃‍♂️ ${playerName}, ${roomCode} odasına katıldı.`);

        io.to(roomCode).emit('room_updated', {
            roomCode,
            players: players,
            host: currentRoom.host
        });
    });

    // ➡️ 3. HOST OYLAMAYI TETİKLEDİĞİNDE[cite: 2]
    socket.on('start_voting', (data) => {
        const { roomCode } = data;
        console.log(`📣 [OYLAMA BAŞLADI] Host odayı oylamaya yönlendiriyor: ${roomCode}`);
        io.to(roomCode).emit('navigate_to_voting');
    });

    // ➡️ 4. OYUNCU OY KULLANDIĞINDA VEYA OYUNU KİLİTLEDİĞİNDE[cite: 2]
    socket.on('submit_vote', async (data) => {
        const { roomCode, voterName, votedFor, isLocking } = data;

        const voteKey = `room:${roomCode}:votes`;
        const lockKey = `room:${roomCode}:locked_votes`;

        if (votedFor !== undefined) {
            await redisClient.hset(voteKey, voterName, votedFor);
            console.log(`🗳️ [OY ANLIK GÜNCELLEME] Oda: ${roomCode} | ${voterName} -> ${votedFor}`);
        }

        if (isLocking) {
            await redisClient.sadd(lockKey, voterName);
            console.log(`🔒 [OY KİLİTLENDİ] Oda: ${roomCode} | ${voterName} oyunu kilitledi.`);
        }

        const roomData = await redisClient.hgetall(`room:${roomCode}`);
        const players = JSON.parse(roomData.players || '[]');
        const impostors = JSON.parse(roomData.impostor || '[]');

        const currentVotes = await redisClient.hgetall(voteKey);
        const lockedPlayers = await redisClient.smembers(lockKey);

        io.to(roomCode).emit('vote_status_updated', {
            votedCount: lockedPlayers.length,
            totalPlayers: players.length,
            currentVotes: currentVotes
        });

        if (lockedPlayers.length >= players.length) {
            console.log(`🏁 Oda [${roomCode}] için tüm oylar kilitlendi. Sonuçlar hesaplanıyor...`);

            const voteCounts = {};
            players.forEach(p => voteCounts[p] = 0);

            Object.entries(currentVotes).forEach(([voter, voted]) => {
                if (voted !== 'skip' && voteCounts[voted] !== undefined) {
                    voteCounts[voted]++;
                }
            });

            let eliminatedPlayer = null;
            let maxVotes = 0;
            let isTie = false;

            Object.entries(voteCounts).forEach(([player, count]) => {
                if (count > maxVotes) {
                    maxVotes = count;
                    eliminatedPlayer = player;
                    isTie = false;
                } else if (count === maxVotes && count > 0) {
                    isTie = true;
                }
            });

            if (isTie) eliminatedPlayer = null;
            const actualImpostor = impostors[0] || "Bulunamadı";

            // 🟢 [MYSQL'E YAZMA - OYUN BİTİŞ KONTROLÜ]:
            // Eğer elenen kişi İmpostor ise veya elenecek kimse kalmadıysa oyunun bittiği anı yakalıyoruz.
            // Flutter tarafında oyunu bitiren bir event de olabilir ama biz burada da önlem alıyoruz:
            if (eliminatedPlayer === actualImpostor && !isTie) {
                // Köylüler kazandı!
                try {
                    await db.query('UPDATE players SET is_winner = TRUE WHERE room_code = ? AND role = "PLAYER"', [roomCode]);
                    await db.query('UPDATE players SET is_winner = FALSE WHERE room_code = ? AND role = "IMPOSTOR"', [roomCode]);
                    await db.query('UPDATE rooms SET is_active = FALSE WHERE room_code = ?', [roomCode]);
                    console.log(`🏆 [MySQL] Köylüler kazandı, veri tabanı güncellendi ve oda pasife çekildi.`);
                } catch (dbErr) {
                    console.error("❌ [MySQL Error] Oyun sonlandırılamadı:", dbErr);
                }
            } else if (eliminatedPlayer !== null && eliminatedPlayer !== actualImpostor && !isTie) {
                // Yanlış kişi elendi, oyunda 1 impostor ve 1 köylü kalma sınırına gelindiyse İmpostor kazanır.
                const kalanOyuncuSayisi = players.length - 1;
                if (kalanOyuncuSayisi <= 2) { // 1 İmpostor ve 1 Köylü kaldığında impostor kazanır kanka
                    try {
                        await db.query('UPDATE players SET is_winner = TRUE WHERE room_code = ? AND role = "IMPOSTOR"', [roomCode]);
                        await db.query('UPDATE players SET is_winner = FALSE WHERE room_code = ? AND role = "PLAYER"', [roomCode]);
                        await db.query('UPDATE rooms SET is_active = FALSE WHERE room_code = ?', [roomCode]);
                        console.log(`🏆 [MySQL] İmpostor kazandı, veri tabanı güncellendi ve oda pasife çekildi.`);
                    } catch (dbErr) {
                        console.error("❌ [MySQL Error] Oyun sonlandırılamadı:", dbErr);
                    }
                }
            }

            io.to(roomCode).emit('voting_results', {
                eliminatedPlayer: eliminatedPlayer,
                isTie: isTie,
                impostorName: actualImpostor,
                votes: currentVotes
            });

            await redisClient.del(voteKey);
            await redisClient.del(lockKey);
        }
    });

    socket.on('disconnect', () => {
        console.log(`❌ Kullanıcı ayrıldı: ${socket.id}`);
    });
});

// ==========================================
// 🏁 --- API ENDPOINT'LERİ ---
// ==========================================

// 🏁 1. Host'un Oyunu Başlatma İsteği[cite: 2]
app.post('/api/start-game', async (req, res) => {
    try {
        const { roomCode, players, gameMode, category, impostorCount } = req.body;

        if (!players || players.length === 0) {
            return res.status(400).json({ error: "Odadaki oyuncu listesi boş olamaz!" });
        }

        let secilenKategori = category;
        if (!category || category === 'Rastgele') {
            const kategoriler = Object.keys(dictionary);
            secilenKategori = kategoriler[Math.floor(Math.random() * kategoriler.length)];
        }

        const kategoriKelimeleri = dictionary[secilenKategori];
        if (!kategoriKelimeleri || kategoriKelimeleri.length < 2) {
            return res.status(500).json({ error: "Seçilen kategoride yeterli kelime bulunamadı kanka!" });
        }

        const randomIndex1 = Math.floor(Math.random() * kategoriKelimeleri.length);
        const selectedWord = kategoriKelimeleri[randomIndex1];

        let impostorWord = "Kelime Yok";
        if (gameMode === 'Yakin Kelime') {
            const kalanKelimeler = kategoriKelimeleri.filter(w => w !== selectedWord);
            const randomIndex2 = Math.floor(Math.random() * kalanKelimeler.length);
            impostorWord = kalanKelimeler[randomIndex2];
        }

        const hedonImpostorSayisi = Math.min(impostorCount || 1, players.length - 1);

        let karistirilmisOyuncular = [...players];
        for (let i = karistirilmisOyuncular.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [karistirilmisOyuncular[i], karistirilmisOyuncular[j]] = [karistirilmisOyuncular[j], karistirilmisOyuncular[i]];
        }

        const chosenImpostors = karistirilmisOyuncular.slice(0, hedonImpostorSayisi);

        console.log(`🎮 Oda [${roomCode}] için Oyun Başladı!`);
        console.log(`📂 Kategori: ${secilenKategori} | Mod: ${gameMode}`);
        console.log(`🎯 Köylü Kelimesi: ${selectedWord} | 😈 İmpostorlar: ${chosenImpostors.join(', ')} (${impostorWord})`);

        // 🟢 [MYSQL'E YAZMA - ROLLERİ GÜNCELLEME]: 
        // Oyun resmen başladığında artık İmpostor olan oyuncular bellidir. 
        // players tablosunda, seçilen impostorların rolünü 'IMPOSTOR' olarak güncelliyoruz.
        try {
            // Önce tüm oyuncuların rolünü PLAYER yapalım (garanti olsun)
            await db.query('UPDATE players SET role = "PLAYER" WHERE room_code = ?', [roomCode]);

            // Sonra seçilen impostor'ları güncelle
            for (const impName of chosenImpostors) {
                await db.query(
                    'UPDATE players SET role = "IMPOSTOR" WHERE room_code = ? AND player_name = ?',
                    [roomCode, impName]
                );
            }
            console.log(`💾 [MySQL] Rol dağılımları başarıyla güncellendi.`);
        } catch (dbErr) {
            console.error("❌ [MySQL Error] Rol dağılımı kaydedilemedi:", dbErr);
        }

        await redisClient.hset(`room:${roomCode}`, 'status', 'started');
        await redisClient.hset(`room:${roomCode}`, 'secretWord', selectedWord);
        await redisClient.hset(`room:${roomCode}`, 'impostor', JSON.stringify(chosenImpostors));
        await redisClient.hset(`room:${roomCode}`, 'impostorWord', impostorWord);

        const roomDataString = {
            status: "started",
            secretWord: selectedWord,
            impostor: chosenImpostors,
            impostorWord: impostorWord
        };
        await redisClient.set(`room:string:${roomCode}`, JSON.stringify(roomDataString));

        io.to(roomCode).emit('game_started', roomDataString);

        return res.json({
            status: "success",
            secretWord: selectedWord,
            impostor: chosenImpostors,
            impostorWord: impostorWord
        });

    } catch (error) {
        console.error("Oyun başlatılırken hata oluştu:", error);
        return res.status(500).json({ error: "Sunucu hatası kanka" });
    }
});

// 📡 2. Oyuncuların Oda Durumunu Sorgulama İsteği[cite: 2]
app.get('/api/game-status/:roomCode', async (req, res) => {
    try {
        const { roomCode } = req.params;

        let roomData = await redisClient.hgetall(`room:${roomCode}`);

        if (!roomData || Object.keys(roomData).length === 0) {
            const rawData = await redisClient.get(`room:string:${roomCode}`);
            if (!rawData) {
                return res.json({ status: "waiting" });
            }
            return res.json(JSON.parse(rawData));
        }

        if (roomData.players) roomData.players = JSON.parse(roomData.players);
        if (roomData.impostor) roomData.impostor = JSON.parse(roomData.impostor);

        return res.json(roomData);

    } catch (error) {
        console.error("Oda durumu kontrol edilirken hata oluştu:", error);
        return res.status(500).json({ error: "Sunucu hatası" });
    }
});

// 🎯 CANLIYA GEÇİŞİ VE HER PORTU DESTEKLEYEN YAPI[cite: 2]
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Sunucu ${PORT} portunda hazır kanka.`);
});