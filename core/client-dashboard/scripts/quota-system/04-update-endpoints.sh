#!/bin/bash

# ================================================
# Script: 04-update-endpoints.sh
# Descrição: Atualiza endpoints para usar sistema de quota
# ================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Diretório base
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../../../" && pwd )"
CLIENT_DIR="$PROJECT_ROOT/core/client-dashboard"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   ATUALIZANDO ENDPOINTS COM SISTEMA DE QUOTA${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ================================================
# BACKUP DO SERVER.JS ORIGINAL
# ================================================

echo -e "${YELLOW}[1/5] Criando backup do server.js...${NC}"

BACKUP_DIR="$CLIENT_DIR/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/server.js.backup.$TIMESTAMP"

if [ -f "$CLIENT_DIR/server.js" ]; then
    cp "$CLIENT_DIR/server.js" "$BACKUP_FILE"
    echo -e "${GREEN}✅ Backup criado: $BACKUP_FILE${NC}"
else
    echo -e "${RED}❌ server.js não encontrado!${NC}"
    exit 1
fi

# ================================================
# CRIAR PATCH PARA O SERVER.JS
# ================================================

echo -e "${YELLOW}[2/5] Criando arquivo de patch...${NC}"

cat > "$CLIENT_DIR/server-quota-patch.js" << 'EOF'
// ================================================
// PATCH: Sistema de Quota - Adicionar após os requires existentes
// ================================================

// Importar middleware de quota
const {
    checkQuota,
    quotaForSingle,
    quotaForBatch,
    quotaForUpload,
    getQuotaStats,
    resetQuotas,
    getQuotaService
} = require('./middleware/quotaMiddleware');

// Importar QuotaService diretamente se necessário
const QuotaService = require('./services/QuotaService');

// ================================================
// ENDPOINTS DE QUOTA (adicionar após /api/auth/verify)
// ================================================

// Obter estatísticas de quota do usuário
app.get('/api/user/quota', authenticateToken, getQuotaStats);

// Obter informações de quota simplificadas
app.get('/api/user/quota/summary', authenticateToken, async (req, res) => {
    try {
        const quotaService = getQuotaService();
        const userId = req.user.id;

        const organization = await quotaService.getUserOrganization(userId);
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
        console.error('Erro ao buscar resumo de quota:', error);
        res.status(500).json({ error: 'Erro ao buscar informações de quota' });
    }
});

// Reset manual de quotas (admin only)
app.post('/api/admin/quota/reset', authenticateToken, resetQuotas);

// Histórico de uso de quota
app.get('/api/user/quota/history', authenticateToken, async (req, res) => {
    try {
        const quotaService = getQuotaService();
        const userId = req.user.id;
        const months = parseInt(req.query.months) || 6;

        const organization = await quotaService.getUserOrganization(userId);
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
});

// ================================================
// MODIFICAÇÕES NOS ENDPOINTS EXISTENTES
// ================================================

// NOTA: Os seguintes endpoints precisam ser modificados manualmente:
// 1. /api/validate/single - Adicionar quotaForSingle após authenticateToken
// 2. /api/validate/batch - Adicionar quotaForBatch após authenticateToken
// 3. /api/validate/advanced - Adicionar quotaForSingle após authenticateToken
// 4. /api/upload - Adicionar checkQuota customizado após processar arquivo
// 5. /api/validate/batch-with-report - Adicionar quotaForBatch após authenticateToken

// Exemplo de como deve ficar:
/*
app.post('/api/validate/single',
    authenticateToken,
    quotaForSingle,  // <-- ADICIONAR ESTA LINHA
    [
        body('email').isEmail().withMessage('Email inválido')
    ],
    async (req, res) => {
        // código existente...
    }
);
*/

EOF

echo -e "${GREEN}✅ Patch criado${NC}"

# ================================================
# CRIAR SCRIPT DE ATUALIZAÇÃO NODE.JS
# ================================================

echo -e "${YELLOW}[3/5] Criando script de atualização automática...${NC}"

cat > "$CLIENT_DIR/update-server-quota.js" << 'EOF'
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

EOF

echo -e "${GREEN}✅ Script de atualização criado${NC}"

# ================================================
# EXECUTAR ATUALIZAÇÃO
# ================================================

echo -e "${YELLOW}[4/5] Executando atualização do server.js...${NC}"

cd "$CLIENT_DIR"
node update-server-quota.js

# ================================================
# CRIAR EXEMPLO DE USO
# ================================================

echo -e "${YELLOW}[5/5] Criando arquivo de exemplo...${NC}"

cat > "$CLIENT_DIR/quota-example.md" << 'EOF'
# Sistema de Quota - Exemplos de Uso

## Endpoints de Quota Disponíveis

### 1. Obter Estatísticas Completas
```bash
GET /api/user/quota
Authorization: Bearer {token}

Response:
{
    "organization": {
        "id": "uuid",
        "name": "Minha Empresa",
        "plan": "free"
    },
    "quota": {
        "max_validations": 1000,
        "validations_used": 150,
        "validations_remaining": 850,
        "usage_percentage": 15,
        "next_reset_date": "2025-02-01",
        "daily_average": 5
    },
    "history": [...],
    "alerts": []
}
```

### 2. Obter Resumo Simplificado
```bash
GET /api/user/quota/summary
Authorization: Bearer {token}

Response:
{
    "organization": "Minha Empresa",
    "plan": "free",
    "used": 150,
    "limit": 1000,
    "remaining": 850,
    "percentage": 15,
    "nextReset": "2025-02-01",
    "alerts": []
}
```

### 3. Validação com Quota
```bash
POST /api/validate/single
Authorization: Bearer {token}
Content-Type: application/json

{
    "email": "teste@example.com"
}

Headers na Resposta:
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 849
X-RateLimit-Used: 151
X-Organization-Plan: free
```

### 4. Erro de Quota Excedida
```json
{
    "error": "Limite de validações excedido",
    "code": "QUOTA_EXCEEDED",
    "details": {
        "message": "Limite excedido. Apenas 0 validações restantes",
        "limit": 1000,
        "used": 1000,
        "remaining": 0,
        "requested": 1,
        "plan": "free",
        "nextResetDate": "2025-02-01"
    },
    "suggestions": [
        "Aguarde até o próximo período de faturamento",
        "Faça upgrade do seu plano para aumentar o limite"
    ]
}
```

## Dashboard - Componente de Quota

Adicione este HTML no dashboard para mostrar a quota:

```html
<div class="quota-widget">
    <h4>Quota de Validações</h4>
    <div class="quota-progress">
        <div class="progress-bar" id="quotaBar"></div>
    </div>
    <div class="quota-info">
        <span id="quotaUsed">0</span> / <span id="quotaLimit">0</span>
        <span class="quota-plan" id="quotaPlan">free</span>
    </div>
</div>

<script>
async function loadQuota() {
    const response = await fetch('/api/user/quota/summary', {
        headers: {
            'Authorization': 'Bearer ' + localStorage.getItem('token')
        }
    });

    if (response.ok) {
        const data = await response.json();
        document.getElementById('quotaUsed').textContent = data.used;
        document.getElementById('quotaLimit').textContent = data.limit;
        document.getElementById('quotaPlan').textContent = data.plan;
        document.getElementById('quotaBar').style.width = data.percentage + '%';

        // Alertas
        if (data.percentage >= 90) {
            document.getElementById('quotaBar').classList.add('danger');
        } else if (data.percentage >= 75) {
            document.getElementById('quotaBar').classList.add('warning');
        }
    }
}

// Carregar ao iniciar
loadQuota();

// Atualizar após cada validação
window.addEventListener('validation-complete', loadQuota);
</script>
```

## CSS para o Widget

```css
.quota-widget {
    padding: 15px;
    border: 1px solid #ddd;
    border-radius: 8px;
    margin: 20px 0;
}

.quota-progress {
    width: 100%;
    height: 20px;
    background: #f0f0f0;
    border-radius: 10px;
    overflow: hidden;
    margin: 10px 0;
}

.progress-bar {
    height: 100%;
    background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
    transition: width 0.3s ease;
}

.progress-bar.warning {
    background: linear-gradient(90deg, #f39c12 0%, #e67e22 100%);
}

.progress-bar.danger {
    background: linear-gradient(90deg, #e74c3c 0%, #c0392b 100%);
}

.quota-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 14px;
}

.quota-plan {
    background: #667eea;
    color: white;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
    text-transform: uppercase;
}
```

EOF

echo -e "${GREEN}✅ Arquivo de exemplo criado${NC}"

# ================================================
# RELATÓRIO FINAL
# ================================================

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   ✅ ATUALIZAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}📋 Ações realizadas:${NC}"
echo "  1. Backup do server.js criado"
echo "  2. Imports de quota adicionados"
echo "  3. Middlewares aplicados nos endpoints"
echo "  4. Novos endpoints de quota criados"
echo "  5. Documentação e exemplos gerados"
echo ""
echo -e "${YELLOW}⚠️  Próximos passos:${NC}"
echo "  1. Revisar o arquivo server.js"
echo "  2. Reiniciar o servidor:"
echo "     docker-compose restart client-dashboard"
echo "  3. Testar os endpoints de quota"
echo "  4. Adicionar widget de quota no dashboard"
echo ""
echo -e "${BLUE}📊 Endpoints de quota disponíveis:${NC}"
echo "  GET  /api/user/quota          - Estatísticas completas"
echo "  GET  /api/user/quota/summary  - Resumo simplificado"
echo "  GET  /api/user/quota/history  - Histórico de uso"
echo "  POST /api/admin/quota/reset   - Reset manual (admin)"
echo ""
echo -e "${GREEN}✨ Sistema de quota instalado!${NC}"
echo ""

exit 0
EOF

chmod +x "$CLIENT_DIR/update-server-quota.js"
echo -e "${GREEN}✅ Script de atualização criado${NC}"
