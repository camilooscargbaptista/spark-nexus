// ================================================
// Teste do Sistema de Validação Avançado
// ================================================

const axios = require('axios');

const API_URL = 'http://localhost:4201';

// Cores para console
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

// Lista de emails para testar
const testEmails = [
    { email: 'valid@gmail.com', expected: 'valid' },
    { email: 'ceo@microsoft.com', expected: 'valid' },
    { email: 'test@tempmail.com', expected: 'disposable' },
    { email: 'admin@company.com', expected: 'role-based' },
    { email: 'user@gmial.com', expected: 'typo' },
    { email: 'invalido@', expected: 'invalid' },
    { email: 'fake123@mailinator.com', expected: 'disposable' },
    { email: 'joão.silva@empresa.com.br', expected: 'valid' }
];

async function testQuickValidation() {
    console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
    console.log(`${colors.blue}🧪 Testando Validação Rápida (Pública)${colors.reset}`);
    console.log(`${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

    for (const test of testEmails) {
        try {
            const response = await axios.post(`${API_URL}/api/validate/quick`, {
                email: test.email
            });

            const { valid, score, risk } = response.data;
            const icon = valid ? '✅' : '❌';
            const color = valid ? colors.green : colors.red;

            console.log(`${icon} ${test.email}`);
            console.log(`   ${color}Valid: ${valid} | Score: ${score}/100 | Risk: ${risk}${colors.reset}`);

            if (test.expected === 'typo' && response.data.suggestions) {
                console.log(`   ${colors.yellow}💡 Sugestão: ${response.data.suggestions}${colors.reset}`);
            }
        } catch (error) {
            console.log(`❌ ${test.email}`);
            console.log(`   ${colors.red}Erro: ${error.response?.data?.error || error.message}${colors.reset}`);
        }

        // Delay para não sobrecarregar
        await new Promise(resolve => setTimeout(resolve, 100));
    }
}

async function testBatchValidation() {
    console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
    console.log(`${colors.blue}🧪 Testando Validação em Lote${colors.reset}`);
    console.log(`${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

    const emails = testEmails.map(t => t.email);

    try {
        // Primeiro fazer login para obter token (usar credenciais de demo)
        console.log('🔐 Fazendo login...');
        const loginResponse = await axios.post(`${API_URL}/api/auth/login`, {
            email: 'demo@sparknexus.com',
            password: 'Demo@123456'
        });

        const token = loginResponse.data.token;
        console.log(`${colors.green}✅ Login realizado${colors.reset}\n`);

        // Enviar lote
        console.log('📦 Enviando lote de emails...');
        const batchResponse = await axios.post(
            `${API_URL}/api/validate/batch`,
            { emails, options: { checkMX: true } },
            { headers: { 'Authorization': `Bearer ${token}` } }
        );

        const { jobId, total } = batchResponse.data;
        console.log(`${colors.green}✅ Job criado: ${jobId}${colors.reset}`);
        console.log(`   Total de emails: ${total}\n`);

        // Aguardar processamento
        console.log('⏳ Aguardando processamento...');
        await new Promise(resolve => setTimeout(resolve, 3000));

        // Verificar status
        const statusResponse = await axios.get(
            `${API_URL}/api/validate/job/${jobId}`,
            { headers: { 'Authorization': `Bearer ${token}` } }
        );

        if (statusResponse.data.status === 'completed') {
            const { summary } = statusResponse.data;
            console.log(`${colors.green}✅ Processamento concluído!${colors.reset}`);
            console.log(`   Válidos: ${summary.valid}`);
            console.log(`   Inválidos: ${summary.invalid}`);
            console.log(`   Score médio: ${summary.avgScore.toFixed(2)}/100`);
        } else {
            console.log(`${colors.yellow}⚠️ Status: ${statusResponse.data.status}${colors.reset}`);
        }

    } catch (error) {
        console.log(`${colors.red}❌ Erro: ${error.response?.data?.error || error.message}${colors.reset}`);
    }
}

async function showAPIDocumentation() {
    console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
    console.log(`${colors.blue}📚 Documentação da API${colors.reset}`);
    console.log(`${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

    try {
        const response = await axios.get(`${API_URL}/api/validate/docs`);
        console.log(JSON.stringify(response.data, null, 2));
    } catch (error) {
        console.log(`${colors.red}❌ Erro ao buscar documentação${colors.reset}`);
    }
}

// Executar testes
async function runTests() {
    console.log(`${colors.cyan}════════════════════════════════════════${colors.reset}`);
    console.log(`${colors.blue}🚀 SPARK NEXUS - Teste do Validador Avançado${colors.reset}`);
    console.log(`${colors.cyan}════════════════════════════════════════${colors.reset}`);

    await testQuickValidation();
    await testBatchValidation();
    await showAPIDocumentation();

    console.log(`\n${colors.green}✨ Testes concluídos!${colors.reset}\n`);
}

// Verificar se o servidor está rodando
axios.get(`${API_URL}/api/health`)
    .then(() => {
        runTests();
    })
    .catch(() => {
        console.log(`${colors.red}❌ Servidor não está rodando em ${API_URL}${colors.reset}`);
        console.log(`${colors.yellow}Execute: npm start${colors.reset}`);
    });
