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
const chanceGames = require('./games/chance_games');
const jackOfHeartsGame = require('./games/jack_of_hearts_game');
const kartZilGame = require('./games/kart_zil_game');

const app = express();

app.use(cors({
    origin: "*",
    methods: ["GET", "POST"]
}));
app.use(express.json());

const server = http.createServer(app);

const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
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

// Flutter buildleri sık güncellendiği için tarayıcının eski oyun sürümünü
// göstermesini engelle. Özellikle main.dart.js ve index.html her istekte
// sunucudan doğrulansın.
app.use('/oyunlar', (req, res, next) => {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    next();
});

app.get('/', (req, res) => {
    res.sendFile(path.join(anaProjeDizini, 'oyun_launcher.html'));
});

app.get('/vampir-guncelle', (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.sendFile(path.join(anaProjeDizini, 'vampir_cache_reset.html'));
});

const vampirV2BuildYolu = path.join(
    oyunlarDizini,
    'vampir_koylu_game',
    'build',
    'web_v2'
);
if (fs.existsSync(vampirV2BuildYolu)) {
    app.use(
        '/oyunlar/vampir_koylu_game/web-v2',
        express.static(vampirV2BuildYolu)
    );
}

const kartZilV2BuildYolu = path.join(
    oyunlarDizini,
    'kart_zil_game',
    'build',
    'web_v2'
);
if (fs.existsSync(kartZilV2BuildYolu)) {
    app.use(
        '/oyunlar/kart_zil_game/web-v2',
        express.static(kartZilV2BuildYolu)
    );
}

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
                aciklama = "Gizli kelimeyi çöz, ipuçlarını takip et ve aranızdaki Impostor’u bul.";
            } else if (oyunAdı === "vampir_koylu_game") {
                ikon = "fa-solid fa-cloud-moon";
                aciklama = "Karanlık çöktüğünde vampirler avlanacak, gündüz olduğunda ise köy meydanında adalet aranacak!";
            }

            if (oyunAd\u0131 === 'sans_oyunlari_game') {
                ikon = 'fa-solid fa-dice';
                aciklama = 'Karar vermek veya rastgele sonuç oluşturmak için yazı-tura ya da zar aracını kullan.';
            }

            if (oyunAd\u0131 === 'kupa_valesi_game') {
                ikon = 'fa-solid fa-heart';
                aciklama = 'İpuçlarını değerlendir, gizli sembolünü bul ve doğru tahmini yap!';
            }
            if (oyunAd\u0131 === 'kart_zil_game') {
                ikon = 'fa-solid fa-bell';
                aciklama = 'Elini g\u00FC\u00E7lendir, en iyi kart kombinasyonunu kur ve do\u011Fru anda zile bas!';
            }
            dinamikAktifOyunlar.push({
                id: oyunAdı,
                isim: {
                    impostor_game: 'Impostor',
                    kart_zil_game: 'Kart & Zil',
                    kupa_valesi_game: 'Sembol Avı',
                    sans_oyunlari_game: 'Zar & Yazı-Tura',
                    vampir_koylu_game: 'Vampir Köylü'
                }[oyunAdı] || oyunAdı.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
                aciklama: aciklama,
                alt_yol: oyunAdı === 'vampir_koylu_game'
                    ? '/oyunlar/vampir_koylu_game/web-v2/index.html'
                    : oyunAdı === 'kart_zil_game'
                        ? '/oyunlar/kart_zil_game/web-v2/index.html'
                        : `/oyunlar/${oyunAdı}/web/index.html`,
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
const jackOfHeartsContext = { app, io, redisClient, path, fs };

if (typeof impostorGame === 'function') {
    impostorGame(impostorContext);
}

if (typeof vampirKoyluGame === 'function') {
    vampirKoyluGame(vampirContext);
}

if (typeof jackOfHeartsGame === 'function') {
    jackOfHeartsGame(jackOfHeartsContext);
}

if (typeof chanceGames === 'function') {
    chanceGames({ app, io, redisClient, path, fs });
}

if (typeof kartZilGame === 'function') {
    kartZilGame({ app, io, redisClient, path, fs });
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
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Ana Sunucu 0.0.0.0:${PORT} adresinde hazır.`);
});
