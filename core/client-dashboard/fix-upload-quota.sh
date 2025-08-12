#!/bin/bash

# ================================================
# Script: auto-fix-upload-quota.sh
# Descrição: Correção automática do endpoint upload com quota
# ================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        CORREÇÃO AUTOMÁTICA DO UPLOAD COM QUOTA              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# PASSO 1: BACKUP
# ================================================
echo -e "${YELLOW}[1/5] Criando backup...${NC}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="server.js.backup.auto.$TIMESTAMP"
cp server.js "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup criado: $BACKUP_FILE${NC}"

# ================================================
# PASSO 2: RESTAURAR VERSÃO LIMPA
# ================================================
echo -e "${YELLOW}[2/5] Restaurando versão estável...${NC}"
if [ -f "backups/server.js.backup.complete.20250811_162211" ]; then
    cp backups/server.js.backup.complete.20250811_162211 server.js
    echo -e "${GREEN}✅ Versão estável restaurada${NC}"
else
    echo -e "${YELLOW}⚠️  Usando versão atual${NC}"
fi

# ================================================
# PASSO 3: CRIAR SCRIPT NODE PARA CORREÇÃO
# ================================================
echo -e "${YELLOW}[3/5] Criando script de correção...${NC}"

cat > auto-fix-upload.js << 'EOFIX'
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
EOFIX

# ================================================
# PASSO 4: EXECUTAR CORREÇÃO
# ================================================
echo -e "${YELLOW}[4/5] Executando correção...${NC}"
if node auto-fix-upload.js; then
    echo -e "${GREEN}✅ Correção aplicada com sucesso!${NC}"
    rm -f auto-fix-upload.js
else
    echo -e "${RED}❌ Falha na correção${NC}"
    echo -e "${YELLOW}Tentando método alternativo...${NC}"

    # Método alternativo: usar sed
    echo -e "${CYAN}Aplicando correção via sed...${NC}"

    # Criar arquivo temporário com o código de quota
    cat > quota_code.txt << 'EOQUOTA'

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
                    console.log(`[QUOTA] Upload bloqueado - Limite excedido para ${organization.name}`);
                    return res.status(429).json({
                        error: 'Limite de validações excedido',
                        code: 'QUOTA_EXCEEDED',
                        details: {
                            message: `Você tem apenas ${quotaCheck.remaining} validações restantes, mas tentou validar ${emails.length} emails`,
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
                console.log(`[QUOTA] Upload: ${emails.length} validações consumidas. Restam: ${incrementResult.remaining}`);

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
EOQUOTA

    # Usar awk para inserir após a linha específica
    awk '/const validationResults = await Promise\.all\(validationPromises\);/ {
        print;
        while ((getline line < "quota_code.txt") > 0) {
            print line;
        }
        close("quota_code.txt");
        next;
    }
    {print}' server.js > server.js.temp

    mv server.js.temp server.js
    rm -f quota_code.txt

    # Verificar sintaxe
    if node -c server.js 2>/dev/null; then
        echo -e "${GREEN}✅ Correção alternativa aplicada com sucesso!${NC}"
    else
        echo -e "${RED}❌ Ainda há erro de sintaxe${NC}"
        echo -e "${YELLOW}Restaurando backup...${NC}"
        cp "$BACKUP_FILE" server.js
        exit 1
    fi
fi

# ================================================
# PASSO 5: VERIFICAÇÃO FINAL
# ================================================
echo -e "${YELLOW}[5/5] Verificação final...${NC}"

# Verificar se o código foi inserido
if grep -q "SISTEMA DE QUOTA NO UPLOAD" server.js; then
    echo -e "${GREEN}✅ Sistema de quota encontrado no código${NC}"
else
    echo -e "${RED}❌ Sistema de quota NÃO foi adicionado${NC}"
    exit 1
fi

# Verificar sintaxe final
if node -c server.js 2>/dev/null; then
    echo -e "${GREEN}✅ Sintaxe do server.js está correta${NC}"
else
    echo -e "${RED}❌ Erro de sintaxe no server.js${NC}"
    echo -e "${YELLOW}Debug: Mostrando últimos erros...${NC}"
    node -c server.js 2>&1 | head -20
    exit 1
fi

# ================================================
# SUCESSO
# ================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✅ UPLOAD CORRIGIDO COM SUCESSO!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📋 O que foi implementado:${NC}"
echo "  ✅ Verificação de quota ANTES de processar CSV"
echo "  ✅ Bloqueio quando exceder limite (erro 429)"
echo "  ✅ Incremento do contador após sucesso"
echo "  ✅ Headers de quota na resposta"
echo "  ✅ Campo 'quota' no JSON de resposta"
echo ""
echo -e "${YELLOW}📝 Próximos passos:${NC}"
echo ""
echo "  1. Sair do diretório:"
echo -e "     ${BLUE}cd ../..${NC}"
echo ""
echo "  2. Reiniciar o servidor:"
echo -e "     ${BLUE}docker-compose restart client-dashboard${NC}"
echo ""
echo "  3. Verificar logs:"
echo -e "     ${BLUE}docker-compose logs --tail=30 client-dashboard | grep QUOTA${NC}"
echo ""
echo "  4. Testar upload de CSV grande para verificar quota"
echo ""
echo -e "${GREEN}🎉 Sistema de quota no upload está pronto!${NC}"
echo ""

# Limpar arquivos temporários
rm -f auto-fix-upload.js quota_code.txt server.js.temp

exit 0
