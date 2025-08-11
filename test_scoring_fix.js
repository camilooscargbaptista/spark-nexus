// Script de teste para validar as correções

// Ajustar o caminho baseado na localização real do arquivo
const path = require('path');
const fs = require('fs');

// Procurar o arquivo EcommerceScoring.js
let scoringPath;
const possiblePaths = [
    './core/client-dashboard/services/validators/advanced/EcommerceScoring.js',
    './core/client-dashboard/services/EcommerceScoring.js',
    './core/client-dashboard/src/services/EcommerceScoring.js',
    './core/client-dashboard/lib/EcommerceScoring.js'
];

for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
        scoringPath = p;
        break;
    }
}

if (!scoringPath) {
    console.error('❌ Não foi possível encontrar EcommerceScoring.js');
    process.exit(1);
}

const EcommerceScoring = require(scoringPath);

console.log('\n========================================');
console.log('🧪 TESTANDO SISTEMA DE SCORING CORRIGIDO');
console.log('========================================\n');

const scorer = new EcommerceScoring();

// Casos de teste
const testCases = [
    {
        name: 'Gmail válido (Carolina)',
        data: {
            email: 'carolinacasaquia@gmail.com',
            tld: { valid: true, isPremium: true },
            disposable: { isDisposable: false },
            smtp: { exists: true, catchAll: false },
            mx: { valid: true, records: 5 },
            patterns: { suspicious: false, suspicionLevel: 0 }
        },
        expected: 'Score > 80'
    },
    {
        name: 'Email sem domínio confiável',
        data: {
            email: 'teste@empresa.com.br',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: true },
            mx: { valid: true },
            patterns: { suspicious: false }
        },
        expected: 'Score 60-80'
    },
    {
        name: 'Email temporário',
        data: {
            email: 'test@tempmail.com',
            tld: { valid: true },
            disposable: { isDisposable: true },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 8 }
        },
        expected: 'Score < 20'
    },
    {
        name: 'Outlook com SMTP bloqueado (fallback)',
        data: {
            email: 'joao.silva@outlook.com',
            tld: { valid: true, isPremium: true },
            disposable: { isDisposable: false },
            smtp: { exists: false, error: 'Connection timeout' },
            mx: { valid: true },
            patterns: { suspicious: false }
        },
        expected: 'Score > 70 (com fallback)'
    }
];

// Executar testes
testCases.forEach((test, index) => {
    console.log(`\nTeste ${index + 1}: ${test.name}`);
    console.log(`Email: ${test.data.email}`);
    
    const result = scorer.calculateScore(test.data);
    
    console.log(`Score Final: ${result.finalScore}/100`);
    console.log(`Tipo: ${result.buyerType}`);
    console.log(`Risco: ${result.riskLevel}`);
    console.log(`Domínio Confiável: ${result.metadata.isTrustedDomain}`);
    console.log(`Categoria: ${result.metadata.domainCategory}`);
    console.log(`Esperado: ${test.expected}`);
    
    // Validar resultado
    const passed = (
        (test.expected.includes('> 80') && result.finalScore > 80) ||
        (test.expected.includes('60-80') && result.finalScore >= 60 && result.finalScore <= 80) ||
        (test.expected.includes('< 20') && result.finalScore < 20) ||
        (test.expected.includes('> 70') && result.finalScore > 70)
    );
    
    console.log(`Resultado: ${passed ? '✅ PASSOU' : '❌ FALHOU'}`);
    
    // Mostrar breakdown
    if (process.env.SHOW_BREAKDOWN === 'true') {
        console.log('\nBreakdown:');
        Object.entries(result.breakdown).forEach(([key, value]) => {
            console.log(`  ${key}: ${value.points}/10 (peso: ${value.weight})`);
        });
    }
});

console.log('\n========================================');
console.log('📊 TESTE ESPECÍFICO: carolinacasaquia@gmail.com');
console.log('========================================\n');

const carolinaTest = {
    email: 'carolinacasaquia@gmail.com',
    tld: { valid: true, isPremium: true },
    disposable: { isDisposable: false },
    smtp: { exists: true },
    mx: { valid: true, records: 5 },
    patterns: { suspicious: false }
};

const carolinaResult = scorer.calculateScore(carolinaTest);

console.log('Resultado Detalhado:');
console.log(`  Email: ${carolinaResult.metadata.email}`);
console.log(`  Domínio: ${carolinaResult.metadata.domain}`);
console.log(`  É Confiável: ${carolinaResult.metadata.isTrustedDomain}`);
console.log(`  Categoria: ${carolinaResult.metadata.domainCategory}`);
console.log(`  Score Base: ${carolinaResult.baseScore}`);
console.log(`  Score Final: ${carolinaResult.finalScore}`);
console.log(`  Classificação: ${carolinaResult.buyerType}`);
console.log(`  Nível de Risco: ${carolinaResult.riskLevel}`);
console.log(`  Confiança: ${carolinaResult.confidence}`);

console.log('\nRecomendações:');
carolinaResult.recommendations.forEach(rec => {
    console.log(`  [${rec.priority}] ${rec.action}: ${rec.message}`);
});

if (carolinaResult.finalScore >= 80) {
    console.log('\n✅ SUCESSO! Carolina agora tem score alto como esperado!');
} else {
    console.log('\n❌ PROBLEMA: Score ainda está baixo');
}

console.log('\n========================================\n');
