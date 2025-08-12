const fs = require('fs');

console.log('🔧 Iniciando correção automática do endpoint upload...\n');

try {
    // Ler arquivo
    let content = fs.readFileSync('server.js', 'utf8');

    // Verificar se já tem quota no upload
    if (content.includes('// SISTEMA DE QUOTA NO UPLOAD')) {
        console.log('✅ Sistema de quota já está presente no upload');
        process.exit(0);
    }

    // Encontrar a linha específica onde adicionar o código
    const targetLine = 'const validationResults = await Promise.all(validationPromises);';
    const targetIndex = content.indexOf(targetLine);

    if (targetIndex === -1) {
        console.error('❌ Não foi possível encontrar o ponto de inserção');
        process.exit(1);
    }

    // Encontrar o fim da linha
    const lineEnd = content.indexOf('\n', targetIndex) + 1;

    // Código de quota a ser inserido
    const quotaCode = `
        // ================================================
        // SISTEMA DE QUOTA NO UPLOAD
        // ================================================
        let quotaInfo = null;
        try {
            const QuotaService = require('./services/QuotaService');
            const quotaService = new QuotaService(db.pool, db.redis);
            const organization = await quotaService.getUserOrganization(req.user.id);

            if (organization) {
                const quotaCheck = await quotaService.checkQuota(organization.id, emails.length);

                if (!quotaCheck.allowed) {
                    console.log(\`[QUOTA] Upload bloqueado - Limite excedido para \${organization.name}\`);
                    return res.status(429).json({
                        error: 'Limite de validações excedido',
                        code: 'QUOTA_EXCEEDED',
                        details: {
                            message: \`Você tem apenas \${quotaCheck.remaining} validações restantes, mas tentou validar \${emails.length} emails\`,
                            limit: quotaCheck.limit,
                            used: quotaCheck.used,
                            remaining: quotaCheck.remaining,
                            requested: emails.length,
                            plan: organization.plan
                        },
                        suggestions: [
                            'Reduza a quantidade de emails no arquivo',
                            'Aguarde até o próximo período de faturamento',
                            'Faça upgrade do seu plano para aumentar o limite'
                        ]
                    });
                }

                const incrementResult = await quotaService.incrementUsage(organization.id, emails.length);
                console.log(\`[QUOTA] Upload: \${emails.length} validações consumidas. Restam: \${incrementResult.remaining}\`);

                quotaInfo = {
                    used: emails.length,
                    remaining: incrementResult.remaining,
                    limit: organization.max_validations,
                    plan: organization.plan
                };

                res.set({
                    'X-RateLimit-Limit': organization.max_validations,
                    'X-RateLimit-Remaining': incrementResult.remaining,
                    'X-RateLimit-Used': organization.validations_used + emails.length
                });
            }
        } catch (quotaError) {
            console.error('[QUOTA] Erro no sistema de quota:', quotaError.message);
        }
        // FIM DO SISTEMA DE QUOTA
`;

    // Inserir código de quota
    content = content.slice(0, lineEnd) + quotaCode + content.slice(lineEnd);
    console.log('✅ Código de quota inserido após validationResults');

    // Agora adicionar quotaInfo no res.json
    // Procurar pelo res.json específico do upload
    const resJsonPattern = /res\.json\(\{[\s\S]*?success:\s*true,[\s\S]*?message:\s*`.*?emails validados[\s\S]*?\}\);/;
    const resJsonMatch = content.match(resJsonPattern);

    if (resJsonMatch) {
        const originalJson = resJsonMatch[0];
        // Adicionar quota: quotaInfo antes do fechamento
        const modifiedJson = originalJson.replace(
            /(\s*)\}\);$/,
            ',\n$1    quota: quotaInfo\n$1});'
        );
        content = content.replace(originalJson, modifiedJson);
        console.log('✅ Campo quota adicionado na resposta JSON');
    } else {
        console.log('⚠️  Não foi possível adicionar campo quota na resposta (não crítico)');
    }

    // Salvar arquivo
    fs.writeFileSync('server.js', content);
    console.log('✅ Arquivo server.js atualizado com sucesso!');

    // Verificar sintaxe
    const { execSync } = require('child_process');
    try {
        execSync('node -c server.js', { stdio: 'pipe' });
        console.log('✅ Sintaxe verificada com sucesso!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Erro de sintaxe detectado');
        throw error;
    }

} catch (error) {
    console.error('❌ Erro durante a correção:', error.message);

    // Tentar restaurar backup
    try {
        const { execSync } = require('child_process');
        const backups = execSync('ls -t server.js.backup.* 2>/dev/null | head -1', { encoding: 'utf8' }).trim();
        if (backups) {
            execSync(`cp ${backups} server.js`);
            console.log('✅ Backup restaurado');
        }
    } catch (e) {
        console.error('❌ Não foi possível restaurar backup');
    }

    process.exit(1);
}
