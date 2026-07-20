const express = require('express');
const http = require('http');
const Redis = require('ioredis');
const fs = require('fs');
const path = require('path');
const { Server } = require('socket.io');
const cors = require('cors');
const db = require('./db');

const app = express();

app.use(cors({
    origin: "*",
    methods: ["GET", "POST"],
    credentials: true
}));
app.use(express.json());

const server = http.createServer(app);

const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"],
        credentials: true
    },
    allowEIO3: true,
    transports: ['websocket', 'polling']
});

const anaProjeDizini = path.resolve(__dirname, '..');
const oyunlarDizini = path.resolve(anaProjeDizini, 'oyunlar');

app.get('/', (req, res) => {
    res.sendFile(path.join(anaProjeDizini, 'oyun_launcher.html'));
});

// YENİ DİNAMİK YAPI
const dinamikAktifOyunlar = [];

if (fs.existsSync(oyunlarDizini)) {
    const oyunKlasorleri = fs.readdirSync(oyunlarDizini);

    oyunKlasorleri.forEach(oyunAdı => {
        const oyunBuildYolu = path.join(oyunlarDizini, oyunAdı, 'build', 'web');

        if (fs.existsSync(oyunBuildYolu)) {
            app.get(`/oyunlar/${oyunAdı}/web/index.html`, (req, res) => {
                res.sendFile(path.join(oyunBuildYolu, 'index.html'));
            });

            app.use(`/oyunlar/${oyunAdı}/web`, express.static(oyunBuildYolu));
            console.log(`🎮 [OTOMATİK AKTİF] "${oyunAdı}" oyunu başarıyla sunucuya bağlandı!`);

            // Launcher için oyun bilgilerini dinamik hazırlıyoruz kanka
            let ikon = "fa-solid fa-gamepad";
            let aciklama = "Eğlenirken öğrenmeye hazır mısın? İstediğin oyunu seç ve hemen başla!";

            if (oyunAdı === "impostor_game") {
                ikon = "fa-solid fa-user-secret";
                aciklama = "Arkadaşlarınla birlikte gizli kelimeyi bulmaya çalış, aranızdaki imposter(lar)ı ayıkla!";
            } else if (oyunAdı === "vampir_koylu_game") {
                ikon = "fa-solid fa-cloud-moon";
                aciklama = "Karanlık çöktüğünde vampirler avlanacak, gündüz olduğunda ise köy meydanında adalet aranacak!";
            }

            dinamikAktifOyunlar.push({
                id: oyunAdı,
                isim: oyunAdı.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
                aciklama: aciklama,
                alt_yol: `/oyunlar/${oyunAdı}/web/index.html`,
                ikon_class: ikon
            });
        }
    });
} else {
    console.log("⚠️ Uyarı: 'oyunlar' klasörü bulunamadı!");
}

// Ön yüzün oyunları çekebileceği yeni API kapısı
app.get('/api/aktif-oyunlar', (req, res) => {
    res.json(dinamikAktifOyunlar);
});

