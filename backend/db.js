// backend/db.js
const mysql = require('mysql2');

// 1. Impostor Oyunu için Bağlantı Havuzu
const impostorPool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: 'My2003.SQL.root-',
    database: 'impostor_game',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// 2. Vampir Köylü Oyunu için Bağlantı Havuzu (YENİ)
const vampirPool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: 'My2003.SQL.root-',
    database: 'vampir_koylu_game', // Workbench'te oluşturduğun yeni veri tabanı adı
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// İkisini de projede rahatça kullanabilmek için dışa aktarıyoruz (Promise desteğiyle)
module.exports = {
    impostorDb: impostorPool.promise(),
    vampirDb: vampirPool.promise()
};