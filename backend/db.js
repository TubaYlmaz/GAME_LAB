// backend/db.js
require('dotenv').config();
const mysql = require('mysql2');

const connectionLimit = Number.parseInt(
    process.env.DB_CONNECTION_LIMIT || '10',
    10
);
const commonOptions = {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number.parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER || 'game_lab',
    password: process.env.DB_PASSWORD || '',
    waitForConnections: true,
    connectionLimit: Number.isFinite(connectionLimit) ? connectionLimit : 10,
    queueLimit: 0
};

// 1. Impostor Oyunu için Bağlantı Havuzu
const impostorPool = mysql.createPool({
    ...commonOptions,
    database: process.env.DB_IMPOSTOR_DATABASE || 'impostor_game'
});

// 2. Vampir Köylü Oyunu için Bağlantı Havuzu (YENİ)
const vampirPool = mysql.createPool({
    ...commonOptions,
    database: process.env.DB_VAMPIRE_DATABASE || 'vampir_koylu_game'
});

// İkisini de projede rahatça kullanabilmek için dışa aktarıyoruz (Promise desteğiyle)
module.exports = {
    impostorDb: impostorPool.promise(),
    vampirDb: vampirPool.promise()
};
