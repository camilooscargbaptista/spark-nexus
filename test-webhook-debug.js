// test-webhook-debug.js

const DatabaseService = require('./core/client-dashboard/services/database');
const dbService = new DatabaseService();
const pool = dbService.pool;

async function testTransactionCreation() {
    console.log('🧪 TESTE DE CRIAÇÃO DE TRANSAÇÃO');
    console.log('================================');
    
    const client = await pool.connect();
    
    try {
        await client.query('BEGIN');
        
        // 1. Buscar um checkout pendente ou completo
        const checkoutResult = await client.query(`
            SELECT pc.*, p.name as plan_name, p.price 
            FROM billing.pending_checkouts pc
            JOIN billing.plans p ON pc.plan_id = p.id
            ORDER BY pc.created_at DESC 
            LIMIT 1
        `);
        
        if (checkoutResult.rows.length === 0) {
            console.log('❌ Nenhum checkout encontrado');
            return;
        }
        
        const checkout = checkoutResult.rows[0];
        console.log('✅ Checkout encontrado:', checkout.stripe_session_id);
        console.log('   Status:', checkout.status);
        console.log('   Plano:', checkout.plan_name);
        
        // 2. Verificar se já existe transação
        const existingTrans = await client.query(`
            SELECT COUNT(*) as count 
            FROM billing.transactions 
            WHERE organization_id = $1 
            AND DATE(created_at) = DATE($2)
        `, [checkout.organization_id, checkout.created_at]);
        
        console.log('   Transações existentes:', existingTrans.rows[0].count);
        
        // 3. Criar transação de teste
        console.log('\n📝 Criando transação de teste...');
        
        const insertResult = await client.query(`
            INSERT INTO billing.transactions 
            (organization_id, type, status, amount, currency, description, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, NOW())
            RETURNING *
        `, [
            checkout.organization_id,
            'payment',
            'completed',
            checkout.price,
            'BRL',
            `Teste - ${checkout.plan_name}`
        ]);
        
        console.log('✅ TRANSAÇÃO CRIADA COM SUCESSO!');
        console.log('   ID:', insertResult.rows[0].id);
        console.log('   Valor:', insertResult.rows[0].amount);
        
        await client.query('COMMIT');
        
        // 4. Verificar se foi salva
        const verifyResult = await client.query(`
            SELECT * FROM billing.transactions 
            WHERE id = $1
        `, [insertResult.rows[0].id]);
        
        if (verifyResult.rows.length > 0) {
            console.log('\n✅ TRANSAÇÃO CONFIRMADA NO BANCO!');
            console.log(verifyResult.rows[0]);
        } else {
            console.log('❌ Transação não encontrada após commit');
        }
        
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('❌ ERRO:', error);
        console.error('Detalhes:', error.detail);
        console.error('Stack:', error.stack);
    } finally {
        client.release();
        process.exit();
    }
}

testTransactionCreation();