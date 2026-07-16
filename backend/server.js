const express = require('express');
const http = require('http');
const Redis = require('ioredis');
const fs = require('fs');
const path = require('path'); // Dosya yolları için güvenli modül
const { Server } = require('socket.io'); // Canlı bağlantılar için Socket.io
const cors = require('cors'); // İşte o meşhur paketimiz burada!

const app = express();
app.use(cors()); // Flutter Web ve Mobil ağ istekleri için CORS aktif
app.use(express.json()); // HTTP POST isteklerindeki JSON gövdelerini okuyabilmek için

// =========================================================================
// 🎯 ANA BACKEND - DİNAMİK OTOMATİK OYUN TARAYICI (ORTAK SUNUCU)
// =========================================================================

// __dirname şu an: OyunLauncherProjesi/backend
const anaProjeDizini = path.resolve(__dirname, '..'); // Bir üst klasör (OyunLauncherProjesi)
const oyunlarDizini = path.resolve(anaProjeDizini, 'oyunlar'); // .../OyunLauncherProjesi/oyunlar

// 1. Kullanıcı 'localhost:3000' yazdığında ana launcher sayfasını gönderiyoruz:
app.get('/', (req, res) => {
    res.sendFile(path.join(anaProjeDizini, 'oyun_launcher.html'));
});

// 2. 'oyunlar' klasöründeki tüm oyunları tarayıp otomatik olarak sunucuya bağlıyoruz:
if (fs.existsSync(oyunlarDizini)) {
    const oyunKlasorleri = fs.readdirSync(oyunlarDizini);

    oyunKlasorleri.forEach(oyunAdı => {
        const oyunBuildYolu = path.join(oyunlarDizini, oyunAdı, 'build', 'web');

        // Eğer oyun klasörünün içinde 'build/web' derleme çıktısı varsa otomatik aktif et kanka:
        if (fs.existsSync(oyunBuildYolu)) {
            
            // Oyuna ait index.html yönlendirmesi:
            app.get(`/oyunlar/${oyunAdı}/web/index.html`, (req, res) => {
                res.sendFile(path.join(oyunBuildYolu, 'index.html'));
            });

            // Oyuna ait statik dosyaların (js, assets vb.) servisi:
            app.use(`/oyunlar/${oyunAdı}/web`, express.static(oyunBuildYolu));
            
            console.log(`🎮 [OTOMATİK AKTİF] "${oyunAdı}" oyunu başarıyla sunucuya bağlandı!`);
        }
    });
} else {
    console.log("⚠️ Uyarı: 'oyunlar' klasörü bulunamadı!");
}

const server = http.createServer(app);

// WebSocket için CORS ayarları
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const redisClient = new Redis();

// 📁 dictionary.json dosyasını oyunun kendi klasöründen dinamik olarak okuyoruz kanka 🔥
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

    // ➡️ 1. HOST ODA OLUŞTURDUĞUNDA
    socket.on('create_room', async (data) => {
        const { roomCode, hostName } = data;

        const roomData = {
            host: hostName,
            status: 'waiting',
            players: JSON.stringify([hostName])
        };

        await redisClient.hmset(`room:${roomCode}`, roomData);
        await redisClient.expire(`room:${roomCode}`, 7200);

        socket.join(roomCode);
        console.log(`🏠 Oda Oluşturuldu: ${roomCode} | Host: ${hostName}`);

        socket.emit('room_created', { success: true, roomCode });
    });

    // ➡️ 2. OYUNCU ODAYA KATILMAK İSTEDİĞİNDE
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

