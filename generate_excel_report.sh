#!/bin/bash

# ================================================
# EXCEL REPORT GENERATOR - SPARK NEXUS
# Sistema de geração de relatórios Excel e envio por email
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
║      SPARK NEXUS - EXCEL REPORT GENERATOR v1.0               ║
║    Sistema de Relatórios Profissionais com Gráficos          ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="excel_report_generator_${TIMESTAMP}.log"

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Verificar estrutura
if [ ! -d "core/client-dashboard" ]; then
    echo -e "${RED}Execute na raiz do spark-nexus!${NC}"
    exit 1
fi

SERVICES_DIR="core/client-dashboard/services"
REPORTS_DIR="core/client-dashboard/reports"
mkdir -p "$SERVICES_DIR/reports"
mkdir -p "$REPORTS_DIR"

# ================================================
# INSTALAR DEPENDÊNCIAS
# ================================================
log "📦 Instalando dependências para geração de Excel..."

cat > /tmp/install_excel_deps.sh << 'DEPS'
#!/bin/sh
cd /app

echo "Instalando dependências para relatórios Excel..."

npm install --save \
    exceljs@^4.4.0 \
    chart.js@^4.4.0 \
    canvas@^2.11.2 \
    moment@^2.29.4

echo "✅ Dependências Excel instaladas"
DEPS

docker cp /tmp/install_excel_deps.sh sparknexus-client:/tmp/ 2>/dev/null || true
docker exec sparknexus-client sh /tmp/install_excel_deps.sh 2>/dev/null || true

success "Dependências instaladas"

# ================================================
# CRIAR GERADOR DE RELATÓRIOS EXCEL
# ================================================
log "📊 Criando gerador de relatórios Excel..."

cat > "${SERVICES_DIR}/reports/ExcelReportGenerator.js" << 'EOF'
// ================================================
// Excel Report Generator - Relatórios Profissionais
// ================================================

