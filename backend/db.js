// backend/db.js
const mysql = require('mysql2');

// MySQL Bağlantı Havuzu (Pool) oluşturuyoruz kanka.
// Bu yapı, her sorgu için sıfırdan bağlantı açıp kapatmak yerine hazır bağlantıları elinde tutarak performansı artırır.
const pool = mysql.createPool({
    host: 'localhost',       // Lokalinde çalıştığın için localhost
    user: 'root',            // MySQL kullanıcı adın (varsayılan olarak root)
    password: '1234', // MySQL kurarken belirlediğin şifreni buraya yaz!
    database: 'impostor_game', // Workbench'te oluşturduğumuz veri tabanı adı
    waitForConnections: true,
    connectionLimit: 10,     // Aynı anda en fazla 10 aktif bağlantı kuyrukta bekleyebilir
    queueLimit: 0
});

// Kodlarımızda modern "async/await" yapısını kullanabilmek için promise versiyonunu dışa aktarıyoruz.
module.exports = pool.promise();