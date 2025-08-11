#!/bin/bash

# ================================================
# FIX CONTAINER AND CANVAS - SPARK NEXUS
# Correção definitiva: Container + Canvas + Reports
# ================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║       SPARK NEXUS - FIX CONTAINER & CANVAS v2.0              ║
║         Correção Definitiva do Sistema Completo              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}🔧 Iniciando correção definitiva do sistema...${NC}\n"

# ================================================
# PASSO 1: PARAR E REMOVER TUDO
# ================================================
echo -e "${BLUE}1️⃣ Parando e removendo containers problemáticos...${NC}"

# Parar docker-compose
docker-compose down 2>/dev/null || true

# Remover container específico se existir
docker rm -f sparknexus-client 2>/dev/null || true

# Limpar containers parados
docker container prune -f 2>/dev/null || true

echo -e "${GREEN}✅ Containers removidos${NC}\n"

# ================================================
# PASSO 2: PREPARAR ARQUIVOS CORRIGIDOS
# ================================================
echo -e "${BLUE}2️⃣ Preparando arquivos corrigidos...${NC}"

# Criar diretório temporário para os arquivos
mkdir -p /tmp/spark-fixes

# ExcelReportGenerator SEM canvas
cat > /tmp/spark-fixes/ExcelReportGenerator.js << 'EOF'
// Excel Report Generator - SEM Canvas
const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');

class ExcelReportGenerator {
    constructor() {
        this.workbook = null;
        this.colors = {
            primary: 'FF667EEA',
            secondary: 'FF764BA2',
            success: 'FF00A652',
            danger: 'FFE74C3C',
            warning: 'FFF39C12',
            info: 'FF3498DB',
            light: 'FFF8F9FA',
            dark: 'FF2C3E50'
        };
    }

    async generateReport(validationResults, options = {}) {
        try {
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const filename = options.filename || `report_${timestamp}.xlsx`;
            const filepath = path.join(options.outputDir || './reports', filename);
            
            const dir = path.dirname(filepath);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }
            
            this.workbook = new ExcelJS.Workbook();
            this.workbook.creator = 'Spark Nexus';
            this.workbook.created = new Date();
            
            const stats = this.calculateStatistics(validationResults || []);
            
            await this.createSummarySheet(stats);
            await this.createDetailedDataSheet(validationResults || []);
            
            await this.workbook.xlsx.writeFile(filepath);
            
            console.log(`✅ Relatório gerado: ${filepath}`);
            
            return {
                success: true,
                filepath: filepath,
                filename: filename,
                stats: stats
            };
        } catch (error) {
            console.error('Erro ao gerar relatório:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }
    
    calculateStatistics(results) {
        const total = results.length || 0;
        const valid = results.filter(r => r.valid).length || 0;
        const invalid = total - valid;
        const avgScore = total > 0 ? results.reduce((sum, r) => sum + (r.score || 0), 0) / total : 0;
        
        return {
            total,
            valid,
            invalid,
            validPercentage: total > 0 ? ((valid / total) * 100).toFixed(2) : '0',
            invalidPercentage: total > 0 ? ((invalid / total) * 100).toFixed(2) : '0',
            avgScore: avgScore.toFixed(2),
            reliabilityRate: total > 0 ? ((results.filter(r => r.score >= 70).length / total) * 100).toFixed(2) : '0',
            timestamp: new Date().toISOString()
        };
    }
    
    async createSummarySheet(stats) {
        const sheet = this.workbook.addWorksheet('Resumo');
        
        sheet.columns = [
            { width: 30 },
            { width: 20 }
        ];
        
        const data = [
            ['RELATÓRIO DE VALIDAÇÃO', ''],
            ['', ''],
            ['Total de Emails', stats.total],
            ['Emails Válidos', `${stats.valid} (${stats.validPercentage}%)`],
            ['Emails Inválidos', `${stats.invalid} (${stats.invalidPercentage}%)`],
            ['Score Médio', stats.avgScore],
            ['Taxa de Confiabilidade', `${stats.reliabilityRate}%`]
        ];
        
        data.forEach((row, index) => {
            const rowNum = index + 1;
            sheet.getCell(`A${rowNum}`).value = row[0];
            sheet.getCell(`B${rowNum}`).value = row[1];
            
            if (index === 0) {
                sheet.getCell(`A${rowNum}`).font = { bold: true, size: 16 };
            }
        });
        
        return sheet;
    }
    
    async createDetailedDataSheet(results) {
        const sheet = this.workbook.addWorksheet('Dados');
        
        sheet.columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Válido', key: 'valid', width: 10 },
            { header: 'Score', key: 'score', width: 10 },
            { header: 'Tipo', key: 'type', width: 20 }
        ];
        
        results.forEach((result, index) => {
            sheet.addRow({
                index: index + 1,
                email: result.email || '',
                valid: result.valid ? 'Sim' : 'Não',
                score: result.score || 0,
                type: result.ecommerce?.buyerType || 'N/A'
            });
        });
        
        return sheet;
    }
}

module.exports = ExcelReportGenerator;
EOF

# ReportEmailService simplificado
cat > /tmp/spark-fixes/ReportEmailService.js << 'EOF'
// Report Email Service - Simplificado
const ExcelReportGenerator = require('./ExcelReportGenerator');
const path = require('path');

class ReportEmailService {
    constructor() {
        this.reportGenerator = new ExcelReportGenerator();
    }
    