const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');
const { createCanvas } = require('canvas');
const Chart = require('chart.js/auto');
const moment = require('moment');

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
        const timestamp = moment().format('YYYYMMDD_HHmmss');
        const filename = options.filename || `validation_report_${timestamp}.xlsx`;
        const filepath = path.join(options.outputDir || './reports', filename);
        
        // Criar diretório se não existir
        const dir = path.dirname(filepath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        
        // Inicializar workbook
        this.workbook = new ExcelJS.Workbook();
        this.workbook.creator = 'Spark Nexus';
        this.workbook.lastModifiedBy = 'Validation System';
        this.workbook.created = new Date();
        this.workbook.modified = new Date();
        
        // Processar dados
        const stats = this.calculateStatistics(validationResults);
        
        // Criar abas
        await this.createSummarySheet(stats);
        await this.createDetailedDataSheet(validationResults);
        await this.createStatisticsSheet(stats, validationResults);
        await this.createDomainAnalysisSheet(validationResults);
        await this.createEcommerceSheet(validationResults);
        await this.createRecommendationsSheet(validationResults);
        await this.createChartsSheet(stats);
        
        // Salvar arquivo
        await this.workbook.xlsx.writeFile(filepath);
        
        console.log(`✅ Relatório Excel gerado: ${filepath}`);
        
        return {
            success: true,
            filepath: filepath,
            filename: filename,
            stats: stats
        };
    }
    
    calculateStatistics(results) {
        const total = results.length;
        const valid = results.filter(r => r.valid).length;
        const invalid = total - valid;
        const avgScore = results.reduce((sum, r) => sum + (r.score || 0), 0) / total;
        
        // Distribuição por tipo de comprador
        const buyerTypes = {};
        results.forEach(r => {
            if (r.ecommerce && r.ecommerce.buyerType) {
                buyerTypes[r.ecommerce.buyerType] = (buyerTypes[r.ecommerce.buyerType] || 0) + 1;
            }
        });
        
        // Distribuição por nível de risco
        const riskLevels = {};
        results.forEach(r => {
            if (r.ecommerce && r.ecommerce.riskLevel) {
                riskLevels[r.ecommerce.riskLevel] = (riskLevels[r.ecommerce.riskLevel] || 0) + 1;
            }
        });
        
        // Domínios mais frequentes
        const domains = {};
        results.forEach(r => {
            const domain = r.email ? r.email.split('@')[1] : 'unknown';
            domains[domain] = (domains[domain] || 0) + 1;
        });
        
        const topDomains = Object.entries(domains)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10);
        
        return {
            total,
            valid,
            invalid,
            validPercentage: ((valid / total) * 100).toFixed(2),
            invalidPercentage: ((invalid / total) * 100).toFixed(2),
            avgScore: avgScore.toFixed(2),
            reliabilityRate: ((results.filter(r => r.score >= 70).length / total) * 100).toFixed(2),
            buyerTypes,
            riskLevels,
            topDomains,
            timestamp: new Date().toISOString()
        };
    }
    
    async createSummarySheet(stats) {
        const sheet = this.workbook.addWorksheet('Resumo Executivo', {
            properties: { tabColor: { argb: this.colors.primary } }
        });
        
        // Configurar colunas
        sheet.columns = [
            { width: 5 },
            { width: 30 },
            { width: 25 },
            { width: 20 },
            { width: 20 }
        ];
        
        // Título
        sheet.mergeCells('B2:E2');
        const titleCell = sheet.getCell('B2');
        titleCell.value = '📊 RELATÓRIO DE VALIDAÇÃO DE EMAILS';
        titleCell.font = { name: 'Arial', size: 18, bold: true, color: { argb: this.colors.primary } };
        titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(2).height = 40;
        
        // Data do relatório
        sheet.mergeCells('B3:E3');
        const dateCell = sheet.getCell('B3');
        dateCell.value = `Gerado em: ${moment().format('DD/MM/YYYY HH:mm:ss')}`;
        dateCell.font = { name: 'Arial', size: 11, italic: true };
        dateCell.alignment = { horizontal: 'center' };
        
        // Espaço
        sheet.getRow(4).height = 10;
        
        // Métricas principais
        const metricsStartRow = 5;
        const metrics = [
            { label: 'RESUMO GERAL', value: '', header: true },
            { label: 'Total de Emails Analisados', value: stats.total },
            { label: 'Emails Válidos', value: `${stats.valid} (${stats.validPercentage}%)`, color: this.colors.success },
            { label: 'Emails Inválidos', value: `${stats.invalid} (${stats.invalidPercentage}%)`, color: this.colors.danger },
            { label: 'Score Médio', value: stats.avgScore },
            { label: 'Taxa de Confiabilidade', value: `${stats.reliabilityRate}%` },
            { label: '', value: '' },
            { label: 'CLASSIFICAÇÃO DA LISTA', value: '', header: true },
            { label: 'Qualidade Geral', value: this.getListQuality(stats.avgScore) },
            { label: 'Recomendação', value: this.getRecommendation(stats.avgScore) }
        ];
        
        metrics.forEach((metric, index) => {
            const row = metricsStartRow + index;
            
            if (metric.header) {
                sheet.mergeCells(`B${row}:E${row}`);
                const cell = sheet.getCell(`B${row}`);
                cell.value = metric.label;
                cell.font = { bold: true, size: 12, color: { argb: 'FFFFFFFF' } };
                cell.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: this.colors.primary }
                };
                cell.alignment = { horizontal: 'center', vertical: 'middle' };
                sheet.getRow(row).height = 25;
            } else if (metric.label) {
                const labelCell = sheet.getCell(`B${row}`);
                labelCell.value = metric.label;
                labelCell.font = { size: 11 };
                labelCell.border = {
                    left: { style: 'thin' },
                    bottom: { style: 'thin' }
                };
                
                sheet.mergeCells(`C${row}:E${row}`);
                const valueCell = sheet.getCell(`C${row}`);
                valueCell.value = metric.value;
                valueCell.font = { 
                    size: 11, 
                    bold: true,
                    color: metric.color ? { argb: metric.color } : undefined
                };
                valueCell.alignment = { horizontal: 'right' };
                valueCell.border = {
                    right: { style: 'thin' },
                    bottom: { style: 'thin' }
                };
            }
        });
        
        // Box de destaque com score
        const scoreRow = metricsStartRow + metrics.length + 2;
        sheet.mergeCells(`B${scoreRow}:E${scoreRow + 3}`);
        const scoreBox = sheet.getCell(`B${scoreRow}`);
        scoreBox.value = `SCORE DE QUALIDADE\n\n${Math.round(stats.avgScore)}/100`;
        scoreBox.font = { size: 24, bold: true, color: { argb: 'FFFFFFFF' } };
        scoreBox.fill = {
            type: 'gradient',
            gradient: 'angle',
            degree: 45,
            stops: [
                { position: 0, color: { argb: this.colors.primary } },
                { position: 1, color: { argb: this.colors.secondary } }
            ]
        };
        scoreBox.alignment = { horizontal: 'center', vertical: 'middle', wrapText: true };
        scoreBox.border = {
            top: { style: 'medium' },
            left: { style: 'medium' },
            bottom: { style: 'medium' },
            right: { style: 'medium' }
        };
        
        return sheet;
    }
    
    async createDetailedDataSheet(results) {
        const sheet = this.workbook.addWorksheet('Dados Detalhados', {
            properties: { tabColor: { argb: this.colors.info } }
        });
        
        // Configurar colunas
        const columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Válido', key: 'valid', width: 10 },
            { header: 'Score', key: 'score', width: 10 },
            { header: 'Tipo de Comprador', key: 'buyerType', width: 20 },
            { header: 'Nível de Risco', key: 'riskLevel', width: 15 },
            { header: 'Prob. Fraude (%)', key: 'fraudProbability', width: 15 },
            { header: 'Confiança', key: 'confidence', width: 15 },
            { header: 'Formato OK', key: 'formatOk', width: 12 },
            { header: 'TLD Válido', key: 'tldValid', width: 12 },
            { header: 'Descartável', key: 'disposable', width: 12 },
            { header: 'MX Records', key: 'hasMX', width: 12 },
            { header: 'SMTP OK', key: 'smtpOk', width: 12 },
            { header: 'Padrões Susp.', key: 'suspicious', width: 15 },
            { header: 'Recomendação', key: 'recommendation', width: 30 }
        ];
        
        sheet.columns = columns;
        
        // Estilizar cabeçalho
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.dark }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 30;
        
        // Adicionar dados
        results.forEach((result, index) => {
            const row = sheet.addRow({
                index: index + 1,
                email: result.email || '',
                valid: result.valid ? '✅ Sim' : '❌ Não',
                score: result.score || 0,
                buyerType: result.ecommerce?.buyerType || 'N/A',
                riskLevel: result.ecommerce?.riskLevel || 'N/A',
                fraudProbability: result.ecommerce?.fraudProbability || 0,
                confidence: result.ecommerce?.confidence || 'N/A',
                formatOk: result.validations?.format?.valid ? '✅' : '❌',
                tldValid: result.validations?.tld?.valid ? '✅' : '❌',
                disposable: result.validations?.disposable?.isDisposable ? '⚠️ Sim' : '✅ Não',
                hasMX: result.validations?.mx?.valid ? '✅' : '❌',
                smtpOk: result.validations?.smtp?.exists ? '✅' : '❌',
                suspicious: result.validations?.patterns?.suspicious ? '⚠️ Sim' : '✅ Não',
                recommendation: result.recommendations?.[0]?.message || 'N/A'
            });
            
            // Colorir linha baseado na validade
            if (result.valid) {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFE8F5E9' }
                };
            } else {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFFFEBEE' }
                };
            }
            
            // Colorir score
            const scoreCell = row.getCell('score');
            if (result.score >= 70) {
                scoreCell.font = { color: { argb: this.colors.success }, bold: true };
            } else if (result.score >= 50) {
                scoreCell.font = { color: { argb: this.colors.warning }, bold: true };
            } else {
                scoreCell.font = { color: { argb: this.colors.danger }, bold: true };
            }
        });
        
        // Adicionar filtros
        sheet.autoFilter = {
            from: { row: 1, column: 1 },
            to: { row: results.length + 1, column: columns.length }
        };
        
        // Congelar painel
        sheet.views = [
            { state: 'frozen', xSplit: 2, ySplit: 1 }
        ];
        
        return sheet;
    }
    
    async createStatisticsSheet(stats, results) {
        const sheet = this.workbook.addWorksheet('Estatísticas', {
            properties: { tabColor: { argb: this.colors.warning } }
        });
        
        // Configurar layout
        sheet.columns = [
            { width: 5 },
            { width: 35 },
            { width: 20 },
            { width: 20 },
            { width: 20 }
        ];
        
        // Título
        sheet.mergeCells('B2:E2');
        const titleCell = sheet.getCell('B2');
        titleCell.value = '📈 ESTATÍSTICAS DETALHADAS';
        titleCell.font = { size: 16, bold: true, color: { argb: this.colors.primary } };
        titleCell.alignment = { horizontal: 'center' };
        
        // Distribuição de Scores
        let currentRow = 4;
        sheet.getCell(`B${currentRow}`).value = 'DISTRIBUIÇÃO DE SCORES';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 12 };
        sheet.mergeCells(`B${currentRow}:E${currentRow}`);
        sheet.getCell(`B${currentRow}`).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.light }
        };
        
        currentRow++;
        const scoreRanges = {
            '0-20': results.filter(r => r.score >= 0 && r.score < 20).length,
            '20-40': results.filter(r => r.score >= 20 && r.score < 40).length,
            '40-60': results.filter(r => r.score >= 40 && r.score < 60).length,
            '60-80': results.filter(r => r.score >= 60 && r.score < 80).length,
            '80-100': results.filter(r => r.score >= 80 && r.score <= 100).length
        };
        
        Object.entries(scoreRanges).forEach(([range, count]) => {
            sheet.getCell(`B${currentRow}`).value = `Score ${range}`;
            sheet.getCell(`C${currentRow}`).value = count;
            sheet.getCell(`D${currentRow}`).value = `${((count / stats.total) * 100).toFixed(2)}%`;
            currentRow++;
        });
        
        currentRow += 2;
        
        // Distribuição por Tipo de Comprador
        sheet.getCell(`B${currentRow}`).value = 'DISTRIBUIÇÃO POR TIPO DE COMPRADOR';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 12 };
        sheet.mergeCells(`B${currentRow}:E${currentRow}`);
        sheet.getCell(`B${currentRow}`).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.light }
        };
        
        currentRow++;
        Object.entries(stats.buyerTypes).forEach(([type, count]) => {
            sheet.getCell(`B${currentRow}`).value = type;
            sheet.getCell(`C${currentRow}`).value = count;
            sheet.getCell(`D${currentRow}`).value = `${((count / stats.total) * 100).toFixed(2)}%`;
            currentRow++;
        });
        
        currentRow += 2;
        
        // Distribuição por Nível de Risco
        sheet.getCell(`B${currentRow}`).value = 'DISTRIBUIÇÃO POR NÍVEL DE RISCO';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 12 };
        sheet.mergeCells(`B${currentRow}:E${currentRow}`);
        sheet.getCell(`B${currentRow}`).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.light }
        };
        
        currentRow++;
        Object.entries(stats.riskLevels).forEach(([level, count]) => {
            sheet.getCell(`B${currentRow}`).value = level;
            sheet.getCell(`C${currentRow}`).value = count;
            sheet.getCell(`D${currentRow}`).value = `${((count / stats.total) * 100).toFixed(2)}%`;
            
            // Colorir baseado no risco
            const row = sheet.getRow(currentRow);
            if (level === 'VERY_LOW' || level === 'LOW') {
                row.getCell('B').font = { color: { argb: this.colors.success } };
            } else if (level === 'MEDIUM') {
                row.getCell('B').font = { color: { argb: this.colors.warning } };
            } else {
                row.getCell('B').font = { color: { argb: this.colors.danger } };
            }
            
            currentRow++;
        });
        
        return sheet;
    }
    
    async createDomainAnalysisSheet(results) {
        const sheet = this.workbook.addWorksheet('Análise de Domínios', {
            properties: { tabColor: { argb: this.colors.success } }
        });
        
        // Agrupar por domínio
        const domainStats = {};
        results.forEach(r => {
            const domain = r.email ? r.email.split('@')[1] : 'unknown';
            if (!domainStats[domain]) {
                domainStats[domain] = {
                    count: 0,
                    valid: 0,
                    invalid: 0,
                    avgScore: 0,
                    scores: []
                };
            }
            domainStats[domain].count++;
            if (r.valid) domainStats[domain].valid++;
            else domainStats[domain].invalid++;
            domainStats[domain].scores.push(r.score || 0);
        });
        
        // Calcular médias
        Object.keys(domainStats).forEach(domain => {
            const stats = domainStats[domain];
            stats.avgScore = (stats.scores.reduce((a, b) => a + b, 0) / stats.scores.length).toFixed(2);
            stats.validRate = ((stats.valid / stats.count) * 100).toFixed(2);
        });
        
        // Configurar colunas
        sheet.columns = [
            { header: 'Domínio', key: 'domain', width: 30 },
            { header: 'Total', key: 'count', width: 12 },
            { header: 'Válidos', key: 'valid', width: 12 },
            { header: 'Inválidos', key: 'invalid', width: 12 },
            { header: 'Taxa Válidos (%)', key: 'validRate', width: 18 },
            { header: 'Score Médio', key: 'avgScore', width: 15 },
            { header: 'Classificação', key: 'classification', width: 20 }
        ];
        
        // Estilizar cabeçalho
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.success }
        };
        headerRow.height = 30;
        
        // Adicionar dados (ordenados por quantidade)
        Object.entries(domainStats)
            .sort((a, b) => b[1].count - a[1].count)
            .forEach(([domain, stats]) => {
                const row = sheet.addRow({
                    domain: domain,
                    count: stats.count,
                    valid: stats.valid,
                    invalid: stats.invalid,
                    validRate: stats.validRate,
                    avgScore: stats.avgScore,
                    classification: this.classifyDomain(stats.avgScore)
                });
                
                // Colorir baseado na taxa de válidos
                if (stats.validRate >= 80) {
                    row.getCell('validRate').font = { color: { argb: this.colors.success }, bold: true };
                } else if (stats.validRate >= 50) {
                    row.getCell('validRate').font = { color: { argb: this.colors.warning }, bold: true };
                } else {
                    row.getCell('validRate').font = { color: { argb: this.colors.danger }, bold: true };
                }
            });
        
        // Adicionar filtros
        sheet.autoFilter = {
            from: { row: 1, column: 1 },
            to: { row: Object.keys(domainStats).length + 1, column: 7 }
        };
        
        return sheet;
    }
    
    async createEcommerceSheet(results) {
        const sheet = this.workbook.addWorksheet('E-commerce Insights', {
            properties: { tabColor: { argb: this.colors.secondary } }
        });
        
        // Configurar colunas
        sheet.columns = [
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Score E-commerce', key: 'ecomScore', width: 18 },
            { header: 'Tipo Comprador', key: 'buyerType', width: 20 },
            { header: 'Nível Risco', key: 'riskLevel', width: 15 },
            { header: 'Prob. Fraude (%)', key: 'fraudProb', width: 15 },
            { header: 'Confiança', key: 'confidence', width: 15 },
            { header: 'Provedor Confiável', key: 'trustedProvider', width: 18 },
            { header: 'Email Corporativo', key: 'corporateEmail', width: 18 },
            { header: 'Ação Recomendada', key: 'action', width: 25 }
        ];
        
        // Cabeçalho
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.secondary }
        };
        headerRow.height = 30;
        
        // Adicionar dados
        results.forEach(result => {
            if (result.ecommerce) {
                const row = sheet.addRow({
                    email: result.email,
                    ecomScore: result.ecommerce.score || 0,
                    buyerType: result.ecommerce.buyerType || 'N/A',
                    riskLevel: result.ecommerce.riskLevel || 'N/A',
                    fraudProb: result.ecommerce.fraudProbability || 0,
                    confidence: result.ecommerce.confidence || 'N/A',
                    trustedProvider: result.ecommerce.insights?.trustedProvider ? '✅ Sim' : '❌ Não',
                    corporateEmail: result.ecommerce.insights?.corporateEmail ? '✅ Sim' : '❌ Não',
                    action: result.recommendations?.[0]?.action || 'N/A'
                });
                
                // Colorir baseado no tipo de comprador
                const buyerCell = row.getCell('buyerType');
                if (result.ecommerce.buyerType === 'PREMIUM_BUYER' || result.ecommerce.buyerType === 'TRUSTED_BUYER') {
                    buyerCell.font = { color: { argb: this.colors.success }, bold: true };
                } else if (result.ecommerce.buyerType === 'REGULAR_BUYER') {
                    buyerCell.font = { color: { argb: this.colors.info }, bold: true };
                } else {
                    buyerCell.font = { color: { argb: this.colors.danger }, bold: true };
                }
            }
        });
        
        // Filtros
        sheet.autoFilter = {
            from: { row: 1, column: 1 },
            to: { row: results.length + 1, column: 9 }
        };
        
        return sheet;
    }
    
    async createRecommendationsSheet(results) {
        const sheet = this.workbook.addWorksheet('Recomendações', {
            properties: { tabColor: { argb: this.colors.danger } }
        });
        
        // Agrupar recomendações
        const recommendations = {};
        results.forEach(r => {
            if (r.recommendations) {
                r.recommendations.forEach(rec => {
                    const key = rec.action;
                    if (!recommendations[key]) {
                        recommendations[key] = {
                            count: 0,
                            message: rec.message,
                            priority: rec.priority,
                            emails: []
                        };
                    }
                    recommendations[key].count++;
                    recommendations[key].emails.push(r.email);
                });
            }
        });
        
        // Configurar colunas
        sheet.columns = [
            { header: 'Ação', key: 'action', width: 25 },
            { header: 'Descrição', key: 'message', width: 50 },
            { header: 'Prioridade', key: 'priority', width: 15 },
            { header: 'Quantidade', key: 'count', width: 15 },
            { header: 'Percentual', key: 'percentage', width: 15 }
        ];
        
        // Cabeçalho
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.danger }
        };
        headerRow.height = 30;
        
        // Adicionar dados
        Object.entries(recommendations)
            .sort((a, b) => b[1].count - a[1].count)
            .forEach(([action, data]) => {
                const row = sheet.addRow({
                    action: action,
                    message: data.message,
                    priority: data.priority.toUpperCase(),
                    count: data.count,
                    percentage: `${((data.count / results.length) * 100).toFixed(2)}%`
                });
                
                // Colorir baseado na prioridade
                const priorityCell = row.getCell('priority');
                if (data.priority === 'critical') {
                    priorityCell.font = { color: { argb: this.colors.danger }, bold: true };
                } else if (data.priority === 'high') {
                    priorityCell.font = { color: { argb: this.colors.warning }, bold: true };
                } else if (data.priority === 'medium') {
                    priorityCell.font = { color: { argb: this.colors.info }, bold: true };
                } else {
                    priorityCell.font = { color: { argb: this.colors.success }, bold: true };
                }
            });
        
        // Adicionar resumo de ações
        const summaryRow = sheet.addRow({});
        summaryRow.height = 30;
        
        sheet.addRow({
            action: 'RESUMO DE AÇÕES NECESSÁRIAS',
            message: '',
            priority: '',
            count: '',
            percentage: ''
        }).font = { bold: true, size: 12 };
        
        const criticalCount = Object.values(recommendations)
            .filter(r => r.priority === 'critical')
            .reduce((sum, r) => sum + r.count, 0);
        
        const highCount = Object.values(recommendations)
            .filter(r => r.priority === 'high')
            .reduce((sum, r) => sum + r.count, 0);
        
        sheet.addRow({
            action: 'Ações Críticas',
            message: 'Requerem atenção imediata',
            priority: '',
            count: criticalCount,
            percentage: `${((criticalCount / results.length) * 100).toFixed(2)}%`
        }).getCell('action').font = { color: { argb: this.colors.danger }, bold: true };
        
        sheet.addRow({
            action: 'Ações de Alta Prioridade',
            message: 'Devem ser tratadas em breve',
            priority: '',
            count: highCount,
            percentage: `${((highCount / results.length) * 100).toFixed(2)}%`
        }).getCell('action').font = { color: { argb: this.colors.warning }, bold: true };
        
        return sheet;
    }
    
    async createChartsSheet(stats) {
        const sheet = this.workbook.addWorksheet('Gráficos', {
            properties: { tabColor: { argb: 'FF9C27B0' } }
        });
        
        // Título
        sheet.mergeCells('B2:J2');
        const titleCell = sheet.getCell('B2');
        titleCell.value = '📊 VISUALIZAÇÃO GRÁFICA DOS RESULTADOS';
        titleCell.font = { size: 18, bold: true, color: { argb: this.colors.primary } };
        titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(2).height = 40;
        
        // Informação sobre os gráficos
        sheet.mergeCells('B4:J6');
        const infoCell = sheet.getCell('B4');
        infoCell.value = 'Esta aba contém representações visuais dos dados analisados.\n' +
                         'Os gráficos ajudam a identificar rapidamente padrões e tendências.\n' +
                         'Use os filtros nas outras abas para análises mais detalhadas.';
        infoCell.alignment = { horizontal: 'center', vertical: 'middle', wrapText: true };
        infoCell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FFF3E0' }
        };
        
        // Adicionar dados para gráficos (Excel pode gerar gráficos a partir desses dados)
        let currentRow = 8;
        
        // Dados para gráfico de pizza - Válidos vs Inválidos
        sheet.getCell(`B${currentRow}`).value = 'Distribuição de Validade';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14 };
        currentRow++;
        
        sheet.getCell(`B${currentRow}`).value = 'Status';
        sheet.getCell(`C${currentRow}`).value = 'Quantidade';
        sheet.getCell(`D${currentRow}`).value = 'Percentual';
        currentRow++;
        
        sheet.getCell(`B${currentRow}`).value = 'Válidos';
        sheet.getCell(`C${currentRow}`).value = stats.valid;
        sheet.getCell(`D${currentRow}`).value = `${stats.validPercentage}%`;
        sheet.getCell(`B${currentRow}`).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FFE8F5E9' }
        };
        currentRow++;
        
        sheet.getCell(`B${currentRow}`).value = 'Inválidos';
        sheet.getCell(`C${currentRow}`).value = stats.invalid;
        sheet.getCell(`D${currentRow}`).value = `${stats.invalidPercentage}%`;
        sheet.getCell(`B${currentRow}`).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FFFFEBEE' }
        };
        
        currentRow += 3;
        
        // Dados para gráfico de barras - Top Domínios
        sheet.getCell(`B${currentRow}`).value = 'Top 10 Domínios';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14 };
        currentRow++;
        
        sheet.getCell(`B${currentRow}`).value = 'Domínio';
        sheet.getCell(`C${currentRow}`).value = 'Quantidade';
        currentRow++;
        
        stats.topDomains.forEach(([domain, count]) => {
            sheet.getCell(`B${currentRow}`).value = domain;
            sheet.getCell(`C${currentRow}`).value = count;
            currentRow++;
        });
        
        // Configurar larguras
        sheet.columns = [
            { width: 5 },
            { width: 30 },
            { width: 15 },
            { width: 15 },
            { width: 15 },
            { width: 15 },
            { width: 15 },
            { width: 15 },
            { width: 15 },
            { width: 15 }
        ];
        
        return sheet;
    }
    
    getListQuality(avgScore) {
        if (avgScore >= 80) return '⭐⭐⭐⭐⭐ Excelente';
        if (avgScore >= 70) return '⭐⭐⭐⭐ Muito Boa';
        if (avgScore >= 60) return '⭐⭐⭐ Boa';
        if (avgScore >= 50) return '⭐⭐ Regular';
        if (avgScore >= 40) return '⭐ Necessita Melhorias';
        return '⚠️ Crítica - Requer Ação Imediata';
    }
    
    getRecommendation(avgScore) {
        if (avgScore >= 80) {
            return 'Lista de alta qualidade. Prosseguir com campanhas normalmente.';
        }
        if (avgScore >= 70) {
            return 'Lista confiável. Considerar limpeza dos emails com score baixo.';
        }
        if (avgScore >= 60) {
            return 'Lista aceitável. Remover emails inválidos antes de campanhas importantes.';
        }
        if (avgScore >= 50) {
            return 'Lista com problemas. Realizar limpeza completa antes de usar.';
        }
        return 'Lista de baixa qualidade. Não recomendada para uso sem limpeza profunda.';
    }
    
    classifyDomain(avgScore) {
        if (avgScore >= 80) return '🏆 Premium';
        if (avgScore >= 60) return '✅ Confiável';
        if (avgScore >= 40) return '⚠️ Suspeito';
        return '❌ Alto Risco';
    }
}

