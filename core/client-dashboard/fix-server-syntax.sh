#!/bin/bash

# ================================================
# Script: fix-server-syntax.sh
# Descrição: Corrige erro de sintaxe no server.js
# ================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   CORRIGINDO ERRO DE SINTAXE NO SERVER.JS${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Diretório
CLIENT_DIR="/spark-nexus/core/client-dashboard"
cd "$CLIENT_DIR"

# Fazer backup
echo -e "${YELLOW}Criando backup...${NC}"
cp server.js server.js.broken
echo -e "${GREEN}✅ Backup criado: server.js.broken${NC}"

# Restaurar do backup anterior
echo -e "${YELLOW}Restaurando do backup anterior...${NC}"
LATEST_BACKUP=$(ls -t backups/server.js.backup.* | head -1)

if [ -f "$LATEST_BACKUP" ]; then
    cp "$LATEST_BACKUP" server.js.temp
    echo -e "${GREEN}✅ Backup restaurado de: $LATEST_BACKUP${NC}"
else
    echo -e "${RED}❌ Nenhum backup encontrado!${NC}"
    exit 1
fi

# Agora vamos adicionar o código de quota corretamente
echo -e "${YELLOW}Adicionando sistema de quota corretamente...${NC}"

cat > add-quota-proper.js << 'EOF'
const fs = require('fs');

let content = fs.readFileSync('server.js.temp', 'utf8');

// Verificar se já tem quota
if (content.includes('quotaMiddleware')) {
    console.log('Sistema de quota já existe');
    process.exit(0);
}

// Encontrar o ponto certo para inserir (após o último require/const do topo)
const lines = content.split('\n');
let lastRequireLine = -1;

for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('const ') && lines[i].includes('require(')) {
        lastRequireLine = i;
    }
    // Parar ao encontrar o primeiro app.use ou função
    if (lines[i].includes('app.use(') || lines[i].includes('app.get(') || lines[i].includes('app.post(')) {
        break;
    }
}

// Adicionar imports após o último require
if (lastRequireLine > -1) {
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
const QuotaService = require('./services/QuotaService');`;

    lines.splice(lastRequireLine + 1, 0, quotaImports);
    content = lines.join('\n');
}

// Atualizar endpoints de validação
const replacements = [
    {
        from: "app.post('/api/validate/single', authenticateToken,",
        to: "app.post('/api/validate/single', authenticateToken, quotaForSingle,"
    },
    {
        from: "app.post('/api/validate/batch', authenticateToken,",
        to: "app.post('/api/validate/batch', authenticateToken, quotaForBatch,"
    },
    {
        from: "app.post('/api/validate/advanced', authenticateToken,",
        to: "app.post('/api/validate/advanced', authenticateToken, quotaForSingle,"
    },
    {
        from: "app.post('/api/validate/batch-with-report', authenticateToken,",
        to: "app.post('/api/validate/batch-with-report', authenticateToken, quotaForBatch,"
    }
];

replacements.forEach(({ from, to }) => {
    if (content.includes(from) && !content.includes(to)) {
        content = content.replace(from, to);
        console.log('✅ Endpoint atualizado:', from.split(',')[0]);
    }
});

// Adicionar endpoints de quota após /api/auth/verify
const authVerifyIndex = content.indexOf("app.get('/api/auth/verify'");
if (authVerifyIndex > -1) {
    const endOfRoute = content.indexOf('});', authVerifyIndex) + 3;

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
        const alerts = await quotaService.checkQuotaAlerts(organization.id);

        res.json({
            organization: organization.name,
            plan: organization.plan,
            used: quota.used,
            limit: quota.limit,
            remaining: quota.remaining,
            percentage: Math.round((quota.used / quota.limit) * 100),
            nextReset: organization.next_reset_date,
            alerts: alerts.alerts.filter(a => a.level !== 'info')
        });
    } catch (error) {
        console.error('Erro ao buscar quota:', error);
        res.status(500).json({ error: 'Erro ao buscar quota' });
    }
});

// Histórico de uso
app.get('/api/user/quota/history', authenticateToken, async (req, res) => {
    try {
        const quotaService = new QuotaService(db.pool, db.redis);
        const months = parseInt(req.query.months) || 6;

        const organization = await quotaService.getUserOrganization(req.user.id);
        if (!organization) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const history = await quotaService.getUsageHistory(organization.id, months);
        res.json({
            organization: organization.name,
            history: history
        });
    } catch (error) {
        console.error('Erro ao buscar histórico:', error);
        res.status(500).json({ error: 'Erro ao buscar histórico' });
    }
});`;

    content = content.slice(0, endOfRoute) + quotaEndpoints + content.slice(endOfRoute);
    console.log('✅ Endpoints de quota adicionados');
}

// Salvar arquivo corrigido
fs.writeFileSync('server.js', content);
console.log('✅ server.js corrigido com sucesso!');
EOF

node add-quota-proper.js

echo -e "${GREEN}✅ Sistema de quota adicionado corretamente${NC}"

# Verificar sintaxe
echo -e "${YELLOW}Verificando sintaxe...${NC}"
if node -c server.js 2>/dev/null; then
    echo -e "${GREEN}✅ Sintaxe válida!${NC}"
else
    echo -e "${RED}❌ Ainda há erros de sintaxe${NC}"
    echo -e "${YELLOW}Verificando erro:${NC}"
    node -c server.js
fi

# Limpar arquivos temporários
rm -f server.js.temp add-quota-proper.js

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   ✅ CORREÇÃO CONCLUÍDA!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Próximos passos:${NC}"
echo "  1. Criar os arquivos que faltam:"
echo "     - middleware/quotaMiddleware.js"
echo "     - services/QuotaService.js"
echo "  2. Reiniciar o servidor:"
echo "     docker-compose restart client-dashboard"
echo ""