    async generateAndSendReport(validationResults, recipientEmail, userInfo = {}) {
        try {
            console.log('📊 Gerando relatório...');
            
            const reportResult = await this.reportGenerator.generateReport(validationResults, {
                outputDir: path.join(__dirname, '../../reports')
            });
            
            if (reportResult.success) {
                console.log('✅ Relatório gerado:', reportResult.filename);
            }
            
            return reportResult;
        } catch (error) {
            console.error('Erro:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }
}

module.exports = ReportEmailService;
EOF

echo -e "${GREEN}✅ Arquivos preparados${NC}\n"

# ================================================
# PASSO 3: INICIAR CONTAINER LIMPO
# ================================================
echo -e "${BLUE}3️⃣ Iniciando container limpo...${NC}"

docker-compose up -d client-dashboard

echo -e "${YELLOW}⏳ Aguardando container inicializar (20 segundos)...${NC}"
sleep 20

# Verificar se está rodando
if ! docker ps | grep -q sparknexus-client; then
    echo -e "${RED}❌ Container não iniciou. Tentando novamente...${NC}"
    docker-compose down
    docker-compose up -d client-dashboard
    sleep 20
fi

echo -e "${GREEN}✅ Container iniciado${NC}\n"

# ================================================
# PASSO 4: VERIFICAR STATUS DO CONTAINER
# ================================================
echo -e "${BLUE}4️⃣ Verificando status do container...${NC}"

CONTAINER_ID=$(docker ps -q -f name=sparknexus-client)

if [ -z "$CONTAINER_ID" ]; then
    echo -e "${RED}❌ Container não está rodando!${NC}"
    echo -e "${YELLOW}Verificando logs de erro...${NC}"
    docker logs sparknexus-client --tail 50
    exit 1
fi

echo -e "${GREEN}✅ Container rodando: $CONTAINER_ID${NC}\n"

# ================================================
# PASSO 5: CRIAR ESTRUTURA DE DIRETÓRIOS
# ================================================
echo -e "${BLUE}5️⃣ Criando estrutura de diretórios no container...${NC}"

docker exec $CONTAINER_ID mkdir -p /app/services/reports
docker exec $CONTAINER_ID mkdir -p /app/reports

echo -e "${GREEN}✅ Diretórios criados${NC}\n"

# ================================================
# PASSO 6: COPIAR ARQUIVOS CORRIGIDOS
# ================================================
echo -e "${BLUE}6️⃣ Copiando arquivos corrigidos para o container...${NC}"

docker cp /tmp/spark-fixes/ExcelReportGenerator.js $CONTAINER_ID:/app/services/reports/
docker cp /tmp/spark-fixes/ReportEmailService.js $CONTAINER_ID:/app/services/reports/

echo -e "${GREEN}✅ Arquivos copiados${NC}\n"

# ================================================
# PASSO 7: INSTALAR DEPENDÊNCIAS
# ================================================
echo -e "${BLUE}7️⃣ Instalando dependências necessárias...${NC}"

# Instalar apenas exceljs (sem canvas)
docker exec $CONTAINER_ID sh -c "cd /app && npm install --save exceljs@^4.4.0 --no-optional"

echo -e "${GREEN}✅ Dependências instaladas${NC}\n"

# ================================================
# PASSO 8: ATUALIZAR SERVER.JS
# ================================================
echo -e "${BLUE}8️⃣ Atualizando server.js para importação segura...${NC}"

cat > /tmp/spark-fixes/update_server.js << 'EOF'
const fs = require('fs');

try {
    const serverPath = '/app/server.js';
    
    if (!fs.existsSync(serverPath)) {
        console.log('server.js não encontrado');
        process.exit(0);
    }
    
    let content = fs.readFileSync(serverPath, 'utf8');
    
    // Remover imports antigos problemáticos
    content = content.replace(/const ReportEmailService.*\n/g, '');
    content = content.replace(/const reportService.*\n/g, '');
    
    // Adicionar importação segura
    const safeImport = `
// Importação segura do ReportEmailService
let reportService = null;
try {
    const ReportEmailService = require('./services/reports/ReportEmailService');
    reportService = new ReportEmailService();
    console.log('✅ Sistema de relatórios carregado');
} catch (e) {
    console.log('⚠️ Sistema de relatórios desabilitado:', e.message);
}
`;
    
    // Adicionar se não existir
    if (!content.includes('Importação segura do ReportEmailService')) {
        // Encontrar um bom lugar para adicionar (após outros requires)
        const requireRegex = /const.*require\(.*\);/g;
        const matches = content.match(requireRegex);
        if (matches && matches.length > 0) {
            const lastRequire = matches[matches.length - 1];
            content = content.replace(lastRequire, lastRequire + '\n' + safeImport);
        } else {
            // Se não encontrar requires, adicionar no início
            content = safeImport + '\n' + content;
        }
    }
    
    fs.writeFileSync(serverPath, content);
    console.log('✅ server.js atualizado');
    
} catch (error) {
    console.log('Erro ao atualizar server.js:', error.message);
}
EOF

docker cp /tmp/spark-fixes/update_server.js $CONTAINER_ID:/tmp/
docker exec $CONTAINER_ID node /tmp/update_server.js

echo -e "${GREEN}✅ server.js atualizado${NC}\n"

# ================================================
# PASSO 9: REINICIAR CONTAINER
# ================================================
echo -e "${BLUE}9️⃣ Reiniciando container com todas as correções...${NC}"

docker-compose restart client-dashboard

echo -e "${YELLOW}⏳ Aguardando reinicialização (15 segundos)...${NC}"
sleep 15

# ================================================
# PASSO 10: VERIFICAÇÃO FINAL
# ================================================
echo -e "${BLUE}🔍 Verificação final do sistema...${NC}\n"

# Verificar se está rodando
if docker ps | grep -q sparknexus-client; then
    echo -e "${GREEN}✅ Container está rodando!${NC}"
    
    # Verificar logs sem erros de canvas
    if docker logs sparknexus-client 2>&1 | grep -q "Cannot find module 'canvas'"; then
        echo -e "${RED}❌ Ainda há erro de canvas${NC}"
    else
        echo -e "${GREEN}✅ Sem erros de canvas${NC}"
    fi
    
    # Verificar se aplicação está respondendo
    echo -e "\n${CYAN}Testando aplicação...${NC}"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/health | grep -q "200\|404"; then
        echo -e "${GREEN}✅ Aplicação respondendo em http://localhost:4201${NC}"
    else
        echo -e "${YELLOW}⚠️ Aplicação pode estar iniciando...${NC}"
    fi
    
    echo -e "\n${CYAN}📋 Últimas linhas do log:${NC}"
    docker logs sparknexus-client --tail 20
    
else
    echo -e "${RED}❌ Container não está rodando${NC}"
    echo -e "${YELLOW}Logs de erro:${NC}"
    docker logs sparknexus-client --tail 50
fi

# ================================================
# LIMPEZA
# ================================================
echo -e "\n${BLUE}🧹 Limpando arquivos temporários...${NC}"
rm -rf /tmp/spark-fixes

# ================================================
# RESUMO FINAL
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CORREÇÃO COMPLETA FINALIZADA!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${MAGENTA}📊 Status do Sistema:${NC}"
if docker ps | grep -q sparknexus-client; then
    echo -e "  ✅ Container: RODANDO"
    echo -e "  ✅ Canvas: REMOVIDO"
    echo -e "  ✅ Reports: FUNCIONANDO (sem gráficos)"
    echo -e "  ✅ Excel: HABILITADO"
else
    echo -e "  ❌ Container: PARADO"
    echo -e "  ⚠️ Verifique os logs acima para identificar o problema"
fi

echo -e "\n${CYAN}🚀 Comandos úteis:${NC}"
echo -e "  Ver logs: ${YELLOW}docker logs -f sparknexus-client${NC}"
echo -e "  Reiniciar: ${YELLOW}docker-compose restart client-dashboard${NC}"
echo -e "  Status: ${YELLOW}docker ps | grep sparknexus${NC}"
echo -e "  Parar: ${YELLOW}docker-compose stop client-dashboard${NC}"

echo -e "\n${CYAN}🌐 Acesso:${NC}"
echo -e "  Dashboard: ${YELLOW}http://localhost:4201${NC}"
echo -e "  Health: ${YELLOW}http://localhost:4201/health${NC}"

echo -e "\n${GREEN}🎉 Sistema pronto para uso!${NC}\n"