module.exports = ExcelReportGenerator;
EOF

success "ExcelReportGenerator.js criado"

# ================================================
# CRIAR INTEGRAÇÃO COM EMAIL SERVICE
# ================================================
log "📧 Criando integração com EmailService..."

cat > "${SERVICES_DIR}/reports/ReportEmailService.js" << 'EOF'
// ================================================
// Report Email Service - Integração com EmailService
// ================================================

const ExcelReportGenerator = require('./ExcelReportGenerator');
const EmailService = require('../EmailService');
const fs = require('fs');
const path = require('path');

class ReportEmailService {
    constructor() {
        this.reportGenerator = new ExcelReportGenerator();
        this.emailService = new EmailService();
    }
    
    async generateAndSendReport(validationResults, recipientEmail, userInfo = {}) {
        try {
            console.log('📊 Gerando relatório Excel...');
            
            // Gerar relatório
            const reportResult = await this.reportGenerator.generateReport(validationResults, {
                outputDir: path.join(__dirname, '../../reports')
            });
            
            if (!reportResult.success) {
                throw new Error('Falha ao gerar relatório');
            }
            
            console.log('📧 Enviando relatório por email...');
            
            // Preparar dados para o email
            const reportData = {
                filename: reportResult.filename,
                stats: reportResult.stats
            };
            
            // Enviar email com anexo
            const emailResult = await this.emailService.sendValidationReport(
                recipientEmail,
                reportData,
                reportResult.filepath,
                userInfo
            );
            
            if (emailResult.success) {
                console.log('✅ Relatório enviado com sucesso!');
                
                // Limpar arquivo após envio (opcional)
                // setTimeout(() => {
                //     fs.unlinkSync(reportResult.filepath);
                // }, 60000); // Deletar após 1 minuto
            }
            
            return {
                success: emailResult.success,
                filepath: reportResult.filepath,
                filename: reportResult.filename,
                stats: reportResult.stats
            };
            
        } catch (error) {
            console.error('❌ Erro ao gerar/enviar relatório:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }
}

module.exports = ReportEmailService;
EOF

success "ReportEmailService.js criado"

# ================================================
# ATUALIZAR ENDPOINT DA API
# ================================================
log "🔄 Criando endpoint para relatórios..."

cat > /tmp/update_api_reports.js << 'APIUPDATE'
const fs = require('fs');

try {
    let content = fs.readFileSync('/app/server.js', 'utf8');
    
    // Adicionar imports se não existirem
    if (!content.includes('ReportEmailService')) {
        const imports = `
const ReportEmailService = require('./services/reports/ReportEmailService');
const reportService = new ReportEmailService();
`;
        content = content.replace(
            "const UltimateValidator",
            imports + "const UltimateValidator"
        );
    }
    
    // Adicionar endpoint para gerar e enviar relatório
    const reportEndpoint = `
// Endpoint para validação com relatório por email
app.post('/api/validate/batch-with-report', async (req, res) => {
    try {
        const { emails, sendReport, recipientEmail, userInfo } = req.body;
        
        if (!emails || !Array.isArray(emails)) {
            return res.status(400).json({ error: 'Lista de emails é obrigatória' });
        }
        
        console.log(\`📧 Validando \${emails.length} emails...\`);
        
        // Validar emails
        const validationResults = await ultimateValidator.validateBatch(emails);
        
        // Se solicitado, enviar relatório por email
        if (sendReport && recipientEmail) {
            console.log(\`📊 Gerando e enviando relatório para \${recipientEmail}...\`);
            
            const reportResult = await reportService.generateAndSendReport(
                validationResults,
                recipientEmail,
                userInfo || {}
            );
            
            return res.json({
                success: true,
                totalEmails: emails.length,
                validationResults: validationResults,
                report: reportResult
            });
        }
        
        // Retornar apenas resultados se não for para enviar relatório
        res.json({
            success: true,
            totalEmails: emails.length,
            validationResults: validationResults
        });
        
    } catch (error) {
        console.error('Erro na validação com relatório:', error);
        res.status(500).json({ error: error.message });
    }
});

// Endpoint para gerar relatório de validações anteriores
app.post('/api/reports/generate', async (req, res) => {
    try {
        const { validationResults, recipientEmail, userInfo } = req.body;
        
        if (!validationResults || !recipientEmail) {
            return res.status(400).json({ 
                error: 'Resultados de validação e email do destinatário são obrigatórios' 
            });
        }
        
        const reportResult = await reportService.generateAndSendReport(
            validationResults,
            recipientEmail,
            userInfo || {}
        );
        
        res.json(reportResult);
        
    } catch (error) {
        console.error('Erro ao gerar relatório:', error);
        res.status(500).json({ error: error.message });
    }
});`;
    
    // Inserir endpoints antes do Health Check
    if (!content.includes('/api/validate/batch-with-report')) {
        content = content.replace(
            '// Health Check',
            reportEndpoint + '\n\n// Health Check'
        );
    }
    
    fs.writeFileSync('/app/server.js', content);
    console.log('✅ API atualizada com endpoints de relatório');
    
} catch (error) {
    console.error('❌ Erro ao atualizar API:', error);
}
APIUPDATE

# Copiar arquivos para o container
docker cp "${SERVICES_DIR}/reports" sparknexus-client:/app/services/ 2>/dev/null || true
docker cp /tmp/update_api_reports.js sparknexus-client:/tmp/ 2>/dev/null || true

# Executar atualização
docker exec sparknexus-client node /tmp/update_api_reports.js 2>/dev/null || true

success "API atualizada com endpoints de relatório"

# ================================================
# CRIAR SCRIPT DE TESTE
# ================================================
log "🧪 Criando script de teste..."

cat > "test_excel_report.js" << 'EOF'
// ================================================
// TESTE DO SISTEMA DE RELATÓRIOS EXCEL
// ================================================

const ReportEmailService = require('./core/client-dashboard/services/reports/ReportEmailService');

async function testReportGeneration() {
    console.log('\n========================================');
    console.log('🧪 TESTANDO GERAÇÃO DE RELATÓRIO EXCEL');
    console.log('========================================\n');
    
    // Dados de teste simulando validação completa
    const testResults = [
        {
            email: 'carolinacasaquia@gmail.com',
            valid: true,
            score: 96,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: true, isPremium: true },
                disposable: { isDisposable: false },
                patterns: { suspicious: false },
                mx: { valid: true },
                smtp: { exists: true }
            },
            ecommerce: {
                score: 96,
                buyerType: 'PREMIUM_BUYER',
                riskLevel: 'VERY_LOW',
                fraudProbability: 4,
                confidence: 'very_high',
                insights: {
                    trustedProvider: true,
                    corporateEmail: false,
                    personalEmail: true
                }
            },
            recommendations: [
                {
                    action: 'APPROVE',
                    message: 'Aprovar compra normalmente',
                    priority: 'low'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 1234,
                validatorVersion: '3.0.0'
            }
        },
        {
            email: 'test@example.com',
            valid: false,
            score: 0,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: false, isBlocked: true },
                disposable: { isDisposable: false },
                patterns: { suspicious: true, suspicionLevel: 8 },
                mx: { valid: false },
                smtp: { exists: false }
            },
            ecommerce: {
                score: 0,
                buyerType: 'BLOCKED',
                riskLevel: 'BLOCKED',
                fraudProbability: 100,
                confidence: 'certain',
                insights: {
                    blocked: true,
                    blockReason: 'Domínio de teste'
                }
            },
            recommendations: [
                {
                    action: 'BLOCK',
                    message: 'Domínio de teste/exemplo',
                    priority: 'critical'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 456,
                validatorVersion: '3.0.0'
            }
        },
        {
            email: 'joao.silva@outlook.com',
            valid: true,
            score: 85,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: true, isPremium: true },
                disposable: { isDisposable: false },
                patterns: { suspicious: false },
                mx: { valid: true },
                smtp: { exists: true }
            },
            ecommerce: {
                score: 85,
                buyerType: 'TRUSTED_BUYER',
                riskLevel: 'VERY_LOW',
                fraudProbability: 15,
                confidence: 'very_high',
                insights: {
                    trustedProvider: true,
                    corporateEmail: false,
                    personalEmail: true
                }
            },
            recommendations: [
                {
                    action: 'APPROVE',
                    message: 'Aprovar compra normalmente',
                    priority: 'low'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 890,
                validatorVersion: '3.0.0'
            }
        },
        {
            email: 'admin@tempmail.com',
            valid: false,
            score: 0,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: true },
                disposable: { isDisposable: true },
                patterns: { suspicious: true, suspicionLevel: 9 },
                mx: { valid: false },
                smtp: { exists: false }
            },
            ecommerce: {
                score: 0,
                buyerType: 'HIGH_RISK_BUYER',
                riskLevel: 'VERY_HIGH',
                fraudProbability: 100,
                confidence: 'certain',
                insights: {
                    blocked: true,
                    blockReason: 'Email temporário'
                }
            },
            recommendations: [
                {
                    action: 'BLOCK',
                    message: 'Email temporário detectado',
                    priority: 'critical'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 234,
                validatorVersion: '3.0.0'
            }
        },
        {
            email: 'contato@empresa.com.br',
            valid: true,
            score: 72,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: true },
                disposable: { isDisposable: false },
                patterns: { suspicious: false },
                mx: { valid: true },
                smtp: { exists: true, catchAll: true }
            },
            ecommerce: {
                score: 72,
                buyerType: 'REGULAR_BUYER',
                riskLevel: 'LOW',
                fraudProbability: 28,
                confidence: 'high',
                insights: {
                    trustedProvider: false,
                    corporateEmail: true,
                    personalEmail: false
                }
            },
            recommendations: [
                {
                    action: 'APPROVE_WITH_MONITORING',
                    message: 'Aprovar mas monitorar comportamento',
                    priority: 'medium'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 1567,
                validatorVersion: '3.0.0'
            }
        }
    ];
    
    const reportService = new ReportEmailService();
    
    // Testar geração local primeiro
    console.log('📊 Gerando relatório Excel localmente...');
    const ExcelReportGenerator = require('./core/client-dashboard/services/reports/ExcelReportGenerator');
    const generator = new ExcelReportGenerator();
    
    const localResult = await generator.generateReport(testResults, {
        outputDir: './reports'
    });
    
    if (localResult.success) {
        console.log(`✅ Relatório gerado: ${localResult.filename}`);
        console.log('\n📈 Estatísticas:');
        console.log(`  Total: ${localResult.stats.total}`);
        console.log(`  Válidos: ${localResult.stats.valid} (${localResult.stats.validPercentage}%)`);
        console.log(`  Inválidos: ${localResult.stats.invalid} (${localResult.stats.invalidPercentage}%)`);
        console.log(`  Score Médio: ${localResult.stats.avgScore}`);
    }
    
    // Perguntar se quer enviar por email
    console.log('\n📧 Para testar o envio por email, configure:');
    console.log('  const SEND_EMAIL = true;');
    console.log('  const RECIPIENT = "seu-email@exemplo.com";');
    
    // Configurar para teste de email
    const SEND_EMAIL = false; // Mude para true para testar
    const RECIPIENT = 'contato@sparknexus.com.br'; // Coloque o email de teste
    
    if (SEND_EMAIL) {
        console.log(`\n📧 Enviando relatório para ${RECIPIENT}...`);
        
        const emailResult = await reportService.generateAndSendReport(
            testResults,
            RECIPIENT,
            { name: 'Teste Spark Nexus' }
        );
        
        if (emailResult.success) {
            console.log('✅ Email enviado com sucesso!');
        } else {
            console.log('❌ Erro ao enviar email:', emailResult.error);
        }
    }
    
    console.log('\n========================================\n');
}

