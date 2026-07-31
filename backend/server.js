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

// DİNAMİK OYUNLAR YAPISI (DİĞER OYUNLAR İÇİN KORUNDU)
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

// IMPOSTOR VE GENEL SÖZLÜK YAPISI (KORUNDU)
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
            console.log("⚠️ Uyarı: dictionary.json dosyası bulunamadı!");
        }
    } catch (err) {
        console.error("Sözlük JSON dosyası okunurken hata oluştu:", err);
    }
}

redisClient.on('connect', () => {
    console.log("1. Adım: Redis'e başarıyla bağlanıldı!");
    kelimeleriYukle();
});

redisClient.on('error', (err) => {
    console.log('Redis Hatası:', err);
});

// Gece oylarını ve mutabakatları tutan bellek
const nightVotes = {};

// ==========================================
// 👑 MUHTAR/HOST DEVİR YARDIMCISI (RASTGELE DEVİR)
// ==========================================
async function handleHostTransferIfNeeded(roomCode, updatedPlayers) {
    const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
    if (!savedRoom) return updatedPlayers;

    const currentHostName = savedRoom.host;
    const currentHostPlayer = updatedPlayers.find(p => (typeof p === 'object' ? p.name : p) === currentHostName);

    if (currentHostPlayer && currentHostPlayer.isAlive === false) {
        const alivePlayers = updatedPlayers.filter(p => p.isAlive !== false);

        if (alivePlayers.length > 0) {
            const randomIndex = Math.floor(Math.random() * alivePlayers.length);
            const newHost = alivePlayers[randomIndex];
            const newHostName = typeof newHost === 'object' ? newHost.name : newHost;

            updatedPlayers.forEach(p => {
                if (typeof p === 'object') {
                    p.isHost = (p.name === newHostName);
                }
            });

            await redisClient.hset(`room:${roomCode}`, 'host', newHostName);
            console.log(`👑 [MUHTAR DEĞİŞTİ] Eski Muhtar (${currentHostName}) öldü. Yeni Muhtar Rastgele Seçildi: ${newHostName}`);

            io.to(roomCode).emit('vk_host_changed', {
                newHost: newHostName,
                message: `👑 Muhtar ${currentHostName} hayatını kaybetti! Yeni Muhtar rastgele seçildi: ${newHostName}`
            });
        }
    }
    return updatedPlayers;
}

// ==========================================
// 🛠️ ROL DAĞITIM VE KURALLAR YARDIMCISI
// ==========================================
async function distributeAndSaveRoles(roomCode) {
    const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
    if (!savedRoom || !savedRoom.players) return { error: "Oda bulunamadı!" };

    let players = JSON.parse(savedRoom.players || '[]');

    if (players.length < 3) {
        return { error: "Oyunu başlatmak için en az 3 oyuncu gereklidir!" };
    }

    let vampireCount = parseInt(savedRoom.vampireCount, 10);
    if (isNaN(vampireCount) || vampireCount < 1) vampireCount = 1;

    let doctorCount = parseInt(savedRoom.doctorCount, 10);
    if (isNaN(doctorCount) || doctorCount < 0) doctorCount = 0;

    let serialKillerCount = parseInt(savedRoom.serialKillerCount, 10);
    if (isNaN(serialKillerCount) || serialKillerCount < 0) serialKillerCount = 0;

    while ((vampireCount + doctorCount + serialKillerCount) >= players.length) {
        if (serialKillerCount > 0) serialKillerCount--;
        else if (doctorCount > 0) doctorCount--;
        else if (vampireCount > 1) vampireCount--;
        else break;
    }

    let karistirilmis = [...players];
    for (let i = karistirilmis.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [karistirilmis[i], karistirilmis[j]] = [karistirilmis[j], karistirilmis[i]];
    }

    const roleMap = {};
    let idx = 0;

    for (let i = 0; i < vampireCount && idx < karistirilmis.length; i++, idx++) {
        const pName = typeof karistirilmis[idx] === 'object' ? karistirilmis[idx].name : karistirilmis[idx];
        roleMap[pName] = { role: 'Vampir 🧛', isVampire: true };
    }

    for (let i = 0; i < doctorCount && idx < karistirilmis.length; i++, idx++) {
        const pName = typeof karistirilmis[idx] === 'object' ? karistirilmis[idx].name : karistirilmis[idx];
        roleMap[pName] = { role: 'Doktor 🩺', isVampire: false };
    }

    for (let i = 0; i < serialKillerCount && idx < karistirilmis.length; i++, idx++) {
        const pName = typeof karistirilmis[idx] === 'object' ? karistirilmis[idx].name : karistirilmis[idx];
        roleMap[pName] = { role: 'Seri Katil 🔪', isVampire: false };
    }

    while (idx < karistirilmis.length) {
        const pName = typeof karistirilmis[idx] === 'object' ? karistirilmis[idx].name : karistirilmis[idx];
        roleMap[pName] = { role: 'Köylü 🧑‍🌾', isVampire: false };
        idx++;
    }

    const updatedPlayers = players.map(p => {
        const pName = typeof p === 'object' ? p.name : p;
        const assigned = roleMap[pName] || { role: 'Köylü 🧑‍🌾', isVampire: false };

        return {
            name: pName,
            gender: typeof p === 'object' ? (p.gender || 'male') : 'male',
            isHost: typeof p === 'object' ? !!p.isHost : false,
            role: assigned.role,
            isVampire: assigned.isVampire,
            isAlive: true
        };
    });

    await redisClient.hset(`room:${roomCode}`, 'status', 'started');
    await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(updatedPlayers));

    return { success: true, players: updatedPlayers };
}

