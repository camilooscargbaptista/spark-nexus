// ================================================
// Teste do Validador de Email
// ================================================

const EmailValidator = require('./services/validators');
const DatabaseService = require('./services/database');

async function test() {
    console.log('🧪 Iniciando teste do validador...\n');

    // Inicializar
    const db = new DatabaseService();
    const validator = new EmailValidator(db);

    // Emails para testar
    const testEmails = [
        'joao.silva@gmail.com',          // Válido
        'maria@empresa.com.br',           // Válido corporativo
        'test@tempmail.com',              // Disposable
        'admin@company.com',              // Role-based
        'user@gmial.com',                 // Typo
        'invalido@',                      // Inválido
        'test123456@mailinator.com',      // Disposable conhecido
        'ceo@microsoft.com'               // Corporativo
    ];

    console.log('Testando emails:\n');

    for (const email of testEmails) {
        console.log(`\n📧 ${email}`);
        console.log('─'.repeat(40));

        try {
            const result = await validator.validate(email, {
                checkMX: true,
                checkDisposable: true,
                detailed: true
            });

            console.log(`✓ Válido: ${result.valid ? '✅' : '❌'}`);
            console.log(`✓ Score: ${result.score}/100`);
            console.log(`✓ Risco: ${result.risk}`);
            console.log(`✓ Tempo: ${result.processingTime}ms`);

            if (result.details && result.details.suggestions.length > 0) {
                console.log(`💡 Sugestão: ${result.details.suggestions[0].suggested}`);
            }

        } catch (error) {
            console.error(`❌ Erro: ${error.message}`);
        }
    }

    console.log('\n\n✅ Teste concluído!');
    process.exit(0);
}

// Executar teste
test().catch(console.error);