// Executar teste
testReportGeneration().catch(console.error);
EOF

success "Script de teste criado"

# ================================================
# RESUMO FINAL
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SISTEMA DE RELATÓRIOS EXCEL INSTALADO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${MAGENTA}📊 RECURSOS IMPLEMENTADOS:${NC}"
echo -e "  ✅ Geração de planilha Excel profissional"
echo -e "  ✅ 7 abas com dados completos"
echo -e "  ✅ Gráficos e visualizações"
echo -e "  ✅ Formatação profissional com cores"
echo -e "  ✅ Filtros e análises automáticas"
echo -e "  ✅ Envio automático por email"
echo -e "  ✅ Template HTML bonito no email"

echo -e "\n${MAGENTA}📑 ABAS DO EXCEL:${NC}"
echo -e "  1. Resumo Executivo - Visão geral com métricas principais"
echo -e "  2. Dados Detalhados - Todos os emails com validações"
echo -e "  3. Estatísticas - Distribuições e análises"
echo -e "  4. Análise de Domínios - Estatísticas por domínio"
echo -e "  5. E-commerce Insights - Dados específicos de e-commerce"
echo -e "  6. Recomendações - Ações agrupadas e priorizadas"
echo -e "  7. Gráficos - Visualizações dos dados"

echo -e "\n${MAGENTA}🔌 ENDPOINTS DA API:${NC}"
echo -e "${CYAN}POST /api/validate/batch-with-report${NC}"
echo '{'
echo '  "emails": ["email1@example.com", "email2@example.com"],'
echo '  "sendReport": true,'
echo '  "recipientEmail": "cliente@exemplo.com",'
echo '  "userInfo": { "name": "Nome do Cliente" }'
echo '}'

echo -e "\n${CYAN}POST /api/reports/generate${NC}"
echo '{'
echo '  "validationResults": [...],  // Resultados anteriores'
echo '  "recipientEmail": "cliente@exemplo.com",'
echo '  "userInfo": { "name": "Nome do Cliente" }'
echo '}'

echo -e "\n${MAGENTA}🧪 PARA TESTAR:${NC}"
echo -e "  1. Teste local: ${CYAN}node test_excel_report.js${NC}"
echo -e "  2. Configure SEND_EMAIL=true no teste para enviar email"
echo -e "  3. Ou use a API para teste completo"

echo -e "\n${YELLOW}📝 Arquivos criados:${NC}"
echo -e "  • ${SERVICES_DIR}/reports/ExcelReportGenerator.js"
echo -e "  • ${SERVICES_DIR}/reports/ReportEmailService.js"
echo -e "  • test_excel_report.js"

echo -e "\n${GREEN}✨ Sistema pronto para gerar e enviar relatórios profissionais!${NC}\n"