const redisClient = new Redis();
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

    socket.on('create_room', async (data) => {
        const { roomCode, hostName, gameMode = 'Klasik', category = 'Rastgele', impostorCount = 1 } = data;

        const roomExists = await redisClient.exists(`room:${roomCode}`);
        if (roomExists) {
            console.log(`🔄 Oda (${roomCode}) zaten mevcut. Mevcut kurucu korunuyor.`);
            socket.join(roomCode);

            const currentRoom = await redisClient.hgetall(`room:${roomCode}`);
            const players = JSON.parse(currentRoom.players || '[]');

            if (!players.includes(hostName)) {
                players.push(hostName);
                await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(players));
            }

            const returnedKey = `room:${roomCode}:returned_players`;
            await redisClient.sadd(returnedKey, hostName);
            const returnedPlayers = await redisClient.smembers(returnedKey);

            socket.emit('room_created', { success: true, roomCode });
            
            io.to(roomCode).emit('room_updated', {
                roomCode,
                players: players,
                host: currentRoom.host
            });
            
            io.to(roomCode).emit('lobby_return_status', {
                returnedPlayers: returnedPlayers,
                isEveryoneBack: returnedPlayers.length >= players.length
            });
            return;
        }

        const roomData = {
            host: hostName,
            status: 'waiting',
            players: JSON.stringify([hostName]),
            gameMode: gameMode,
            category: category,
            impostorCount: impostorCount.toString()
        };

        await redisClient.hmset(`room:${roomCode}`, roomData);
        await redisClient.expire(`room:${roomCode}`, 7200);

        await redisClient.sadd(`room:${roomCode}:returned_players`, hostName);

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
        console.log(`🏠 Oda Oluşturuldu: ${roomCode} | Host: ${hostName} | Mod: ${gameMode} | Kategori: ${category}`);
        socket.emit('room_created', { success: true, roomCode });
    });

    // 🎯 YENİ SOKET: Host lobi içinden ayar değiştirdiğinde anlık tetiklenir kanka![cite: 9]
    socket.on('update_room_settings', async (data) => {
        const { roomCode, gameMode, category, impostorCount } = data;
        const roomExists = await redisClient.exists(`room:${roomCode}`);

        if (roomExists) {
            await redisClient.hset(`room:${roomCode}`, 'gameMode', gameMode);
            await redisClient.hset(`room:${roomCode}`, 'category', category);
            await redisClient.hset(`room:${roomCode}`, 'impostorCount', impostorCount.toString());

            console.log(`⚙️ [AYARLAR GÜNCELLENDİ] Oda: ${roomCode} | Mod: ${gameMode} | Kategori: ${category} | İmp: ${impostorCount}`);
            
            // Lobi ekranındaki herkese ayarların değiştiğini haber veriyoruz kanka
            io.to(roomCode).emit('room_settings_changed', {
                gameMode,
                category,
                impostorCount: parseInt(impostorCount, 10)
            });
        }
    });

    socket.on('player_returned_to_lobby', async (data) => {
        const { roomCode, playerName } = data;
        const roomExists = await redisClient.exists(`room:${roomCode}`);

        if (roomExists) {
            const returnedKey = `room:${roomCode}:returned_players`;
            await redisClient.sadd(returnedKey, playerName);

            const roomData = await redisClient.hgetall(`room:${roomCode}`);
            const totalPlayers = JSON.parse(roomData.players || '[]');
            const returnedPlayers = await redisClient.smembers(returnedKey);

            io.to(roomCode).emit('lobby_return_status', {
                returnedPlayers: returnedPlayers,
                isEveryoneBack: returnedPlayers.length >= totalPlayers.length
            });
            console.log(`🟢 [LOBİYE DÖNDÜ] Oda: ${roomCode} | Oyuncu: ${playerName} (${returnedPlayers.length}/${totalPlayers.length})`);
        }
    });

    socket.on('check_host', async (data) => {
        const { roomCode, playerName } = data;
        const roomExists = await redisClient.exists(`room:${roomCode}`);

        if (roomExists) {
            const currentRoom = await redisClient.hgetall(`room:${roomCode}`);
            const isHost = currentRoom.host === playerName;
            socket.emit('host_verification', { isHost: isHost, actualHost: currentRoom.host });
        } else {
            socket.emit('host_verification', { isHost: false, actualHost: "" });
        }
    });

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

        await redisClient.sadd(`room:${roomCode}:returned_players`, playerName);
        const returnedPlayers = await redisClient.smembers(`room:${roomCode}:returned_players`);

        socket.join(roomCode);
        console.log(`🏃‍♂️ ${playerName}, ${roomCode} odasına katıldı.`);

        io.to(roomCode).emit('room_updated', {
            roomCode,
            players: players,
            host: currentRoom.host
        });

        io.to(roomCode).emit('lobby_return_status', {
            returnedPlayers: returnedPlayers,
            isEveryoneBack: returnedPlayers.length >= players.length
        });
    });

    socket.on('start_voting', (data) => {
        const { roomCode } = data;
        console.log(`📣 [OYLAMA BAŞLADI] Host odayı oylamaya yönlendiriyor: ${roomCode}`);
        io.to(roomCode).emit('navigate_to_voting');
    });

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

            if (eliminatedPlayer === actualImpostor && !isTie) {
                try {
                    await db.query('UPDATE players SET is_winner = TRUE WHERE room_code = ? AND role = "PLAYER"', [roomCode]);
                    await db.query('UPDATE players SET is_winner = FALSE WHERE room_code = ? AND role = "IMPOSTOR"', [roomCode]);
                    await db.query('UPDATE rooms SET is_active = FALSE WHERE room_code = ?', [roomCode]);
                    console.log(`🏆 [MySQL] Köylüler kazandı, veri tabanı güncellendi ve oda pasife çekildi.`);
                } catch (dbErr) {
                    console.error("❌ [MySQL Error] Oyun sonlandırılamadı:", dbErr);
                }
            } else if (eliminatedPlayer !== null && eliminatedPlayer !== actualImpostor && !isTie) {
                const kalanOyuncuSayisi = players.length - 1;
                if (kalanOyuncuSayisi <= 2) {
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
            
            await redisClient.del(`room:${roomCode}:returned_players`);
        }
    });

    socket.on('disconnect', () => {
        console.log(`❌ Kullanıcı ayrıldı: ${socket.id}`);
    });
});

// ==========================================
// 🏁 --- API ENDPOINT'LERİ ---
// ==========================================

