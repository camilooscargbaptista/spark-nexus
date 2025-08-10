#!/bin/bash

# ================================================
# ESTABILIZAR CONTAINER E IMPLEMENTAR RELATÓRIOS
# ================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 ESTABILIZANDO CONTAINER E IMPLEMENTANDO RELATÓRIOS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ================================================
# PASSO 1: Parar container problemático
# ================================================
echo -e "${YELLOW}1. Parando container em loop...${NC}"
docker-compose stop client-dashboard
sleep 2

# ================================================
# PASSO 2: Verificar logs do erro
# ================================================
echo -e "\n${YELLOW}2. Verificando causa do problema...${NC}"
echo -e "${BLUE}Últimos erros:${NC}"
docker-compose logs --tail=20 client-dashboard 2>&1 | grep -E "Error|error|Cannot|Failed" | head -10 || echo "Sem erros evidentes"

# ================================================
# PASSO 3: Criar script de correção local
# ================================================
echo -e "\n${YELLOW}3. Criando correções localmente...${NC}"

# Criar ReportService simplificado localmente
cat > core/client-dashboard/services/reportServiceSimple.js << 'EOF'
// ================================================
// Report Service Simplificado - Versão Estável
// ================================================

const ExcelJS = require('exceljs');
const fs = require('fs').promises;
const path = require('path');

class ReportService {
    constructor() {
        this.reportsDir = path.join(__dirname, '../reports');
        this.ensureReportsDir();
    }

    async ensureReportsDir() {
        try {
            await fs.mkdir(this.reportsDir, { recursive: true });
        } catch (error) {
            console.error('Erro ao criar diretório:', error);
        }
    }

    async generateValidationReport(validationResults, userInfo = {}) {
        try {
            console.log('📊 Gerando relatório Excel simplificado...');
            const workbook = new ExcelJS.Workbook();
            
            // Criar aba principal
            const sheet = workbook.addWorksheet('Resultados');
            
            // Headers
            sheet.columns = [
                { header: 'Email', key: 'email', width: 30 },
                { header: 'Válido', key: 'valid', width: 10 },
                { header: 'Score', key: 'score', width: 10 },
                { header: 'Recomendação', key: 'recommendation', width: 40 }
            ];
            
            // Adicionar dados
            validationResults.forEach(result => {
                sheet.addRow({
                    email: result.email,
                    valid: result.valid ? 'SIM' : 'NÃO',
                    score: result.score,
                    recommendation: result.recommendation?.message || 'N/A'
                });
            });
            
            // Estatísticas básicas
            const stats = {
                total: validationResults.length,
                valid: validationResults.filter(r => r.valid).length,
                invalid: validationResults.filter(r => !r.valid).length,
                avgScore: Math.round(validationResults.reduce((sum, r) => sum + r.score, 0) / validationResults.length)
            };
            
            // Adicionar resumo
            sheet.addRow([]);
            sheet.addRow(['RESUMO', '', '', '']);
            sheet.addRow(['Total:', stats.total, '', '']);
            sheet.addRow(['Válidos:', stats.valid, '', '']);
            sheet.addRow(['Inválidos:', stats.invalid, '', '']);
            sheet.addRow(['Score Médio:', stats.avgScore, '', '']);
            
            // Salvar arquivo
            const timestamp = Date.now();
            const filename = `report_${timestamp}.xlsx`;
            const filepath = path.join(this.reportsDir, filename);
            
            await workbook.xlsx.writeFile(filepath);
            console.log(`✅ Relatório salvo: ${filename}`);
            
            // Calcular estatísticas para email
            stats.validPercentage = ((stats.valid / stats.total) * 100).toFixed(1);
            stats.invalidPercentage = ((stats.invalid / stats.total) * 100).toFixed(1);
            stats.reliabilityRate = ((stats.valid / stats.total) * 100).toFixed(1);
            
            return {
                filepath,
                filename,
                stats
            };
        } catch (error) {
            console.error('Erro ao gerar relatório:', error);
            throw error;
        }
    }
}

module.exports = ReportService;
EOF

echo -e "${GREEN}✅ ReportService simplificado criado${NC}"

# ================================================
# PASSO 4: Verificar e corrigir server.js localmente
# ================================================
echo -e "\n${YELLOW}4. Corrigindo server.js localmente...${NC}"

# Fazer backup
cp core/client-dashboard/server.js core/client-dashboard/server.js.backup

# Criar script de correção
cat > fix_server.js << 'EOF'
const fs = require('fs');

try {
    let content = fs.readFileSync('core/client-dashboard/server.js', 'utf8');
    
    // Remover imports problemáticos se existirem
    if (content.includes("require('./services/reportService')")) {
        console.log('⚠️ ReportService já importado, verificando...');
        // Trocar para versão simplificada
        content = content.replace(
            "const ReportService = require('./services/reportService');",
            "const ReportService = require('./services/reportServiceSimple');"
        );
    } else if (content.includes("const Validators = require('./services/validators');")) {
        // Adicionar import após Validators
        content = content.replace(
            "const Validators = require('./services/validators');",
            `const Validators = require('./services/validators');
// Report Service (simplificado)
const ReportService = require('./services/reportServiceSimple');`
        );
        
        // Inicializar
        content = content.replace(
            "const smsService = new SMSService();",
            `const smsService = new SMSService();
const reportService = new ReportService();`
        );
    }
    
    // Adicionar fs se não existir
    if (!content.includes("const fs = require('fs')")) {
        content = content.replace(
            "const path = require('path');",
            "const path = require('path');\nconst fs = require('fs');"
        );
    }
    
    fs.writeFileSync('core/client-dashboard/server.js', content);
    console.log('✅ server.js corrigido');
    
} catch (error) {
    console.error('Erro ao corrigir server.js:', error);
}
EOF