// ==========================================
// 🚀 OYUN LOGIC VE WEBSOCKET BAĞLANTILARI
// ==========================================

io.on('connection', (socket) => {
    console.log(`🔌 Bir kullanıcı bağlandı: ${socket.id}`);

    socket.on('vk_create_room', async (data) => {
        const { roomCode, hostName, gender, vampireCount, doctorCount, serialKillerCount, villagerCount } = data;
        const initialPlayers = [{ name: hostName, gender: gender || 'male', isHost: true }];

        const roomData = {
            host: hostName,
            status: 'waiting',
            players: JSON.stringify(initialPlayers),
            gameMode: 'Klasik',
            category: 'Rastgele',
            impostorCount: (vampireCount !== undefined ? vampireCount : 1).toString(),
            vampireCount: (vampireCount !== undefined ? vampireCount : 1).toString(),
            doctorCount: (doctorCount !== undefined ? doctorCount : 0).toString(),
            serialKillerCount: (serialKillerCount !== undefined ? serialKillerCount : 0).toString(),
            villagerCount: (villagerCount !== undefined ? villagerCount : 4).toString()
        };

        if (typeof redisClient !== 'undefined') {
            await redisClient.hmset(`room:${roomCode}`, roomData);
            await redisClient.expire(`room:${roomCode}`, 7200);
            await redisClient.sadd(`room:${roomCode}:returned_players`, hostName.trim());
        }

        if (typeof db !== 'undefined') {
            try {
                await db.query(
                    'INSERT INTO rooms (room_code, game_mode, impostor_count) VALUES (?, ?, ?)',
                    [roomCode, 'Klasik', vampireCount || 1]
                );
                await db.query(
                    'INSERT INTO players (room_code, player_name, role, is_host) VALUES (?, ?, ?, ?)',
                    [roomCode, hostName, 'PLAYER', true]
                );
            } catch (dbErr) {
                console.error("❌ [MySQL Error] Oda kurulamadı:", dbErr);
            }
        }

        socket.join(roomCode);
        console.log(`🏠 [Vampir Köylü] Oda Kuruldu: ${roomCode} | Host: ${hostName}`);
        socket.emit('room_created', { success: true, roomCode });
        io.to(roomCode).emit('vk_players_updated', initialPlayers);

        // Oda sahibi ilk açılışta hazır sayılıyor
        const returnedPlayers = await redisClient.smembers(`room:${roomCode}:returned_players`);
        io.to(roomCode).emit('vk_lobby_status_updated', {
            totalPlayersCount: initialPlayers.length,
            returnedPlayers: returnedPlayers
        });
    });

    socket.on('vk_change_phase', async (data) => {
        const { roomCode, nextPhase } = data;
        console.log(`🔄 [Vampir Köylü FAZ] Oda: ${roomCode} -> Yeni Faz: ${nextPhase}`);

        if (nextPhase === 'night') {
            nightVotes[roomCode] = {
                vampires: {},
                killers: {},
                doctors: {},
                mathSolvedPlayers: []
            };
        }

        if (nextPhase === 'voting') {
            io.to(roomCode).emit('vk_navigate_to_voting');
        } else {
            io.to(roomCode).emit('vk_phase_changed', { phase: nextPhase });
        }
    });

    socket.on('update_room_settings', async (data) => {
        const { roomCode, gameMode, category, impostorCount } = data;
        const roomExists = await redisClient.exists(`room:${roomCode}`);

        if (roomExists) {
            await redisClient.hset(`room:${roomCode}`, 'gameMode', gameMode);
            await redisClient.hset(`room:${roomCode}`, 'category', category);
            await redisClient.hset(`room:${roomCode}`, 'impostorCount', impostorCount.toString());

            console.log(`⚙️ [AYARLAR GÜNCELLENDİ] Oda: ${roomCode} | Mod: ${gameMode} | Kategori: ${category} | İmp: ${impostorCount}`);

            io.to(roomCode).emit('room_settings_changed', {
                gameMode,
                category,
                impostorCount: parseInt(impostorCount, 10)
            });
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

    socket.on('vk_join_room', async (data) => {
        const { roomCode, playerName, gender } = data;
        const roomExists = await redisClient.exists(`room:${roomCode}`);

        if (!roomExists) {
            socket.emit('error_message', { message: '❌ Böyle bir oda bulunamadı.' });
            return;
        }

        const currentRoom = await redisClient.hgetall(`room:${roomCode}`);
        let rawPlayers = JSON.parse(currentRoom.players || '[]');

        let playerObjects = rawPlayers.map(p => {
            if (typeof p === 'string') {
                return { name: p, gender: 'male', isHost: p === currentRoom.host };
            }
            return p;
        });

        const playerExists = playerObjects.some(p => p.name.trim().toLowerCase() === playerName.trim().toLowerCase());

        if (!playerExists) {
            playerObjects.push({
                name: playerName,
                gender: gender || 'male',
                isHost: false
            });

            try {
                await db.query(
                    'INSERT INTO players (room_code, player_name, role, is_host) VALUES (?, ?, ?, ?)',
                    [roomCode, playerName, 'PLAYER', false]
                );
            } catch (dbErr) {
                console.error("❌ [MySQL Error] Oyuncu eklenemedi:", dbErr);
            }
        }

        await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(playerObjects));
        await redisClient.sadd(`room:${roomCode}:returned_players`, playerName.trim());
        const returnedPlayers = await redisClient.smembers(`room:${roomCode}:returned_players`);

        socket.join(roomCode);
        console.log(`🏃‍♂️ ${playerName} (${gender}), ${roomCode} odasına katıldı.`);

        io.to(roomCode).emit('room_updated', {
            roomCode,
            players: playerObjects,
            host: currentRoom.host
        });

        io.to(roomCode).emit('vk_players_updated', playerObjects);

        // Hem eski hem yeni lobi dinleyicisine haber ver
        io.to(roomCode).emit('vk_lobby_status_updated', {
            totalPlayersCount: playerObjects.length,
            returnedPlayers: returnedPlayers
        });
        io.to(roomCode).emit('lobby_return_status', {
            returnedPlayers: returnedPlayers,
            isEveryoneBack: returnedPlayers.length >= playerObjects.length
        });
    });

    // ==========================================
    // 🏠 LOBİYE DÖNÜŞ FLAG (BAYRAK) KAYDI
    // ==========================================
    socket.on('vk_player_returned_to_lobby', async (data) => {
        const { roomCode, playerName } = data;
        if (!roomCode || !playerName) return;
        const roomKey = `room:${roomCode}`;

        // İsmi temiz string olarak ekliyoruz
        const cleanName = playerName.toString().trim().toLowerCase();
        await redisClient.sadd(`${roomKey}:returned_players`, cleanName);

        const roomData = await redisClient.hgetall(roomKey);
        let players = JSON.parse(roomData.players || '[]');
        const returnedPlayers = await redisClient.smembers(`${roomKey}:returned_players`) || [];

        console.log(`🟢 [LOBİ FLAG] ${playerName} lobiye döndü. Hazır olanlar: ${returnedPlayers.length}/${players.length}`);

        // Odaya canlı durumu fırlat
        io.to(roomCode).emit('vk_lobby_status_updated', {
            totalPlayersCount: players.length,
            returnedPlayers: returnedPlayers
        });
    });

    // ==========================================
    // 🚀 OYUNU SIFIRDAN BAŞLATMA (KESİN VE SIRALANMIŞ AKIŞ)
    // ==========================================
    socket.on('vk_start_game', async (data) => {
        const { roomCode } = data;
        if (!roomCode) return;

        const roomKey = `room:${roomCode}`;
        console.log(`📣 [YENİ EL BAŞLIYOR] Oda: ${roomCode}`);

        const roomData = await redisClient.hgetall(roomKey);
        if (!roomData || !roomData.players) {
            socket.emit('vk_start_game_error', { message: 'Oda verisi bulunamadı!' });
            return;
        }

        let players = JSON.parse(roomData.players || '[]');
        const returnedPlayers = await redisClient.smembers(`${roomKey}:returned_players`) || [];

        // 1. KONTROL: Lobiye dönmeyen var mı?
        const cleanPlayerNames = players.map(p => (typeof p === 'object' ? p.name : p).toString().trim().toLowerCase());
        const cleanReturnedNames = returnedPlayers.map(r => r.toString().trim().toLowerCase());

        const missingPlayers = cleanPlayerNames.filter(pName => !cleanReturnedNames.includes(pName));

        if (missingPlayers.length > 0 && players.length > 1) {
            console.log(`⚠️ Başlatılamadı. Lobiye dönmeyen var: ${missingPlayers.join(', ')}`);
            socket.emit('vk_start_game_error', {
                message: `Tüm oyuncuların lobiye dönmesi bekleniyor! ⏳`
            });
            return;
        }

        // 🎯 2. ODA STATÜSÜNÜ GEÇİCİ OLARAK BEKLEMEDEN ÇIKARIP YENİDEN BAŞLATIYORUZ
        await redisClient.hset(roomKey, 'status', 'waiting');

        // 3. TEMİZLİK: Önceki turun verilerini sil
        await redisClient.del(`${roomKey}:vk_votes`);
        await redisClient.del(`${roomKey}:vk_locked_votes`);
        await redisClient.del(`${roomKey}:returned_players`);
        delete nightVotes[roomCode];
        await redisClient.del(`${roomKey}:roles_seen_players`);

        // 4. ROLLERİ SIFIRDAN DAĞIT KODU
        const result = await distributeAndSaveRoles(roomCode);

        if (result.error) {
            socket.emit('vk_start_game_error', { message: result.error });
            return;
        }

        // 🎯 5. BÜTÜN İSTEMCİLERE ANINDA YENİ OYUN SİNYALİ GÖNDER
        io.to(roomCode).emit('vk_game_started', { 
            players: result.players,
            timestamp: Date.now() // Ekranın yenilenmesini zorlamak için timestamp
        });
        
        io.to(roomCode).emit('vk_players_updated', result.players);
    });

    // ==========================================
    // 🃏 ROL KARTLARININ OKUNDUĞUNU VE HAZIRLIK DURUMUNU YÖNETME
    // ==========================================
    socket.on('vk_player_role_seen', async (data) => {
        const { roomCode, playerName } = data;
        if (!roomCode || !playerName) return;

        const roomKey = `room:${roomCode}`;
        const cleanName = playerName.toString().trim().toLowerCase();
        
        // Rolünü onaylayan oyuncunun temizlenmiş ismini Redis Set'e ekle
        await redisClient.sadd(`${roomKey}:roles_seen_players`, cleanName);

        const roomData = await redisClient.hgetall(roomKey);
        if (!roomData || !roomData.players) return;

        let players = JSON.parse(roomData.players || '[]');
        const seenPlayers = await redisClient.smembers(`${roomKey}:roles_seen_players`) || [];

        console.log(`🃏 [ROL ONAYI] Oda: ${roomCode} | Oyuncu: ${playerName} (${seenPlayers.length}/${players.length})`);

        // Herkes rolünü onayladıysa oyunu başlat
        if (seenPlayers.length >= players.length) {
            console.log(`🚀 [OYUN BAŞLIYOR] Tüm oyuncular rolünü onayladı! Kartlar kapatılıyor...`);
            
            // Onay sayacını temizle
            await redisClient.del(`${roomKey}:roles_seen_players`);

            // 1. Kartları kapatma emri gönder
            io.to(roomCode).emit('vk_all_roles_seen');

            // 2. Oyunu Gündüz fazına geçir
            io.to(roomCode).emit('vk_phase_changed', { phase: 'day' });
        }
    });

    socket.on('vk_get_players', async (data) => {
        const { roomCode } = data;
        const currentRoom = await redisClient.hgetall(`room:${roomCode}`);
        if (currentRoom && currentRoom.players) {
            const rawPlayers = JSON.parse(currentRoom.players);
            let playerObjects = rawPlayers.map(p => {
                if (typeof p === 'string') {
                    return { name: p, gender: 'male', isHost: p === currentRoom.host };
                }
                return p;
            });
            socket.emit('vk_players_updated', playerObjects);
        }
    });

    socket.on('start_voting', (data) => {
        const { roomCode } = data;
        console.log(`📣 [OYLAMA BAŞLADI] Host odayı oylamaya yönlendiriyor: ${roomCode}`);
        io.to(roomCode).emit('navigate_to_voting');
    });

    // GECE FAZI AKSİYON VE ORTAK MUTABAKAT YÖNETİMİ
    socket.on('submit_night_action', async (data) => {
        const { roomCode, playerName, role, target } = data;

        if (!nightVotes[roomCode]) {
            nightVotes[roomCode] = {
                vampires: {},
                killers: {},
                doctors: {},
                mathSolvedPlayers: []
            };
        }

        const roomData = await redisClient.hgetall(`room:${roomCode}`);
        const players = JSON.parse(roomData.players || '[]');
        const alivePlayers = players.filter(p => p.isAlive !== false);

        const rStr = role ? role.toString().toLowerCase() : '';

        if (rStr.includes('vampir')) {
            nightVotes[roomCode].vampires[playerName] = target;
        } else if (rStr.includes('seri') || rStr.includes('katil')) {
            nightVotes[roomCode].killers[playerName] = target;
        } else if (rStr.includes('doktor')) {
            nightVotes[roomCode].doctors[playerName] = target;
        } else {
            if (!nightVotes[roomCode].mathSolvedPlayers.includes(playerName)) {
                nightVotes[roomCode].mathSolvedPlayers.push(playerName);
            }
        }

        const vampireChoices = Object.values(nightVotes[roomCode].vampires);
        const uniqueVampireTargets = [...new Set(vampireChoices)];
        const totalVampiresInGame = alivePlayers.filter(p => p.role && p.role.toLowerCase().includes('vampir')).length;

        if (totalVampiresInGame > 0 && vampireChoices.length === totalVampiresInGame && uniqueVampireTargets.length > 1) {
            io.to(roomCode).emit('night_action_error', {
                roleTarget: 'Vampir',
                message: '⚠️ Vampirler anlaşamadı! Aynı kişiyi seçene kadar gece bitmeyecek.'
            });
            nightVotes[roomCode].vampires = {};
            return;
        }

        const killerChoices = Object.values(nightVotes[roomCode].killers);
        const uniqueKillerTargets = [...new Set(killerChoices)];
        const totalKillersInGame = alivePlayers.filter(p => p.role && (p.role.toLowerCase().includes('seri') || p.role.toLowerCase().includes('katil'))).length;

        if (totalKillersInGame > 0 && killerChoices.length === totalKillersInGame && uniqueKillerTargets.length > 1) {
            io.to(roomCode).emit('night_action_error', {
                roleTarget: 'Seri Katil',
                message: '⚠️ Seri katiller anlaşamadı! Ortak hedef seçmelisiniz.'
            });
            nightVotes[roomCode].killers = {};
            return;
        }

        socket.emit('action_confirmed', {
            message: 'Kararın onaylandı, diğer oyuncuların işlemleri tamamlaması bekleniyor...'
        });

        const totalActivePlayers = alivePlayers.length;
        const totalActionsReceived =
            Object.keys(nightVotes[roomCode].vampires).length +
            Object.keys(nightVotes[roomCode].killers).length +
            Object.keys(nightVotes[roomCode].doctors).length +
            nightVotes[roomCode].mathSolvedPlayers.length;

        io.to(roomCode).emit('night_progress_update', {
            completedCount: totalActionsReceived,
            totalCount: totalActivePlayers
        });

        if (totalActionsReceived >= totalActivePlayers) {
            const finalVampireTarget = uniqueVampireTargets[0] || null;
            const finalDoctorTarget = Object.values(nightVotes[roomCode].doctors)[0] || null;
            const finalKillerTarget = uniqueKillerTargets[0] || null;

            let rawDeadTargets = [];

            if (finalKillerTarget) {
                rawDeadTargets.push(finalKillerTarget.toString().trim().toLowerCase());
            }

            if (finalVampireTarget && finalVampireTarget !== finalDoctorTarget) {
                const cleanVampTarget = finalVampireTarget.toString().trim().toLowerCase();
                if (!rawDeadTargets.includes(cleanVampTarget)) {
                    rawDeadTargets.push(cleanVampTarget);
                }
            }

            let actualDeadNames = [];

            let updatedPlayers = players.map(p => {
                const pNameClean = (typeof p === 'object' ? p.name : p).toString().trim().toLowerCase();
                if (rawDeadTargets.includes(pNameClean)) {
                    actualDeadNames.push(typeof p === 'object' ? p.name : p);
                    return { ...p, isAlive: false };
                }
                return p;
            });

            updatedPlayers = await handleHostTransferIfNeeded(roomCode, updatedPlayers);
            await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(updatedPlayers));

            io.to(roomCode).emit('night_results', {
                deadPlayers: actualDeadNames,
                message: actualDeadNames.length > 0
                    ? `Sabah oldu! Gece kurbanı / kurbanları: ${actualDeadNames.join(', ')} 💀`
                    : "Mucize! Doktor köyü korumayı başardı, gece kimse ölmedi. 🩺"
            });
            io.to(roomCode).emit('vk_players_updated', updatedPlayers);

            const updatedAlive = updatedPlayers.filter(p => p.isAlive !== false);
            const aliveVampires = updatedAlive.filter(p => p.isVampire || (p.role && p.role.toLowerCase().includes('vampir'))).length;
            const aliveVillagers = updatedAlive.filter(p => !p.isVampire && !(p.role && p.role.toLowerCase().includes('vampir'))).length;

            console.log(`🌅 [SABAH ZAFER KONTROLÜ] Kalan Vampir: ${aliveVampires} | Kalan Köylü: ${aliveVillagers}`);

            if (aliveVampires === 0) {
                io.to(roomCode).emit('vk_game_over', {
                    winner: 'KÖYLÜLER',
                    eliminatedPlayer: actualDeadNames.join(', ') || 'Vampirler'
                });
            } else if (aliveVampires >= aliveVillagers) {
                io.to(roomCode).emit('vk_game_over', {
                    winner: 'VAMPİRLER',
                    eliminatedPlayer: actualDeadNames.join(', ') || 'Köy Kurbanı'
                });
            }

            delete nightVotes[roomCode];
        }
    });

    // 🎯 OYLAMA VE ELEME LOGIC BLOĞU (GARANTİLİ OY SAYIMI VE ELEME)
    socket.on('vk_submit_vote', async (data) => {
        const { roomCode, voterName, votedTargetName, votedFor, isLocking } = data;
        const actualTarget = votedTargetName || votedFor;

        const voteKey = `room:${roomCode}:vk_votes`;
        const lockKey = `room:${roomCode}:vk_locked_votes`;

        if (actualTarget) {
            await redisClient.hset(voteKey, voterName, actualTarget);
        }

        if (isLocking) {
            await redisClient.sadd(lockKey, voterName);
        }

        const roomData = await redisClient.hgetall(`room:${roomCode}`);
        let players = JSON.parse(roomData.players || '[]');
        const alivePlayers = players.filter(p => p.isAlive !== false);

        const currentVotes = await redisClient.hgetall(voteKey) || {};
        const lockedPlayers = await redisClient.smembers(lockKey) || [];

        io.to(roomCode).emit('vk_vote_status_updated', {
            votedCount: lockedPlayers.length,
            totalPlayers: alivePlayers.length,
            currentVotes: currentVotes,
            lockedPlayers: lockedPlayers
        });

        io.to(roomCode).emit('vk_vote_progress', {
            votedCount: lockedPlayers.length,
            totalAlive: alivePlayers.length,
            currentVotes: currentVotes
        });

        if (lockedPlayers.length >= alivePlayers.length) {
            const voteCounts = {};
            alivePlayers.forEach(p => {
                const pName = typeof p === 'object' ? p.name : p;
                voteCounts[pName.trim()] = 0;
            });

            Object.entries(currentVotes).forEach(([voter, voted]) => {
                if (voted && voted !== 'skip') {
                    const targetClean = voted.toString().trim();
                    const matchedKey = Object.keys(voteCounts).find(
                        k => k.toLowerCase() === targetClean.toLowerCase()
                    );
                    if (matchedKey) {
                        voteCounts[matchedKey]++;
                    }
                }
            });

            let eliminatedPlayerName = null;
            let eliminatedPlayerObj = null;
            let maxVotes = 0;
            let isTie = false;

            Object.entries(voteCounts).forEach(([player, count]) => {
                if (count > maxVotes) {
                    maxVotes = count;
                    eliminatedPlayerName = player;
                    isTie = false;
                } else if (count === maxVotes && count > 0) {
                    isTie = true;
                }
            });

            if (isTie) {
                eliminatedPlayerName = null;
            }

            let isVampire = false;

            if (eliminatedPlayerName) {
                players = players.map(p => {
                    const pName = typeof p === 'object' ? p.name : p;
                    if (pName && pName.toString().trim().toLowerCase() === eliminatedPlayerName.toString().trim().toLowerCase()) {
                        eliminatedPlayerObj = typeof p === 'object' ? p : { name: p, role: 'Köylü 🧑‍🌾' };
                        isVampire = !!eliminatedPlayerObj.isVampire || (eliminatedPlayerObj.role && eliminatedPlayerObj.role.toLowerCase().includes('vampir'));
                        return { ...eliminatedPlayerObj, isAlive: false };
                    }
                    return p;
                });

                players = await handleHostTransferIfNeeded(roomCode, players);
                await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(players));
            }

            await redisClient.del(voteKey);
            await redisClient.del(lockKey);

            const updatedAlive = players.filter(p => p.isAlive !== false);
            const aliveVampires = updatedAlive.filter(p => p.isVampire || (p.role && p.role.toLowerCase().includes('vampir'))).length;
            const aliveVillagers = updatedAlive.filter(p => !p.isVampire && !(p.role && p.role.toLowerCase().includes('vampir'))).length;

            console.log(`📊 [VK OYLAMA SONUCU] Elenen: ${eliminatedPlayerName} | Kalan Vampir: ${aliveVampires} | Kalan Köylü: ${aliveVillagers}`);

            if (aliveVampires === 0) {
                io.to(roomCode).emit('vk_game_over', {
                    winner: 'KÖYLÜLER',
                    eliminatedPlayer: eliminatedPlayerName
                });
            } else if (aliveVampires >= aliveVillagers) {
                io.to(roomCode).emit('vk_game_over', {
                    winner: 'VAMPİRLER',
                    eliminatedPlayer: eliminatedPlayerName
                });
            } else {
                io.to(roomCode).emit('vk_voting_results', {
                    eliminatedPlayer: eliminatedPlayerName,
                    eliminatedRole: eliminatedPlayerObj ? eliminatedPlayerObj.role : null,
                    isTie: isTie,
                    isVampire: isVampire,
                    players: players
                });
                io.to(roomCode).emit('vk_round_ended', {
                    eliminatedPlayer: eliminatedPlayerName,
                    eliminatedRole: eliminatedPlayerObj ? eliminatedPlayerObj.role : null,
                    isTie: isTie,
                    isVampire: isVampire,
                    players: players
                });
            }

            io.to(roomCode).emit('vk_players_updated', players);
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
        const { roomCode } = req.body;

        const result = await distributeAndSaveRoles(roomCode);

        if (result.error) {
            return res.status(400).json({ error: result.error });
        }

        const updatedPlayers = result.players;

        io.to(roomCode).emit('vk_game_started', { players: updatedPlayers });
        io.to(roomCode).emit('vk_players_updated', updatedPlayers);

        return res.json({
            status: "success",
            players: updatedPlayers
        });

    } catch (error) {
        console.error("Oyunu ilerletirken hata oluştu:", error);
        return res.status(500).json({ error: "Sunucu hatası" });
    }
});

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
    console.log(`Sunucu ${PORT} portunda hazır.`);
});