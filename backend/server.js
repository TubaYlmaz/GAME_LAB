const express = require('express');
const http = require('http');
const Redis = require('ioredis');
const fs = require('fs');
const path = require('path');
const { Server } = require('socket.io');
const cors = require('cors');
const db = require('./db');

// Oyun modüllerini içe aktarıyoruz
const impostorGame = require('./games/impostor_game');
const vampirKoyluGame = require('./games/vampir_koylu_game');

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

const redisClient = new Redis();

redisClient.on('connect', () => {
    console.log("1. Adım: Redis'e başarıyla bağlanıldı!");
});

redisClient.on('error', (err) => {
    console.log('Redis Hatası:', err);
});

// ==========================================
// 🎮 DİNAMİK OYUN STATİK VE LUNCHER YAPISI
// ==========================================
const anaProjeDizini = path.resolve(__dirname, '..');
const oyunlarDizini = path.resolve(anaProjeDizini, 'oyunlar');

app.get('/', (req, res) => {
    res.sendFile(path.join(anaProjeDizini, 'oyun_launcher.html'));
});

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

app.get('/api/aktif-oyunlar', (req, res) => {
    res.json(dinamikAktifOyunlar);
});

// ==========================================
// 🚀 OYUN MODÜLLERİNİ BAŞLATMA
// ==========================================
const vampirContext = { app, io, redisClient, db: db.vampirDb, path, fs };
const impostorContext = { app, io, redisClient, db: db.impostorDb, path, fs };

if (typeof impostorGame === 'function') {
    impostorGame(impostorContext);
}

if (typeof vampirKoyluGame === 'function') {
    vampirKoyluGame(vampirContext);
}

// Ortak WebSocket Bağlantı Logu
io.on('connection', (socket) => {
    console.log(`🔌 Bir kullanıcı bağlandı: ${socket.id}`);

    socket.on('disconnect', () => {
        console.log(`❌ Kullanıcı ayrıldı: ${socket.id}`);
    });
});

// Ortak Oyun Durum Kontrolü Endpoint'leri
app.post('/api/reset-game-status', async (req, res) => {
    try {
        const { roomCode } = req.body;
        await redisClient.hset(`room:${roomCode}`, 'status', 'waiting');
        await redisClient.del(`room:string:${roomCode}`);
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
    console.log(`🚀 Ana Sunucu ${PORT} portunda hazır kanka!`);
});