// ================================================
// TESTE DO SISTEMA ENHANCED DE VALIDAÇÃO
// ================================================

const path = require('path');
const fs = require('fs');

// Localizar o arquivo
const scoringPath = './core/client-dashboard/services/validators/advanced/EcommerceScoring_Enhanced.js';

if (!fs.existsSync(scoringPath)) {
    console.error('❌ Arquivo EcommerceScoring_Enhanced.js não encontrado!');
    process.exit(1);
}

const EcommerceScoring = require(scoringPath);
const scorer = new EcommerceScoring();

console.log('\n========================================');
console.log('🧪 TESTE DO SISTEMA ENHANCED DE VALIDAÇÃO');
console.log('========================================\n');

// Casos de teste que devem ser BLOQUEADOS ou ter score baixo
const testCases = [
    // DEVEM SER BLOQUEADOS (Score 0)
    {
        name: 'Domínio example.com',
        email: 'test@example.com',
        data: {
            email: 'test@example.com',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: false },
            patterns: { suspicious: false }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    {
        name: 'Email temporário (tempmail)',
        email: 'admin@tempmail.com',
        data: {
            email: 'admin@tempmail.com',
            tld: { valid: true },
            disposable: { isDisposable: true },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 8 }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    {
        name: '10minutemail',
        email: 'support@10minutemail.com',
        data: {
            email: 'support@10minutemail.com',
            tld: { valid: true },
            disposable: { isDisposable: true },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 8 }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    {
        name: 'Domínio fake (company.com)',
        email: 'user@company.com',
        data: {
            email: 'user@company.com',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: false },
            patterns: { suspicious: false }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    {
        name: 'Disposable óbvio',
        email: 'info@disposable.com',
        data: {
            email: 'info@disposable.com',
            tld: { valid: true },
            disposable: { isDisposable: true },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 9 }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    
    // DEVEM TER SCORE BAIXO (< 50)
    {
        name: 'Email genérico suspeito',
        email: 'test123@randomdomain.net',
        data: {
            email: 'test123@randomdomain.net',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 6 }
        },
        expectedValid: false,
        expectedMaxScore: 50
    },
    
    // EMAILS VÁLIDOS (Score > 70)
    {
        name: 'Gmail válido (Carolina)',
        email: 'carolinacasaquia@gmail.com',
        data: {
            email: 'carolinacasaquia@gmail.com',
            tld: { valid: true, isPremium: true },
            disposable: { isDisposable: false },
            smtp: { exists: true },
            patterns: { suspicious: false }
        },
        expectedValid: true,
        expectedMinScore: 70
    },
    {
        name: 'Outlook válido',
        email: 'real.person@outlook.com',
        data: {
            email: 'real.person@outlook.com',
            tld: { valid: true, isPremium: true },
            disposable: { isDisposable: false },
            smtp: { exists: true },
            patterns: { suspicious: false }
        },
        expectedValid: true,
        expectedMinScore: 70
    },
    {
        name: 'Email corporativo brasileiro',
        email: 'contato@empresa.com.br',
        data: {
            email: 'contato@empresa.com.br',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: true, catchAll: true },
            patterns: { suspicious: false }
        },
        expectedValid: true,
        expectedMinScore: 60
    }
];

// Executar testes
let passed = 0;
let failed = 0;

testCases.forEach((test, index) => {
    console.log(`\n${index + 1}. ${test.name}`);
    console.log(`   Email: ${test.email}`);
    
    const result = scorer.calculateScore(test.data);
    
    console.log(`   Score: ${result.finalScore}/100`);
    console.log(`   Válido: ${result.valid ? '✅' : '❌'}`);
    console.log(`   Classificação: ${result.buyerType}`);
    console.log(`   Risco: ${result.riskLevel}`);
    
    // Verificar se passou no teste
    let testPassed = true;
    
    if (test.expectedValid !== undefined) {
        if (result.valid !== test.expectedValid) {
            testPassed = false;
            console.log(`   ❌ FALHOU: Esperado válido=${test.expectedValid}, obteve ${result.valid}`);
        }
    }
    
    if (test.expectedMaxScore !== undefined) {
        if (result.finalScore > test.expectedMaxScore) {
            testPassed = false;
            console.log(`   ❌ FALHOU: Score máximo esperado ${test.expectedMaxScore}, obteve ${result.finalScore}`);
        }
    }
    
    if (test.expectedMinScore !== undefined) {
        if (result.finalScore < test.expectedMinScore) {
            testPassed = false;
            console.log(`   ❌ FALHOU: Score mínimo esperado ${test.expectedMinScore}, obteve ${result.finalScore}`);
        }
    }
    
    if (testPassed) {
        console.log(`   ✅ PASSOU`);
        passed++;
    } else {
        failed++;
    }
    
    // Mostrar razão se foi bloqueado
    if (result.metadata && result.metadata.isBlocked) {
        console.log(`   🚫 Bloqueado: ${result.breakdown.blocked.reason}`);
    }
});

// Resumo
console.log('\n========================================');
console.log('📊 RESUMO DOS TESTES');
console.log('========================================');
console.log(`✅ Passou: ${passed}/${testCases.length}`);
console.log(`❌ Falhou: ${failed}/${testCases.length}`);

if (failed === 0) {
    console.log('\n🎉 TODOS OS TESTES PASSARAM! Sistema funcionando corretamente!');
} else {
    console.log('\n⚠️  Alguns testes falharam. Verifique os resultados acima.');
}

// Teste específico dos problemáticos
console.log('\n========================================');
console.log('🔍 TESTE ESPECÍFICO DOS EMAILS PROBLEMÁTICOS');
console.log('========================================\n');

const problematicEmails = [
    'test@example.com',
    'admin@tempmail.com',
    'user@company.com',
    'support@10minutemail.com',
    'info@disposable.com'
];

problematicEmails.forEach(email => {
    const result = scorer.calculateScore({ 
        email: email,
        tld: { valid: true },
        disposable: { isDisposable: email.includes('mail') },
        smtp: { exists: false },
        patterns: { suspicious: true, suspicionLevel: 5 }
    });
    
    console.log(`${email}:`);
    console.log(`  Score: ${result.finalScore} | Válido: ${result.valid ? '✅' : '❌'} | Status: ${result.buyerType}`);
    
    if (result.valid) {
        console.log(`  ⚠️  PROBLEMA: Este email deveria ser inválido!`);
    }
});

console.log('\n========================================\n');
