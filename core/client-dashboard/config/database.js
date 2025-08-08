const { Pool } = require('pg');

// Detectar se está rodando dentro do Docker
const isDocker = process.env.DOCKER_ENV || process.env.NODE_ENV === 'production';

// Configuração do banco
const config = {
    // Usar 'postgres' quando dentro do Docker, '127.0.0.1' quando local
    host: process.env.DB_HOST || (isDocker ? 'postgres' : '127.0.0.1'),
    port: parseInt(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'sparknexus',
    user: process.env.DB_USER || 'sparknexus',
    password: process.env.DB_PASSWORD || 'SparkNexus2024!',
    
    // Configurações de pool
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
};

console.log('🔧 Database config:', {
    host: config.host,
    port: config.port,
    database: config.database,
    user: config.user,
    // Não logar a senha completa
    password: config.password ? '***' + config.password.slice(-4) : 'not set'
});

const pool = new Pool(config);

// Evento de erro
pool.on('error', (err) => {
    console.error('❌ Database pool error:', err);
});

// Testar conexão
pool.connect((err, client, release) => {
    if (err) {
        console.error('❌ Error connecting to PostgreSQL:', err.message);
        console.error('Config used:', {
            host: config.host,
            port: config.port,
            database: config.database,
            user: config.user
        });
    } else {
        console.log('✅ Connected to PostgreSQL successfully!');
        release();
    }
});

module.exports = pool;