app.post('/api/start-game', async (req, res) => {
    try {
        const { roomCode, players, gameMode, category, impostorCount } = req.body;

        if (!players || players.length === 0) {
            return res.status(400).json({ error: "Odadaki oyuncu listesi boş olamaz!" });
        }

        const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
        
        // 🎯 KATEGORİ VE MOD KORUMA DUVARI: Redis hafızasında (savedRoom) zaten kurulan geçerli bir oda ayarı varsa,
        // Flutter'dan oylama dönüşünde gelen ezici 'Rastgele' veya boş dataları tamamen ezip orijinal ayarlara öncelik tanıyoruz kanka![cite: 9]
        let aktifOyunModu = (savedRoom.gameMode && savedRoom.gameMode !== 'Rastgele') ? savedRoom.gameMode : (gameMode || 'Klasik');
        let aktifKategori = (savedRoom.category && savedRoom.category !== 'Rastgele') ? savedRoom.category : (category || 'Rastgele');
        let aktifImpostorSayisi = parseInt(savedRoom.impostorCount || impostorCount || '1', 10);

        if (aktifKategori === 'Rastgele') {
            const kategoriler = Object.keys(dictionary);
            aktifKategori = kategoriler[Math.floor(Math.random() * kategoriler.length)];
        }

        const kategoriKelimeleri = dictionary[aktifKategori];
        if (!kategoriKelimeleri || kategoriKelimeleri.length < 2) {
            return res.status(500).json({ error: "Seçilen kategoride yeterli kelime bulunamadı kanka!" });
        }

        const randomIndex1 = Math.floor(Math.random() * kategoriKelimeleri.length);
        const selectedWord = kategoriKelimeleri[randomIndex1];

        let impostorWord = "Kelime Yok";
        if (aktifOyunModu === 'Yakin Kelime') {
            const kalanKelimeler = kategoriKelimeleri.filter(w => w !== selectedWord);
            const randomIndex2 = Math.floor(Math.random() * kalanKelimeler.length);
            impostorWord = kalanKelimeler[randomIndex2];
        }

        const hedonImpostorSayisi = Math.min(aktifImpostorSayisi, players.length - 1);

        let karistirilmisOyuncular = [...players];
        for (let i = karistirilmisOyuncular.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [karistirilmisOyuncular[i], karistirilmisOyuncular[j]] = [karistirilmisOyuncular[j], karistirilmisOyuncular[i]];
        }

        const chosenImpostors = karistirilmisOyuncular.slice(0, hedonImpostorSayisi);

        console.log(`🎮 Oda [${roomCode}] için Yeni El Başladı!`);
        console.log(`📂 Kategori: ${aktifKategori} | Mod: ${aktifOyunModu}`);
        console.log(`🎯 Köylü Kelimesi: ${selectedWord} | 😈 İmpostorlar: ${chosenImpostors.join(', ')} (${impostorWord})`);

        try {
            await db.query('UPDATE players SET role = "PLAYER" WHERE room_code = ?', [roomCode]);

            for (const impName of chosenImpostors) {
                await db.query(
                    'UPDATE players SET role = "IMPOSTOR" WHERE room_code = ? AND player_name = ?',
                    [roomCode, impName]
                );
            }
            console.log(`💾 [MySQL] Yeni el rol dağılımları başarıyla güncellendi.`);
        } catch (dbErr) {
            console.error("❌ [MySQL Error] Rol dağılımı kaydedilemedi:", dbErr);
        }

        await redisClient.hset(`room:${roomCode}`, 'status', 'started');
        await redisClient.hset(`room:${roomCode}`, 'secretWord', selectedWord);
        await redisClient.hset(`room:${roomCode}`, 'impostor', JSON.stringify(chosenImpostors));
        await redisClient.hset(`room:${roomCode}`, 'impostorWord', impostorWord);

        await redisClient.del(`room:${roomCode}:returned_players`);

        const roomDataString = {
            status: "started",
            secretWord: selectedWord,
            impostor: chosenImpostors,
            impostorWord: impostorWord,
            gameMode: aktifOyunModu,
            category: aktifKategori
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
        console.error("Oyunu ilerletirken hata oluştu:", error);
        return res.status(500).json({ error: "Sunucu hatası kanka" });
    }
});

app.post('/api/reset-game-status', async (req, res) => {
    try {
        const { roomCode } = req.body;
        await redisClient.hset(`room:${roomCode}`, 'status', 'waiting');
        await redisClient.del(`room:string:${roomCode}`);
        console.log(`🔄 Oda [${roomCode}] durumu lobi için başarıyla sıfırlandı.`);
        return res.json({ status: "success" });
    } catch (error) {
        return res.status(500).json({ error: "Sıfırlama hatası" });
    }
});

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

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Sunucu ${PORT} portunda hazır kanka.`);
});