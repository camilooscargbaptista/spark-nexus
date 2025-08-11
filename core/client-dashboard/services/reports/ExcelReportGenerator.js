// ================================================
// Excel Report Generator - VERSÃO MELHORADA
// Com traduções amigáveis e formatação aprimorada
// ================================================

const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');
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

        // Mapeamento de traduções para mensagens amigáveis
        this.translations = {
            // Tipos de compradores
            buyerTypes: {
                'TRUSTED_BUYER': 'Comprador Confiável',
                'REGULAR_BUYER': 'Comprador Regular',
                'NEW_BUYER': 'Novo Comprador',
                'SUSPICIOUS_BUYER': 'Comprador Suspeito',
                'HIGH_RISK_BUYER': 'Comprador Alto Risco',
                'BLOCKED': 'Bloqueado',
                'INVALID': 'Inválido',
                'unknown': '-----'
            },

            // Níveis de risco
            riskLevels: {
                'VERY_LOW': 'Muito Baixo',
                'LOW': 'Baixo',
                'MEDIUM': 'Médio',
                'HIGH': 'Alto',
                'VERY_HIGH': 'Muito Alto',
                'BLOCKED': 'Bloqueado',
                'unknown': '-----'
            },

            // Níveis de confiança
            confidence: {
                'very_high': 'Muito Alta',
                'high': 'Alta',
                'medium': 'Média',
                'low': 'Baixa',
                'very_low': 'Muito Baixa',
                'certain': 'Absoluta',
                'none': 'Nenhuma',
                'unknown': '-----'
            },

            // Ações de recomendação
            actions: {
                'APPROVE': 'Aprovar',
                'REJECT': 'Rejeitar',
                'BLOCK': 'Bloquear',
                'MANUAL_REVIEW': 'Revisão Manual',
                'REQUEST_VERIFICATION': 'Solicitar Verificação',
                'SUGGEST_ALTERNATIVE': 'Sugerir Alternativa',
                'WARNING': 'Atenção',
                'unknown': '-----'
            },

            // Prioridades
            priorities: {
                'critical': 'Crítica',
                'high': 'Alta',
                'medium': 'Média',
                'low': 'Baixa',
                'unknown': '-----'
            }
        };
    }

    // Função auxiliar para traduzir valores
    translate(value, category) {
        if (!value || value === 'N/A' || value === null || value === undefined) {
            return '-----';
        }

        if (this.translations[category] && this.translations[category][value]) {
            return this.translations[category][value];
        }

        return value;
    }

    // Função auxiliar para formatar valores
    formatValue(value, type = 'text') {
        if (value === null || value === undefined || value === 'N/A' || value === '') {
            return '-----';
        }

        switch(type) {
            case 'boolean':
                return value ? 'Sim' : 'Não';
            case 'percentage':
                return `${value}%`;
            case 'number':
                return typeof value === 'number' ? value.toFixed(2) : '-----';
            case 'integer':
                return typeof value === 'number' ? Math.round(value) : '-----';
            default:
                return value;
        }
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
        const total = results.length || 0;
        const valid = results.filter(r => r.valid).length || 0;
        const invalid = total - valid;
        const avgScore = total > 0 ? results.reduce((sum, r) => sum + (r.score || 0), 0) / total : 0;

        // Distribuição por tipo de comprador
        const buyerTypes = {};
        results.forEach(r => {
            if (r.ecommerce && r.ecommerce.buyerType) {
                const translatedType = this.translate(r.ecommerce.buyerType, 'buyerTypes');
                buyerTypes[translatedType] = (buyerTypes[translatedType] || 0) + 1;
            }
        });

        // Distribuição por nível de risco
        const riskLevels = {};
        results.forEach(r => {
            if (r.ecommerce && r.ecommerce.riskLevel) {
                const translatedRisk = this.translate(r.ecommerce.riskLevel, 'riskLevels');
                riskLevels[translatedRisk] = (riskLevels[translatedRisk] || 0) + 1;
            }
        });

        // Domínios mais frequentes
        const domains = {};
        results.forEach(r => {
            const domain = r.email ? r.email.split('@')[1] : '-----';
            domains[domain] = (domains[domain] || 0) + 1;
        });

        const topDomains = Object.entries(domains)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10);

        return {
            total,
            valid,
            invalid,
            validPercentage: total > 0 ? ((valid / total) * 100).toFixed(2) : '0',
            invalidPercentage: total > 0 ? ((invalid / total) * 100).toFixed(2) : '0',
            avgScore: avgScore.toFixed(2),
            reliabilityRate: total > 0 ? ((results.filter(r => r.score >= 70).length / total) * 100).toFixed(2) : '0',
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
            { width: 35 },
            { width: 25 },
            { width: 20 },
            { width: 20 }
        ];

        // Título
        sheet.mergeCells('B2:E2');
        const titleCell = sheet.getCell('B2');
        titleCell.value = 'RELATÓRIO DE VALIDAÇÃO DE EMAILS';
        titleCell.font = { name: 'Arial', size: 18, bold: true, color: { argb: this.colors.primary } };
        titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(2).height = 40;

        // Data
        sheet.mergeCells('B3:E3');
        const dateCell = sheet.getCell('B3');
        dateCell.value = `Gerado em: ${moment().format('DD/MM/YYYY HH:mm:ss')}`;
        dateCell.font = { name: 'Arial', size: 11, italic: true };
        dateCell.alignment = { horizontal: 'center' };

        // Seção de Métricas Principais
        let currentRow = 5;
        sheet.getCell(`B${currentRow}`).value = 'MÉTRICAS PRINCIPAIS';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14, color: { argb: this.colors.dark } };
        currentRow += 2;

        const metrics = [
            { label: 'Total de Emails Processados', value: stats.total },
            { label: 'Emails Válidos', value: `${stats.valid} (${stats.validPercentage}%)`, color: this.colors.success },
            { label: 'Emails Inválidos', value: `${stats.invalid} (${stats.invalidPercentage}%)`, color: this.colors.danger },
            { label: 'Pontuação Média', value: stats.avgScore },
            { label: 'Taxa de Confiabilidade', value: `${stats.reliabilityRate}%` },
            { label: 'Qualidade da Lista', value: this.getListQuality(parseFloat(stats.avgScore)) }
        ];

        metrics.forEach((metric) => {
            sheet.getCell(`B${currentRow}`).value = metric.label;
            sheet.getCell(`B${currentRow}`).font = { name: 'Arial', size: 11 };

            sheet.getCell(`C${currentRow}`).value = metric.value;
            sheet.getCell(`C${currentRow}`).font = {
                name: 'Arial',
                size: 11,
                bold: true,
                color: metric.color ? { argb: metric.color } : undefined
            };

            currentRow++;
        });

        // Seção de Distribuição
        currentRow += 2;
        sheet.getCell(`B${currentRow}`).value = 'DISTRIBUIÇÃO POR TIPO DE COMPRADOR';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14, color: { argb: this.colors.dark } };
        currentRow += 2;

        Object.entries(stats.buyerTypes).forEach(([type, count]) => {
            sheet.getCell(`B${currentRow}`).value = type;
            sheet.getCell(`C${currentRow}`).value = count;
            currentRow++;
        });

        // Seção de Risco
        currentRow += 2;
        sheet.getCell(`B${currentRow}`).value = 'DISTRIBUIÇÃO POR NÍVEL DE RISCO';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14, color: { argb: this.colors.dark } };
        currentRow += 2;

        Object.entries(stats.riskLevels).forEach(([level, count]) => {
            sheet.getCell(`B${currentRow}`).value = level;
            sheet.getCell(`C${currentRow}`).value = count;
            currentRow++;
        });

        // Recomendação geral
        currentRow += 2;
        sheet.mergeCells(`B${currentRow}:E${currentRow}`);
        sheet.getCell(`B${currentRow}`).value = 'RECOMENDAÇÃO GERAL';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14, color: { argb: this.colors.primary } };

        currentRow++;
        sheet.mergeCells(`B${currentRow}:E${currentRow + 1}`);
        sheet.getCell(`B${currentRow}`).value = this.getRecommendation(parseFloat(stats.avgScore));
        sheet.getCell(`B${currentRow}`).font = { size: 12, italic: true };
        sheet.getCell(`B${currentRow}`).alignment = { wrapText: true, vertical: 'top' };

        // Aplicar bordas e estilo
        this.applyStyleToSheet(sheet);

        return sheet;
    }

    async createDetailedDataSheet(results) {
        const sheet = this.workbook.addWorksheet('Dados Detalhados', {
            properties: { tabColor: { argb: this.colors.info } }
        });

        // Configurar colunas com larguras otimizadas
        sheet.columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Válido', key: 'valid', width: 10 },
            { header: 'Pontuação', key: 'score', width: 12 },
            { header: 'Tipo de Comprador', key: 'buyerType', width: 22 },
            { header: 'Nível de Risco', key: 'riskLevel', width: 18 },
            { header: 'Confiança', key: 'confidence', width: 15 },
            { header: 'Recomendação', key: 'recommendation', width: 40 }
        ];

        // Estilizar cabeçalho
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.primary }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 25;

        // Adicionar dados
        results.forEach((result, index) => {
            const recommendation = result.recommendations && result.recommendations[0]
                ? result.recommendations[0].message
                : '-----';

            const row = sheet.addRow({
                index: index + 1,
                email: this.formatValue(result.email),
                valid: this.formatValue(result.valid, 'boolean'),
                score: this.formatValue(result.score, 'integer'),
                buyerType: this.translate(result.ecommerce?.buyerType, 'buyerTypes'),
                riskLevel: this.translate(result.ecommerce?.riskLevel, 'riskLevels'),
                confidence: this.translate(result.ecommerce?.confidence, 'confidence'),
                recommendation: this.formatValue(recommendation)
            });

            // Colorir linha baseado na validade
            if (!result.valid) {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFFFE6E6' }
                };
            }

            // Colorir célula de score baseado no valor
            const scoreCell = row.getCell('score');
            if (result.score >= 80) {
                scoreCell.font = { color: { argb: this.colors.success } };
            } else if (result.score >= 60) {
                scoreCell.font = { color: { argb: this.colors.warning } };
            } else {
                scoreCell.font = { color: { argb: this.colors.danger } };
            }
        });

        // Adicionar filtros
        sheet.autoFilter = {
            from: 'A1',
            to: `H${results.length + 1}`
        };

        return sheet;
    }

    async createStatisticsSheet(stats, results) {
        const sheet = this.workbook.addWorksheet('Estatísticas', {
            properties: { tabColor: { argb: this.colors.secondary } }
        });

        sheet.columns = [
            { width: 35 },
            { width: 20 },
            { width: 20 },
            { width: 20 }
        ];

        // Título
        sheet.getCell('A1').value = 'ANÁLISE ESTATÍSTICA DETALHADA';
        sheet.getCell('A1').font = { size: 16, bold: true, color: { argb: this.colors.primary } };

        // Distribuição de Pontuações
        let currentRow = 3;
        sheet.getCell(`A${currentRow}`).value = 'Distribuição de Pontuações';
        sheet.getCell(`A${currentRow}`).font = { bold: true, size: 12 };
        currentRow++;

        sheet.getCell(`A${currentRow}`).value = 'Faixa';
        sheet.getCell(`B${currentRow}`).value = 'Quantidade';
        sheet.getCell(`C${currentRow}`).value = 'Percentual';
        sheet.getRow(currentRow).font = { bold: true };
        currentRow++;

        const scoreRanges = {
            'Excelente (80-100)': results.filter(r => r.score >= 80 && r.score <= 100).length,
            'Bom (60-79)': results.filter(r => r.score >= 60 && r.score < 80).length,
            'Regular (40-59)': results.filter(r => r.score >= 40 && r.score < 60).length,
            'Ruim (20-39)': results.filter(r => r.score >= 20 && r.score < 40).length,
            'Péssimo (0-19)': results.filter(r => r.score >= 0 && r.score < 20).length
        };

        Object.entries(scoreRanges).forEach(([range, count]) => {
            const percentage = stats.total > 0 ? ((count / stats.total) * 100).toFixed(1) : '0';
            sheet.getCell(`A${currentRow}`).value = range;
            sheet.getCell(`B${currentRow}`).value = count;
            sheet.getCell(`C${currentRow}`).value = `${percentage}%`;
            currentRow++;
        });

        // Estatísticas de Validação
        currentRow += 2;
        sheet.getCell(`A${currentRow}`).value = 'Estatísticas de Validação';
        sheet.getCell(`A${currentRow}`).font = { bold: true, size: 12 };
        currentRow++;

        const validationStats = [
            { label: 'Total de emails processados', value: stats.total },
            { label: 'Emails com pontuação >= 70', value: results.filter(r => r.score >= 70).length },
            { label: 'Emails com pontuação < 50', value: results.filter(r => r.score < 50).length },
            { label: 'Emails bloqueados', value: results.filter(r => r.ecommerce?.buyerType === 'BLOCKED').length },
            { label: 'Emails suspeitos', value: results.filter(r => r.ecommerce?.buyerType === 'SUSPICIOUS_BUYER').length }
        ];

        validationStats.forEach(stat => {
            sheet.getCell(`A${currentRow}`).value = stat.label;
            sheet.getCell(`B${currentRow}`).value = stat.value;
            currentRow++;
        });

        // Top 10 Domínios
        currentRow += 2;
        sheet.getCell(`A${currentRow}`).value = 'Top 10 Domínios Mais Frequentes';
        sheet.getCell(`A${currentRow}`).font = { bold: true, size: 12 };
        currentRow++;

        sheet.getCell(`A${currentRow}`).value = 'Domínio';
        sheet.getCell(`B${currentRow}`).value = 'Quantidade';
        sheet.getCell(`C${currentRow}`).value = 'Percentual';
        sheet.getRow(currentRow).font = { bold: true };
        currentRow++;

        stats.topDomains.forEach(([domain, count]) => {
            const percentage = stats.total > 0 ? ((count / stats.total) * 100).toFixed(1) : '0';
            sheet.getCell(`A${currentRow}`).value = domain;
            sheet.getCell(`B${currentRow}`).value = count;
            sheet.getCell(`C${currentRow}`).value = `${percentage}%`;
            currentRow++;
        });

        return sheet;
    }

    async createDomainAnalysisSheet(results) {
        const sheet = this.workbook.addWorksheet('Análise de Domínios', {
            properties: { tabColor: { argb: this.colors.warning } }
        });

        // Agrupar por domínio
        const domainStats = {};
        results.forEach(r => {
            const domain = r.email ? r.email.split('@')[1] : '-----';
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
            domainStats[domain].scores.push(r.score || 0);
            if (r.valid) domainStats[domain].valid++;
            else domainStats[domain].invalid++;
        });

        // Calcular média de score por domínio
        Object.keys(domainStats).forEach(domain => {
            const scores = domainStats[domain].scores;
            domainStats[domain].avgScore = scores.length > 0
                ? (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(1)
                : '0';
        });

        // Configurar colunas
        sheet.columns = [
            { header: 'Domínio', key: 'domain', width: 30 },
            { header: 'Total', key: 'count', width: 12 },
            { header: 'Válidos', key: 'valid', width: 12 },
            { header: 'Inválidos', key: 'invalid', width: 12 },
            { header: 'Score Médio', key: 'avgScore', width: 15 },
            { header: 'Taxa de Validade', key: 'validRate', width: 18 }
        ];

        // Estilizar cabeçalho
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.warning }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 25;

        // Adicionar dados ordenados por quantidade
        Object.entries(domainStats)
            .sort((a, b) => b[1].count - a[1].count)
            .forEach(([domain, stats]) => {
                const validRate = stats.count > 0
                    ? ((stats.valid / stats.count) * 100).toFixed(1) + '%'
                    : '-----';

                sheet.addRow({
                    domain: domain,
                    count: stats.count,
                    valid: stats.valid,
                    invalid: stats.invalid,
                    avgScore: stats.avgScore,
                    validRate: validRate
                });
            });

        // Adicionar filtros
        sheet.autoFilter = {
            from: 'A1',
            to: `F${Object.keys(domainStats).length + 1}`
        };

        return sheet;
    }

    async createEcommerceSheet(results) {
        const sheet = this.workbook.addWorksheet('Análise E-commerce', {
            properties: { tabColor: { argb: this.colors.success } }
        });

        sheet.columns = [
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Score E-commerce', key: 'ecomScore', width: 18 },
            { header: 'Tipo de Comprador', key: 'buyerType', width: 22 },
            { header: 'Nível de Risco', key: 'riskLevel', width: 18 },
            { header: 'Prob. Fraude (%)', key: 'fraudProb', width: 18 },
            { header: 'Confiança', key: 'confidence', width: 15 },
            { header: 'Ação Recomendada', key: 'action', width: 20 }
        ];

        // Estilizar cabeçalho
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.success }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 25;

        // Filtrar apenas emails com dados de e-commerce
        const ecommerceData = results.filter(r => r.ecommerce);

        ecommerceData.forEach(result => {
            const firstRecommendation = result.recommendations && result.recommendations[0]
                ? this.translate(result.recommendations[0].action, 'actions')
                : '-----';

            const row = sheet.addRow({
                email: this.formatValue(result.email),
                ecomScore: this.formatValue(result.ecommerce.finalScore || result.ecommerce.score, 'integer'),
                buyerType: this.translate(result.ecommerce.buyerType, 'buyerTypes'),
                riskLevel: this.translate(result.ecommerce.riskLevel, 'riskLevels'),
                fraudProb: this.formatValue(result.ecommerce.fraudProbability, 'integer'),
                confidence: this.translate(result.ecommerce.confidence, 'confidence'),
                action: firstRecommendation
            });

            // Colorir linha baseado no risco
            const riskLevel = result.ecommerce.riskLevel;
            if (riskLevel === 'VERY_HIGH' || riskLevel === 'HIGH') {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFFFE6E6' }
                };
            } else if (riskLevel === 'MEDIUM') {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFFFF3E6' }
                };
            }
        });

        // Adicionar filtros
        sheet.autoFilter = {
            from: 'A1',
            to: `G${ecommerceData.length + 1}`
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
                    const translatedAction = this.translate(rec.action, 'actions');
                    const key = `${translatedAction}_${rec.message}`;
                    if (!recommendations[key]) {
                        recommendations[key] = {
                            action: translatedAction,
                            message: rec.message,
                            priority: this.translate(rec.priority, 'priorities'),
                            count: 0,
                            emails: []
                        };
                    }
                    recommendations[key].count++;
                    if (recommendations[key].emails.length < 5) {
                        recommendations[key].emails.push(r.email);
                    }
                });
            }
        });

        sheet.columns = [
            { header: 'Ação', key: 'action', width: 20 },
            { header: 'Descrição', key: 'message', width: 50 },
            { header: 'Prioridade', key: 'priority', width: 15 },
            { header: 'Quantidade', key: 'count', width: 15 },
            { header: 'Exemplos de Emails', key: 'examples', width: 60 }
        ];

        // Estilizar cabeçalho
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.danger }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 25;

        // Ordenar por prioridade e quantidade
        const priorityOrder = { 'Crítica': 0, 'Alta': 1, 'Média': 2, 'Baixa': 3, '-----': 4 };

        Object.values(recommendations)
            .sort((a, b) => {
                const priorityDiff = priorityOrder[a.priority] - priorityOrder[b.priority];
                if (priorityDiff !== 0) return priorityDiff;
                return b.count - a.count;
            })
            .forEach(data => {
                const row = sheet.addRow({
                    action: data.action,
                    message: data.message,
                    priority: data.priority,
                    count: data.count,
                    examples: data.emails.join(', ') || '-----'
                });

                // Colorir baseado na prioridade
                if (data.priority === 'Crítica') {
                    row.getCell('priority').font = { color: { argb: this.colors.danger }, bold: true };
                } else if (data.priority === 'Alta') {
                    row.getCell('priority').font = { color: { argb: this.colors.warning }, bold: true };
                }
            });

        // Adicionar resumo no final
        const summaryRow = sheet.addRow({});
        summaryRow.getCell(1).value = 'RESUMO DAS AÇÕES';
        summaryRow.getCell(1).font = { bold: true, size: 12 };

        const actionSummary = {};
        Object.values(recommendations).forEach(rec => {
            actionSummary[rec.action] = (actionSummary[rec.action] || 0) + rec.count;
        });

        Object.entries(actionSummary)
            .sort((a, b) => b[1] - a[1])
            .forEach(([action, count]) => {
                const row = sheet.addRow({
                    action: action,
                    message: `Total de emails com esta ação: ${count}`,
                    priority: '',
                    count: count,
                    examples: ''
                });
                row.font = { italic: true };
            });

        return sheet;
    }

    applyStyleToSheet(sheet) {
        // Aplicar bordas a todas as células com conteúdo
        sheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
            row.eachCell({ includeEmpty: false }, (cell) => {
                cell.border = {
                    top: { style: 'thin' },
                    left: { style: 'thin' },
                    bottom: { style: 'thin' },
                    right: { style: 'thin' }
                };
            });
        });
    }

    getListQuality(avgScore) {
        if (avgScore >= 80) return 'Excelente - Lista de alta qualidade';
        if (avgScore >= 70) return 'Boa - Lista confiável';
        if (avgScore >= 60) return 'Regular - Necessita limpeza';
        if (avgScore >= 50) return 'Ruim - Muitos emails problemáticos';
        return 'Péssima - Lista não recomendada';
    }

    getRecommendation(avgScore) {
        if (avgScore >= 80) {
            return 'Lista de excelente qualidade! Recomendamos prosseguir com suas campanhas de email marketing. ' +
                   'A maioria dos emails é válida e confiável. Continue monitorando métricas de engajamento.';
        }
        if (avgScore >= 70) {
            return 'Lista de boa qualidade. Recomendamos remover os emails inválidos antes de iniciar campanhas. ' +
                   'Considere implementar dupla confirmação (double opt-in) para novos cadastros.';
        }
        if (avgScore >= 60) {
            return 'Lista regular que necessita limpeza. Remova emails inválidos e suspeitos antes de usar. ' +
                   'Recomendamos validação adicional dos emails com pontuação baixa.';
        }
        if (avgScore >= 50) {
            return 'Lista com muitos problemas. É essencial fazer uma limpeza completa removendo emails inválidos, ' +
                   'suspeitos e de alto risco. Considere implementar um processo de revalidação.';
        }
        return 'Lista de baixa qualidade não recomendada para uso. Mais de 50% dos emails apresentam problemas. ' +
               'Recomendamos reconstruir sua base de dados com processos de validação mais rigorosos.';
    }
}

module.exports = ExcelReportGenerator;
