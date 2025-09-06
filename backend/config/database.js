const mysql = require('mysql2/promise');
require('dotenv').config();

let connection;

const connectDB = async () => {
  try {
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 3306,
      user: process.env.DB_USER || 'walkicar',
      password: process.env.DB_PASSWORD || 'ck491#9Kd',
      database: process.env.DB_NAME || 'walkicar',
      charset: 'utf8mb4',
      timezone: '+00:00'
    });

    console.log('✅ MySQL Datenbank verbunden');
    return connection;
  } catch (error) {
    console.error('❌ Datenbankverbindung fehlgeschlagen:', error.message);
    throw error;
  }
};

const getConnection = () => {
  if (!connection) {
    throw new Error('Datenbankverbindung nicht initialisiert');
  }
  return connection;
};

const query = async (sql, params = []) => {
  try {
    const conn = getConnection();
    const [rows] = await conn.execute(sql, params);
    return rows;
  } catch (error) {
    console.error('Datenbankfehler:', error);
    throw error;
  }
};

const transaction = async (queries) => {
  const conn = getConnection();
  await conn.beginTransaction();
  
  try {
    const results = [];
    for (const { sql, params } of queries) {
      const [rows] = await conn.execute(sql, params);
      results.push(rows);
    }
    await conn.commit();
    return results;
  } catch (error) {
    await conn.rollback();
    throw error;
  }
};

module.exports = {
  connectDB,
  getConnection,
  query,
  transaction
};
