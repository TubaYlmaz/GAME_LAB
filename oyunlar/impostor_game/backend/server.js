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
// 🎯 GÜVENLİ VE DİNAMİK YÖNLENDİRMELER (MATEMATİĞİ TAM DOĞRU YAPI)
// =========================================================================

// 1. backend klasöründen sadece 1 adım yukarı çıkıp "impostor_game" dizinini buluyoruz kanka (Şimdi tam doğru!):
const oyunDizini = path.resolve(__dirname, '..'); // .../oyunlar/impostor_game

// 2. backend klasöründen tam 3 adım yukarı çıkarak "OyunLauncherProjesi" ana dizinini buluyoruz:
const anaProjeDizini = path.resolve(__dirname, '../../..'); // .../OyunLauncherProjesi

// 3. Gerçek 'build/web' klasörünü buluyoruz:
const gercekOyunBuildDizini = path.resolve(oyunDizini, 'build/web'); // .../impostor_game/build/web

// 4. Kullanıcı 'localhost:3000' yazdığında ana launcher sayfasını gönderiyoruz:
app.get('/', (req, res) => {
    res.sendFile(path.join(anaProjeDizini, 'oyun_launcher.html'));
});

// 5. Oyun kartına basıldığında gerçek derlenmiş 'index.html' dosyasını gönderiyoruz:
app.get('/oyunlar/impostor_game/web/index.html', (req, res) => {
    res.sendFile(path.join(gercekOyunBuildDizini, 'index.html')); 
});

// 6. Statik dosyaları doğrudan 'build/web' altından servis ediyoruz:
app.use('/oyunlar/impostor_game/web', express.static(gercekOyunBuildDizini));

const server = http.createServer(app);

// WebSocket için CORS ayarları
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const redisClient = new Redis();

// 📁 dictionary.json dosyamızı güvenli ve dinamik şekilde yüklüyoruz kanka
const dictionaryPath = path.join(__dirname, '../dictionary.json');
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