// ==========================================
    // 🗳️ GERÇEK ZAMANLI MULTIPLAYER OYLAMA SİSTEMİ
    // ==========================================

    // ➡️ 3. OYUNCU OY KULLANDIĞINDA
    socket.on('submit_vote', async (data) => {
        const { roomCode, voterName, votedFor } = data;

        console.log(`🗳️ [OY] Oda: ${roomCode} | ${voterName} -> ${votedFor} için oy verdi.`);

        // Redis'te bu oda için verilmiş oyları tutalım (Geçici hash yapısı)
        const voteKey = `room:${roomCode}:votes`;
        await redisClient.hset(voteKey, voterName, votedFor);

        // Odadaki güncel oyuncu listesini ve rollerini çekelim
        const roomData = await redisClient.hgetall(`room:${roomCode}`);
        const players = JSON.parse(roomData.players || '[]');
        const impostors = JSON.parse(roomData.impostor || '[]'); // İmpostor listesi array olarak duruyor

        // Şu ana kadar kaç kişi oy vermiş kontrol edelim
        const currentVotes = await redisClient.hgetall(voteKey);
        const totalVotesCount = Object.keys(currentVotes).length;

        // Odadaki herkes oy verdi mi?
        if (totalVotesCount >= players.length) {
            console.log(`🏁 Oda [${roomCode}] için oylama tamamlandı. Sonuçlar hesaplanıyor...`);

            // Oyların sayımını yapalım (En çok oyu kim aldı?)
            const voteCounts = {};
            // Herkes için sayacı sıfırlayalım
            players.forEach(p => voteCounts[p] = 0);

            // Oyları sayalım
            Object.values(currentVotes).forEach(voted => {
                if (voted !== 'skip' && voteCounts[voted] !== undefined) {
                    voteCounts[voted]++;
                }
            });

            // En çok oyu alan kişiyi (elenen kişiyi) bulalım
            let eliminatedPlayer = null;
            let maxVotes = 0;
            let isTie = false; // Beraberlik durumu kontrolü

            Object.entries(voteCounts).forEach(([player, count]) => {
                if (count > maxVotes) {
                    maxVotes = count;
                    eliminatedPlayer = player;
                    isTie = false;
                } else if (count === maxVotes && count > 0) {
                    isTie = true; // Aynı oyu alan başka biri var, beraberlik!
                }
            });

            // Eğer beraberlik varsa kimse elenmez kanka
            if (isTie) {
                eliminatedPlayer = null;
            }

            // İmpostor'un adını bulalım (Simülasyon için tek impostor olduğunu varsayalım ya da ilkini alalım)
            const actualImpostor = impostors[0] || "Bulunamadı";

            // Sonuçları odaya canlı yayınla!
            io.to(roomCode).emit('voting_results', {
                eliminatedPlayer: eliminatedPlayer, // En çok oyu alan (Beraberlikte null)
                isTie: isTie,
                impostorName: actualImpostor,
                votes: currentVotes // Kim kime oy verdi detayı da gitsin kanka
            });

            // Oylama bittiği için Redis'teki oyları temizle
            await redisClient.del(voteKey);
        } else {
            // Eğer herkes henüz oy vermediyse, sadece oyların güncel sayısını odadakilere bildir
            io.to(roomCode).emit('vote_status_updated', {
                votedCount: totalVotesCount,
                totalPlayers: players.length
            });
        }
    });

    socket.on('disconnect', () => {
        console.log(`❌ Kullanıcı ayrıldı: ${socket.id}`);
    });
});

// ==========================================
// 🏁 --- API ENDPOINT'LERİ ---
// ==========================================

// 🏁 1. Host'un Oyunu Başlatma İsteği
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

        const hedefImpostorSayisi = Math.min(impostorCount || 1, players.length - 1);
        
        let karistirilmisOyuncular = [...players];
        for (let i = karistirilmisOyuncular.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [karistirilmisOyuncular[i], karistirilmisOyuncular[j]] = [karistirilmisOyuncular[j], karistirilmisOyuncular[i]];
        }

        const chosenImpostors = karistirilmisOyuncular.slice(0, hedefImpostorSayisi);

        console.log(`🎮 Oda [${roomCode}] için Oyun Başladı!`);
        console.log(`📂 Kategori: ${secilenKategori} | Mod: ${gameMode}`);
        console.log(`🎯 Köylü Kelimesi: ${selectedWord} | 😈 İmpostorlar: ${chosenImpostors.join(', ')} (${impostorWord})`);

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

// 📡 2. Oyuncuların Oda Durumunu Sorgulama İstetiği
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

// 🎯 CANLIYA GEÇİŞİ VE HER PORTU DESTEKLEYEN YAPI
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Sunucu ${PORT} portunda hazır kanka.`);
});