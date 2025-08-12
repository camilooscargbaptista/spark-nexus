const fs = require('fs');

console.log('Corrigindo endpoint de upload...');

let content = fs.readFileSync('server.js', 'utf8');

// Localizar o endpoint de upload
const uploadStart = content.indexOf("app.post('/api/upload'");
const uploadEnd = content.indexOf('});', content.indexOf('res.json({', uploadStart)) + 3;

if (uploadStart === -1) {
    console.error('❌ Endpoint de upload não encontrado!');
    process.exit(1);
}

// Extrair o endpoint atual
const currentUpload = content.substring(uploadStart, uploadEnd);

// Verificar se já tem quota implementada
if (currentUpload.includes('quotaService.incrementUsage')) {
    console.log('✅ Quota já está implementada no upload');
    process.exit(0);
}

// Criar versão corrigida do endpoint
const fixedUpload = `app.post('/api/upload', authenticateToken, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Nenhum arquivo enviado' });
        }

        // Buscar dados completos do usuário
        const userData = await getUserFullData(req.user.id);

        if (!userData) {
            return res.status(404).json({ error: 'Dados do usuário não encontrados' });
        }

        console.log('Dados do usuário recuperados:', userData);

        // Processar arquivo
        const fs = require('fs').promises;
        const csvContent = await fs.readFile(req.file.path, 'utf-8');
        const lines = csvContent.split('\n').filter(line => line.trim());
        const emails = [];

        for (let i = 1; i < lines.length; i++) {
            const values = lines[i].split(',').map(v => v.trim());
            if (values[0]) {
                emails.push(values[0]);
            }
        }

        // Limpar arquivo temporário
        await fs.unlink(req.file.path);

        // ================================================
        // VERIFICAR E CONSUMIR QUOTA
        // ================================================
        try {
            const QuotaService = require('./services/QuotaService');
            const quotaService = new QuotaService(db.pool, db.redis);

            // Buscar organização do usuário
            const organization = await quotaService.getUserOrganization(req.user.id);

            if (organization) {
                // Verificar se tem quota suficiente
                const quotaCheck = await quotaService.checkQuota(organization.id, emails.length);

                if (!quotaCheck.allowed) {
                    return res.status(429).json({
                        error: 'Limite de validações excedido',
                        code: 'QUOTA_EXCEEDED',
                        details: {
                            message: quotaCheck.message,
                            limit: quotaCheck.limit,
                            used: quotaCheck.used,
                            remaining: quotaCheck.remaining,
                            requested: emails.length,
                            plan: organization.plan
                        },
                        suggestions: [
                            'Reduza a quantidade de emails no arquivo',
                            'Aguarde até o próximo período de faturamento',
                            'Faça upgrade do seu plano'
                        ]
                    });
                }

                console.log(\`[QUOTA] Processando \${emails.length} emails para \${organization.name}\`);
            }
        } catch (quotaError) {
            console.error('[QUOTA] Erro ao verificar quota:', quotaError.message);
            // Continuar sem quota se houver erro
        }

        // Criar job de validação
        const jobId = uuidv4();

        // Processar emails com validador aprimorado
        console.log(\`Iniciando validação de \${emails.length} emails...\`);
        const validationPromises = emails.map(email => ultimateValidator.validateEmail(email));
        const validationResults = await Promise.all(validationPromises);

        console.log('Resultados da validação:', validationResults);

        // ================================================
        // INCREMENTAR QUOTA APÓS SUCESSO
        // ================================================
        try {
            const QuotaService = require('./services/QuotaService');
            const quotaService = new QuotaService(db.pool, db.redis);
            const organization = await quotaService.getUserOrganization(req.user.id);

            if (organization) {
                const incrementResult = await quotaService.incrementUsage(organization.id, emails.length);
                console.log(\`[QUOTA] Incrementado \${emails.length} validações. Restam: \${incrementResult.remaining}\`);

                // Adicionar headers de quota na resposta
                res.set({
                    'X-RateLimit-Limit': organization.max_validations,
                    'X-RateLimit-Remaining': incrementResult.remaining,
                    'X-RateLimit-Used': organization.validations_used + emails.length
                });
            }
        } catch (quotaError) {
            console.error('[QUOTA] Erro ao incrementar uso:', quotaError.message);
        }

        // Preparar informações do usuário para o relatório
        const userInfo = {
            name: userData.fullName,
            email: userData.email,
            company: userData.company,
            phone: userData.phone
        };

        // Gerar e enviar relatório para o email do usuário
        console.log(\`Enviando relatório para: \${userData.email}\`);
        const reportResult = await reportEmailService.generateAndSendReport(
            validationResults,
            userData.email, // Email do usuário autenticado
            userInfo
        );

        console.log('Resultado do relatório:', reportResult);

        // Estatísticas
        const validCount = validationResults.filter(r => r.valid).length;
        const avgScore = validationResults.reduce((acc, r) => acc + r.score, 0) / validationResults.length;

        res.json({
            success: true,
            message: \`\${emails.length} emails validados com sucesso! O relatório será enviado por e-mail.\`,
            jobId,
            user: {
                name: userData.fullName,
                email: userData.email,
                company: userData.company
            },
            stats: {
                total: emails.length,
                valid: validCount,
                invalid: emails.length - validCount,
                averageScore: Math.round(avgScore)
            },
            reportSent: true,
            reportDetails: {
                sentTo: userData.email,
                filename: reportResult.filename,
                sentAt: new Date().toISOString()
            }
        });
    } catch (error) {
        console.error('Erro no upload:', error);
        res.status(500).json({ error: 'Erro ao processar arquivo' });
    }
})`;

// Substituir o endpoint
content = content.substring(0, uploadStart) + fixedUpload + content.substring(uploadEnd);

// Salvar
fs.writeFileSync('server.js', content);

console.log('✅ Endpoint de upload corrigido com verificação e incremento de quota!');

// Verificar sintaxe
const { execSync } = require('child_process');
try {
    execSync('node -c server.js', { stdio: 'pipe' });
    console.log('✅ Sintaxe verificada com sucesso!');
} catch (error) {
    console.error('❌ Erro de sintaxe! Restaurando backup...');
    execSync('cp server.js.backup.upload.* server.js');
    process.exit(1);
}