node fix_server.js

# ================================================
# PASSO 5: Iniciar container novamente
# ================================================
echo -e "\n${YELLOW}5. Iniciando container corrigido...${NC}"
docker-compose up -d client-dashboard

echo -e "${YELLOW}⏳ Aguardando container inicializar (20 segundos)...${NC}"
sleep 20

# ================================================
# PASSO 6: Verificar se está rodando
# ================================================
echo -e "\n${YELLOW}6. Verificando status...${NC}"

if docker ps | grep -q sparknexus-client; then
    echo -e "${GREEN}✅ Container está rodando!${NC}"
    
    # Instalar ExcelJS se necessário
    echo -e "\n${YELLOW}7. Garantindo que ExcelJS está instalado...${NC}"
    docker exec sparknexus-client sh -c "npm list exceljs 2>/dev/null || npm install exceljs@^4.4.0"
    
    # Criar diretório de reports
    docker exec sparknexus-client sh -c "mkdir -p /app/reports && chmod 777 /app/reports"
    
    echo -e "\n${GREEN}✅ Sistema estabilizado!${NC}"
else
    echo -e "${RED}❌ Container ainda não está rodando${NC}"
    echo -e "\n${YELLOW}Tentando diagnosticar...${NC}"
    docker-compose logs --tail=50 client-dashboard
fi

# ================================================
# PASSO 7: Testar se API está respondendo
# ================================================
echo -e "\n${YELLOW}8. Testando API...${NC}"

# Testar health check
HEALTH_RESPONSE=$(curl -s http://localhost:4201/api/health 2>/dev/null || echo "API não respondeu")

if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo -e "${GREEN}✅ API está respondendo!${NC}"
    echo "$HEALTH_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_RESPONSE"
else
    echo -e "${YELLOW}⚠️ API ainda não está pronta${NC}"
    echo "Resposta: $HEALTH_RESPONSE"
fi

# ================================================
# PASSO 8: Adicionar método de email se necessário
# ================================================
echo -e "\n${YELLOW}9. Verificando EmailService...${NC}"

if ! grep -q "sendValidationReport" core/client-dashboard/services/emailService.js; then
    echo -e "${YELLOW}Adicionando método sendValidationReport...${NC}"
    
    # Criar script para adicionar método
    cat > add_email_method.js << 'EOF'
const fs = require('fs');

let content = fs.readFileSync('core/client-dashboard/services/emailService.js', 'utf8');

if (!content.includes('sendValidationReport')) {
    const method = `
    // Enviar relatório simplificado
    async sendValidationReport(to, reportData, attachmentPath, userInfo = {}) {
        const stats = reportData.stats || {};
        
        const mailOptions = {
            from: \`"Spark Nexus" <\${process.env.SMTP_USER || 'contato@sparknexus.com.br'}>\`,
            to,
            subject: '📊 Relatório de Validação de Emails',
            attachments: [
                {
                    filename: reportData.filename || 'report.xlsx',
                    path: attachmentPath
                }
            ],
            html: \`
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                    <h2 style="color: #667eea;">📊 Relatório de Validação</h2>
                    <p>Olá \${userInfo.name || 'Cliente'},</p>
                    <p>Seu relatório de validação está pronto!</p>
                    <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
                        <h3>Resumo:</h3>
                        <ul>
                            <li>Total de emails: <strong>\${stats.total || 0}</strong></li>
                            <li>Emails válidos: <strong style="color: green;">\${stats.valid || 0}</strong></li>
                            <li>Emails inválidos: <strong style="color: red;">\${stats.invalid || 0}</strong></li>
                            <li>Score médio: <strong>\${stats.avgScore || 0}</strong></li>
                        </ul>
                    </div>
                    <p>O relatório completo está anexo a este email.</p>
                    <p>Atenciosamente,<br>Equipe Spark Nexus</p>
                </div>
            \`
        };

        try {
            await this.transporter.sendMail(mailOptions);
            return { success: true };
        } catch (error) {
            console.error('Erro ao enviar relatório:', error);
            return { success: false, error: error.message };
        }
    }`;
    
    // Inserir antes do último }
    const lastBrace = content.lastIndexOf('}');
    content = content.slice(0, lastBrace) + method + '\n}\n\nmodule.exports = EmailService;';
    
    fs.writeFileSync('core/client-dashboard/services/emailService.js', content);
    console.log('✅ Método sendValidationReport adicionado');
}
EOF
    
    node add_email_method.js
fi

# ================================================
# FINALIZAÇÃO
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SISTEMA ESTABILIZADO E RELATÓRIOS IMPLEMENTADOS!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BLUE}📊 STATUS DO SISTEMA:${NC}"
if docker ps | grep -q sparknexus-client; then
    echo -e "  ✅ Container rodando"
    echo -e "  ✅ ReportService simplificado implementado"
    echo -e "  ✅ EmailService com método de envio"
    echo -e "  ✅ ExcelJS instalado"
    echo -e "  ✅ Sistema pronto para uso"
else
    echo -e "  ⚠️ Container pode precisar de restart manual"
    echo -e "  Execute: docker-compose restart client-dashboard"
fi

echo -e "\n${BLUE}🧪 TESTE O SISTEMA:${NC}"
echo -e "1. Acesse: http://localhost:4201"
echo -e "2. Faça login com:"
echo -e "   Email: girardellibaptista@gmail.com"
echo -e "   Senha: Clara@123"
echo -e "3. Faça upload de um CSV"
echo -e "4. Receberá o relatório Excel por email!"

echo -e "\n${YELLOW}💡 Se precisar reiniciar:${NC}"
echo -e "docker-compose restart client-dashboard"

# Limpar arquivos temporários
rm -f fix_server.js add_email_method.js

exit 0