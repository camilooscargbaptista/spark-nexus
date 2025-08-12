const fs = require('fs');
const path = require('path');

console.log('🔧 Atualizando server.js com sistema de quota...\n');

const serverPath = path.join(__dirname, 'server.js');
const backupPath = path.join(__dirname, `backups/server.js.backup.${Date.now()}`);

// Fazer backup
if (!fs.existsSync(path.dirname(backupPath))) {
    fs.mkdirSync(path.dirname(backupPath), { recursive: true });
}
fs.copyFileSync(serverPath, backupPath);
console.log(`✅ Backup criado: ${backupPath}`);

// Ler arquivo atual
let serverContent = fs.readFileSync(serverPath, 'utf8');

// Verificar se já foi modificado
if (serverContent.includes('quotaMiddleware')) {
    console.log('⚠️  Sistema de quota já está instalado!');
    process.exit(0);
}

// 1. Adicionar imports após os requires existentes
const requiresEndIndex = serverContent.lastIndexOf("const ultimateValidator");
if (requiresEndIndex > -1) {
    const insertPoint = serverContent.indexOf('\n', requiresEndIndex) + 1;

    const quotaImports = `
// Sistema de Quota
const {
    checkQuota,
    quotaForSingle,
    quotaForBatch,
    quotaForUpload,
    getQuotaStats,
    resetQuotas
} = require('./middleware/quotaMiddleware');
const QuotaService = require('./services/QuotaService');
`;

    serverContent = serverContent.slice(0, insertPoint) + quotaImports + serverContent.slice(insertPoint);
    console.log('✅ Imports de quota adicionados');
}

// 2. Adicionar middleware nos endpoints de validação
const endpointsToUpdate = [
    {
        pattern: /app\.post\('\/api\/validate\/single',\s*authenticateToken,/g,
        replacement: "app.post('/api/validate/single', authenticateToken, quotaForSingle,"
    },
    {
        pattern: /app\.post\('\/api\/validate\/batch',\s*authenticateToken,/g,
        replacement: "app.post('/api/validate/batch', authenticateToken, quotaForBatch,"
    },
    {
        pattern: /app\.post\('\/api\/validate\/advanced',\s*authenticateToken,/g,
        replacement: "app.post('/api/validate/advanced', authenticateToken, quotaForSingle,"
    },
    {
        pattern: /app\.post\('\/api\/validate\/batch-with-report',\s*authenticateToken,/g,
        replacement: "app.post('/api/validate/batch-with-report', authenticateToken, quotaForBatch,"
    }
];

endpointsToUpdate.forEach(({ pattern, replacement }) => {
    if (serverContent.match(pattern)) {
        serverContent = serverContent.replace(pattern, replacement);
        console.log(`✅ Endpoint atualizado: ${replacement.split(',')[0]}`);
    }
});

// 3. Adicionar endpoints de quota após /api/auth/verify
const authVerifyIndex = serverContent.indexOf("app.get('/api/auth/verify'");
if (authVerifyIndex > -1) {
    const endOfAuthVerify = serverContent.indexOf('});', authVerifyIndex) + 3;

    const quotaEndpoints = `

// ================================================
// ENDPOINTS DE QUOTA
// ================================================

// Estatísticas de quota
app.get('/api/user/quota', authenticateToken, getQuotaStats);

// Resumo de quota
app.get('/api/user/quota/summary', authenticateToken, async (req, res) => {
    try {
        const quotaService = new QuotaService(db.pool, db.redis);
        const organization = await quotaService.getUserOrganization(req.user.id);

        if (!organization) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const quota = await quotaService.checkQuota(organization.id);
        res.json({
            organization: organization.name,
            plan: organization.plan,
            used: quota.used,
            limit: quota.limit,
            remaining: quota.remaining,
            percentage: Math.round((quota.used / quota.limit) * 100)
        });
    } catch (error) {
        res.status(500).json({ error: 'Erro ao buscar quota' });
    }
});
`;

    serverContent = serverContent.slice(0, endOfAuthVerify) + quotaEndpoints + serverContent.slice(endOfAuthVerify);
    console.log('✅ Endpoints de quota adicionados');
}

// 4. Tratamento especial para upload
const uploadPattern = /const validationResults = await Promise\.all\(validationPromises\);/g;
if (serverContent.match(uploadPattern)) {
    const uploadReplacement = `const validationResults = await Promise.all(validationPromises);

        // Verificar e consumir quota
        const quotaService = new QuotaService(db.pool, db.redis);
        const organization = await quotaService.getUserOrganization(req.user.id);

        if (organization) {
            const quotaCheck = await quotaService.checkQuota(organization.id, emails.length);
            if (!quotaCheck.allowed) {
                return res.status(429).json({
                    error: 'Limite de validações excedido',
                    details: quotaCheck
                });
            }

            // Incrementar uso
            await quotaService.incrementUsage(organization.id, emails.length);
            console.log(\`Quota consumida: \${emails.length} validações para \${organization.name}\`);
        }`;

    serverContent = serverContent.replace(uploadPattern, uploadReplacement);
    console.log('✅ Upload endpoint atualizado com verificação de quota');
}

// Salvar arquivo atualizado
fs.writeFileSync(serverPath, serverContent);
console.log('\n🎉 server.js atualizado com sucesso!');
console.log('📝 Por favor, verifique o arquivo e reinicie o servidor.');

