// ================================================
// Excel Report Generator - VERSÃO FINAL COMPLETA
// Com abas de ação detalhadas e cálculos precisos
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
            dark: 'FF2C3E50',
            correction: 'FF9B59B6',
            criticalBg: 'FFFFEBEE',
            highBg: 'FFFFF3E0',
            mediumBg: 'FFE3F2FD',
            lowBg: 'FFE8F5E9',
            successBg: 'FFE8F5E9',
            grayBg: 'FFF5F5F5'
        };

        this.translations = {
            buyerTypes: {
                'TRUSTED_BUYER': 'Comprador Confiável',
                'REGULAR_BUYER': 'Comprador Regular',
                'NEW_BUYER': 'Novo Comprador',
                'SUSPICIOUS_BUYER': 'Comprador Suspeito',
                'HIGH_RISK_BUYER': 'Comprador Alto Risco',
                'CORRECTED_VALID_BUYER': 'Comprador Confiável',
                'CORRECTED_REGULAR_BUYER': 'Comprador Regular',
                'CORRECTED_SUSPICIOUS_BUYER': 'Comprador Suspeito',
                'CORRECTED_HIGH_RISK_BUYER': 'Alto Risco',
                'BLOCKED': 'Bloqueado',
                'INVALID': 'Inválido',
                'unknown': 'Não Classificado',
                null: 'Não Classificado',
                undefined: 'Não Classificado'
            },
            riskLevels: {
                'VERY_LOW': 'Muito Baixo',
                'LOW': 'Baixo',
                'MEDIUM': 'Médio',
                'HIGH': 'Alto',
                'VERY_HIGH': 'Muito Alto',
                'CRITICAL': 'Crítico',
                'BLOCKED': 'Bloqueado',
                'unknown': 'Não Avaliado'
            },
            confidence: {
                'very_high': 'Muito Alta',
                'high': 'Alta',
                'medium': 'Média',
                'low': 'Baixa',
                'very_low': 'Muito Baixa',
                'certain': 'Absoluta',
                'none': 'Nenhuma',
                'unknown': 'Não Definida'
            }
        };
    }

    // ================================================
    // MÉTODO PRINCIPAL - GERAR RELATÓRIO
    // ================================================
    async generateReport(validationResults, options = {}) {
        const timestamp = moment().format('YYYYMMDD_HHmmss');
        const filename = options.filename || `validation_report_${timestamp}.xlsx`;
        const filepath = path.join(options.outputDir || './reports', filename);

        const dir = path.dirname(filepath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }

        this.workbook = new ExcelJS.Workbook();
        this.workbook.creator = 'Spark Nexus';
        this.workbook.lastModifiedBy = 'Validation System';
        this.workbook.created = new Date();
        this.workbook.modified = new Date();

        // Processar dados e análise
        const stats = this.calculateStatistics(validationResults);
        const analysis = this.analyzeProblems(validationResults);

        // Criar abas na ordem correta
        await this.createSummarySheet(stats);
        await this.createDetailedDataSheet(validationResults);
        await this.createRecommendationsSheet(validationResults, stats, analysis);

        // NOVAS ABAS DE AÇÃO
        await this.createInvalidEmailsSheet(validationResults, analysis);
        await this.createSuspiciousEmailsSheet(validationResults, analysis);
        await this.createCleanListSheet(validationResults, analysis);

        // Abas existentes
        await this.createStatisticsSheet(stats, validationResults);
        await this.createDomainAnalysisSheet(validationResults);
        await this.createCorrectionsSheet(validationResults);
        await this.createEcommerceSheet(validationResults);

        await this.workbook.xlsx.writeFile(filepath);
        console.log(`✅ Relatório Excel gerado: ${filepath}`);

        return {
            success: true,
            filepath: filepath,
            filename: filename,
            stats: stats
        };
    }

    // ================================================
    // CÁLCULO DE ESTATÍSTICAS - TOTALMENTE CORRIGIDO
    // ================================================
    calculateStatistics(results) {
        const total = results.length || 0;

        // CORREÇÃO: Emails válidos são aqueles com score >= 50 OU valid = true
        const validEmails = results.filter(r => {
            return r.valid === true || r.score >= 50;
        });

        const valid = validEmails.length;
        const invalid = total - valid;

        // CORREÇÃO DA TAXA DE CONFIABILIDADE
        // Emails com alta confiança são aqueles com score >= 70
        const highConfidenceEmails = results.filter(r => r.score >= 70);
        const highConfidenceCount = highConfidenceEmails.length;

        // Se temos 2999 válidos de 3000, a taxa deve refletir isso
        const reliabilityRate = total > 0
            ? ((highConfidenceCount / total) * 100).toFixed(2)
            : '0.00';

        // Contar emails REALMENTE corrigidos (não todos os 3000!)
        const corrected = results.filter(r => {
            // Email foi corrigido se tem campo indicando correção E os emails são diferentes
            if (r.wasCorrected || r.correctedDuringParse) {
                const current = (r.correctedEmail || r.email || '').toLowerCase().trim();
                const original = (r.originalEmail || r.normalizedEmail || r.originalBeforeParse || '').toLowerCase().trim();
                return original && current && current !== original;
            }
            return false;
        }).length;

        // Score médio
        const avgScore = total > 0
            ? results.reduce((sum, r) => sum + (r.score || 0), 0) / total
            : 0;

        // CORREÇÃO: Distribuição por tipo de comprador
        // Contar corretamente sem duplicar
        const buyerTypes = {};
        results.forEach(r => {
            let buyerType = r.scoring?.buyerType || r.ecommerce?.buyerType || 'unknown';

            // Simplificar tipos corrigidos
            if (buyerType.startsWith('CORRECTED_')) {
                buyerType = buyerType.replace('CORRECTED_', '');
            }

            const translatedType = this.translate(buyerType, 'buyerTypes');
            buyerTypes[translatedType] = (buyerTypes[translatedType] || 0) + 1;
        });

        // Distribuição por nível de risco
        const riskLevels = {};
        results.forEach(r => {
            const riskLevel = r.scoring?.riskLevel || r.ecommerce?.riskLevel || 'unknown';
            const translatedRisk = this.translate(riskLevel, 'riskLevels');
            riskLevels[translatedRisk] = (riskLevels[translatedRisk] || 0) + 1;
        });

        // Top domínios
        const domains = {};
        results.forEach(r => {
            const email = r.correctedEmail || r.email || '';
            const domain = email.includes('@') ? email.split('@')[1] : 'invalid';
            domains[domain] = (domains[domain] || 0) + 1;
        });

        const topDomains = Object.entries(domains)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10);

        return {
            total,
            valid,
            invalid,
            corrected,
            validPercentage: total > 0 ? ((valid / total) * 100).toFixed(2) : '0.00',
            invalidPercentage: total > 0 ? ((invalid / total) * 100).toFixed(2) : '0.00',
            correctionPercentage: total > 0 ? ((corrected / total) * 100).toFixed(2) : '0.00',
            avgScore: avgScore.toFixed(2),
            reliabilityRate: reliabilityRate,
            highConfidenceCount: highConfidenceCount,
            buyerTypes,
            riskLevels,
            topDomains,
            timestamp: new Date().toISOString()
        };
    }

    // ================================================
    // ANÁLISE DE PROBLEMAS - MELHORADA
    // ================================================
    analyzeProblems(results) {
        const analysis = {
            invalidEmails: [],
            suspiciousEmails: [],
            highQualityEmails: [],
            correctedEmails: [],
            duplicateEmails: [],
            problematicDomains: []
        };

        const domainStats = {};
        const emailCounts = {};

        results.forEach((r, index) => {
            const email = r.correctedEmail || r.email || '';
            const domain = email.includes('@') ? email.split('@')[1] : 'invalid';

            // Criar objeto detalhado para cada email
            const emailDetail = {
                email: email,
                score: r.score || 0,
                valid: r.valid,
                reason: '',
                action: '',
                originalLine: r.originalLine || index + 2,
                buyerType: this.translate(r.scoring?.buyerType || r.ecommerce?.buyerType || 'unknown', 'buyerTypes'),
                riskLevel: this.translate(r.scoring?.riskLevel || r.ecommerce?.riskLevel || 'unknown', 'riskLevels')
            };

            // Classificar emails por qualidade
            if (r.score < 30 || !r.valid) {
                emailDetail.reason = `Score muito baixo (${r.score}). Email inválido ou inexistente.`;
                emailDetail.action = 'REMOVER IMEDIATAMENTE';
                analysis.invalidEmails.push(emailDetail);
            } else if (r.score >= 30 && r.score < 60) {
                emailDetail.reason = `Score baixo (${r.score}). Possível email temporário, inativo ou com problemas.`;
                emailDetail.action = 'REVISAR MANUALMENTE ou SEGMENTAR';
                analysis.suspiciousEmails.push(emailDetail);
            } else if (r.score >= 70) {
                emailDetail.reason = 'Email de alta qualidade';
                emailDetail.action = 'MANTER NA LISTA';
                analysis.highQualityEmails.push(emailDetail);
            }

            // Emails corrigidos (com detalhes)
            const originalEmail = r.originalEmail || r.normalizedEmail || r.originalBeforeParse || '';
            if (originalEmail && email.toLowerCase() !== originalEmail.toLowerCase()) {
                analysis.correctedEmails.push({
                    original: originalEmail,
                    corrected: email,
                    score: r.score,
                    valid: r.valid,
                    line: r.originalLine || index + 2
                });
            }

            // Estatísticas por domínio
            if (domain && domain !== 'invalid') {
                if (!domainStats[domain]) {
                    domainStats[domain] = { total: 0, problems: 0, emails: [] };
                }
                domainStats[domain].total++;
                domainStats[domain].emails.push(email);
                if (!r.valid || r.score < 50) {
                    domainStats[domain].problems++;
                }
            }

            // Contar duplicados
            emailCounts[email] = (emailCounts[email] || 0) + 1;
        });

        // Identificar domínios problemáticos
        Object.entries(domainStats).forEach(([domain, stats]) => {
            const problemRate = stats.problems / stats.total;
            if (problemRate > 0.3 && stats.total >= 3) {
                analysis.problematicDomains.push({
                    domain,
                    total: stats.total,
                    problems: stats.problems,
                    rate: (problemRate * 100).toFixed(1),
                    emails: stats.emails.slice(0, 5)
                });
            }
        });

        // Emails duplicados com detalhes
        Object.entries(emailCounts).forEach(([email, count]) => {
            if (count > 1) {
                const firstOccurrence = results.find(r => (r.correctedEmail || r.email) === email);
                analysis.duplicateEmails.push({
                    email: email,
                    count: count,
                    score: firstOccurrence?.score || 0,
                    action: 'MANTER APENAS UMA OCORRÊNCIA'
                });
            }
        });

        return analysis;
    }

    // ================================================
    // ABA 1: RESUMO EXECUTIVO - CORRIGIDO
    // ================================================
    async createSummarySheet(stats) {
        const sheet = this.workbook.addWorksheet('Resumo Executivo', {
            properties: { tabColor: { argb: this.colors.primary } }
        });

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

        // Métricas Principais
        let currentRow = 5;
        sheet.getCell(`B${currentRow}`).value = 'MÉTRICAS PRINCIPAIS';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14, color: { argb: this.colors.dark } };
        currentRow += 2;

        // CORREÇÃO: Qualidade da lista com ação clara
        let qualityDescription = '';
        let qualityAction = '';
        const avgScore = parseFloat(stats.avgScore);
        const validPercentage = parseFloat(stats.validPercentage);

        if (avgScore >= 70 && validPercentage >= 95) {
            qualityDescription = 'Excelente - Lista pronta para uso';
            qualityAction = 'Lista aprovada para campanhas';
        } else if (avgScore >= 60 && validPercentage >= 85) {
            qualityDescription = 'Boa - Lista confiável';
            qualityAction = 'Remover emails com score < 50 (veja aba "Emails Inválidos")';
        } else if (avgScore >= 50 && validPercentage >= 70) {
            qualityDescription = 'Regular - Necessita limpeza';
            qualityAction = 'Use a aba "Lista Limpa" para obter emails aprovados';
        } else {
            qualityDescription = 'Ruim - Muitos problemas';
            qualityAction = 'Limpeza urgente - veja abas de ação';
        }

        const metrics = [
            { label: 'Total de Emails Processados', value: stats.total },
            { label: 'Emails Válidos', value: `${stats.valid} (${stats.validPercentage}%)`, color: this.colors.success },
            { label: 'Emails Inválidos', value: `${stats.invalid} (${stats.invalidPercentage}%)`, color: this.colors.danger },
            { label: 'Emails Corrigidos', value: `${stats.corrected} (${stats.correctionPercentage}%)`, color: this.colors.correction },
            { label: 'Pontuação Média', value: stats.avgScore },
            { label: 'Taxa de Confiabilidade', value: `${stats.reliabilityRate}%` },
            { label: 'Qualidade da Lista', value: qualityDescription },
            { label: 'Ação Recomendada', value: qualityAction, color: this.colors.info }
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

        // Correções (se houver e forem reais)
        if (stats.corrected > 0 && stats.corrected < stats.total) {
            currentRow += 2;
            sheet.getCell(`B${currentRow}`).value = 'CORREÇÕES APLICADAS';
            sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14, color: { argb: this.colors.correction } };
            currentRow += 2;

            sheet.getCell(`B${currentRow}`).value = 'Emails corrigidos automaticamente';
            sheet.getCell(`C${currentRow}`).value = stats.corrected;
            currentRow++;
        }

        // Distribuição por Tipo de Comprador (simplificada)
        currentRow += 2;
        sheet.getCell(`B${currentRow}`).value = 'DISTRIBUIÇÃO POR TIPO DE COMPRADOR';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14, color: { argb: this.colors.dark } };
        currentRow += 2;

        // Mostrar apenas contagens significativas
        Object.entries(stats.buyerTypes)
            .filter(([type, count]) => count > 0)
            .sort((a, b) => b[1] - a[1])
            .forEach(([type, count]) => {
                sheet.getCell(`B${currentRow}`).value = type;
                sheet.getCell(`C${currentRow}`).value = count;
                currentRow++;
            });

        // Recomendação Geral
        currentRow += 2;
        sheet.mergeCells(`B${currentRow}:E${currentRow}`);
        sheet.getCell(`B${currentRow}`).value = 'RECOMENDAÇÃO GERAL';
        sheet.getCell(`B${currentRow}`).font = { bold: true, size: 14, color: { argb: this.colors.primary } };

        currentRow++;
        sheet.mergeCells(`B${currentRow}:E${currentRow + 2}`);
        sheet.getCell(`B${currentRow}`).value = this.getRecommendation(avgScore, validPercentage, stats.corrected > 0);
        sheet.getCell(`B${currentRow}`).font = { size: 12, italic: true };
        sheet.getCell(`B${currentRow}`).alignment = { wrapText: true, vertical: 'top' };

        this.applyStyleToSheet(sheet);
        return sheet;
    }

    // ================================================
    // ABA 3: RECOMENDAÇÕES - COM LINKS PARA ABAS DE AÇÃO
    // ================================================
    async createRecommendationsSheet(results, stats, analysis) {
        const sheet = this.workbook.addWorksheet('Recomendações', {
            properties: { tabColor: { argb: this.colors.danger } }
        });

        sheet.columns = [
            { width: 5 },
            { width: 5 },
            { width: 35 },
            { width: 60 },
            { width: 15 },
            { width: 20 },
            { width: 5 }
        ];

        let currentRow = 2;

        // Título
        sheet.mergeCells(`B${currentRow}:F${currentRow}`);
        const titleCell = sheet.getCell(`B${currentRow}`);
        titleCell.value = '📋 PLANO DE AÇÃO PARA MELHORIA DA LISTA';
        titleCell.font = { size: 18, bold: true, color: { argb: this.colors.primary } };
        titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(currentRow).height = 40;
        currentRow += 2;

        // Resumo Executivo
        sheet.mergeCells(`B${currentRow}:F${currentRow + 1}`);
        const summaryCell = sheet.getCell(`B${currentRow}`);

        const validPercentage = parseFloat(stats.validPercentage);
        const avgScore = parseFloat(stats.avgScore);

        let summaryText = '';
        let summaryColor = this.colors.success;

        if (validPercentage >= 95 && avgScore >= 70) {
            summaryText = `✅ LISTA EXCELENTE: ${validPercentage}% dos emails são válidos com score médio de ${avgScore}. ` +
                         `Sua lista está pronta para uso!`;
            summaryColor = this.colors.success;
        } else if (validPercentage >= 85) {
            summaryText = `👍 LISTA BOA: ${validPercentage}% dos emails são válidos. ` +
                         `Pequenos ajustes melhorarão os resultados.`;
            summaryColor = this.colors.info;
        } else if (validPercentage >= 70) {
            summaryText = `⚠️ LISTA REGULAR: ${validPercentage}% dos emails são válidos. ` +
                         `Limpeza necessária - veja as abas de ação.`;
            summaryColor = this.colors.warning;
        } else {
            summaryText = `❌ LISTA PROBLEMÁTICA: Apenas ${validPercentage}% válidos. ` +
                         `Limpeza urgente - use a aba "Lista Limpa".`;
            summaryColor = this.colors.danger;
        }

        summaryCell.value = summaryText;
        summaryCell.font = { size: 12, bold: true, color: { argb: summaryColor } };
        summaryCell.alignment = { horizontal: 'left', vertical: 'middle', wrapText: true };
        summaryCell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.grayBg }
        };
        currentRow += 3;

        // Cards de Recomendação
        const recommendations = [];

        // 1. Emails Inválidos
        if (analysis.invalidEmails.length > 0) {
            recommendations.push({
                priority: 'CRÍTICA',
                icon: '🚫',
                action: 'Remover Emails Inválidos',
                description: `${analysis.invalidEmails.length} emails com score < 30 devem ser removidos. ` +
                            `Veja lista completa na aba "Emails Inválidos".`,
                impact: `${analysis.invalidEmails.length} emails`,
                status: 'VER ABA "EMAILS INVÁLIDOS"',
                color: this.colors.danger,
                bgColor: this.colors.criticalBg
            });
        }

        // 2. Emails Suspeitos
        if (analysis.suspiciousEmails.length > 0) {
            recommendations.push({
                priority: 'ALTA',
                icon: '⚠️',
                action: 'Revisar Emails Suspeitos',
                description: `${analysis.suspiciousEmails.length} emails com score 30-59 precisam revisão. ` +
                            `Detalhes na aba "Emails Suspeitos".`,
                impact: `${analysis.suspiciousEmails.length} emails`,
                status: 'VER ABA "EMAILS SUSPEITOS"',
                color: this.colors.warning,
                bgColor: this.colors.highBg
            });
        }

        // 3. Lista Limpa
        recommendations.push({
            priority: 'INFO',
            icon: '✅',
            action: 'Use a Lista Limpa',
            description: `Preparamos uma lista com apenas emails aprovados (score >= 60). ` +
                        `Acesse a aba "Lista Limpa" para baixar.`,
            impact: `${analysis.highQualityEmails.length} emails aprovados`,
            status: 'VER ABA "LISTA LIMPA"',
            color: this.colors.success,
            bgColor: this.colors.successBg
        });

        // Renderizar cards
        recommendations.forEach((rec) => {
            // Cabeçalho
            sheet.mergeCells(`B${currentRow}:F${currentRow}`);
            const headerCell = sheet.getCell(`B${currentRow}`);
            headerCell.value = `${rec.icon} ${rec.action}`;
            headerCell.font = { size: 14, bold: true, color: { argb: 'FFFFFFFF' } };
            headerCell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: rec.color }
            };
            headerCell.alignment = { horizontal: 'left', vertical: 'middle' };
            sheet.getRow(currentRow).height = 30;
            currentRow++;

            // Descrição
            sheet.mergeCells(`B${currentRow}:F${currentRow + 2}`);
            const bodyCell = sheet.getCell(`B${currentRow}`);
            bodyCell.value = rec.description;
            bodyCell.font = { size: 11 };
            bodyCell.alignment = { horizontal: 'left', vertical: 'top', wrapText: true };
            bodyCell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: rec.bgColor }
            };
            currentRow += 3;

            // Métricas
            sheet.getCell(`B${currentRow}`).value = 'Impacto:';
            sheet.getCell(`B${currentRow}`).font = { bold: true, size: 10 };
            sheet.getCell(`C${currentRow}`).value = rec.impact;

            sheet.getCell(`D${currentRow}`).value = 'Ação:';
            sheet.getCell(`D${currentRow}`).font = { bold: true, size: 10 };
            sheet.getCell(`E${currentRow}`).value = rec.status;
            sheet.getCell(`E${currentRow}`).font = { size: 10, bold: true, color: { argb: rec.color } };

            currentRow += 2;
        });

        return sheet;
    }

    // ================================================
    // NOVA ABA: EMAILS INVÁLIDOS (PARA REMOVER)
    // ================================================
    async createInvalidEmailsSheet(results, analysis) {
        const sheet = this.workbook.addWorksheet('Emails Inválidos', {
            properties: { tabColor: { argb: this.colors.danger } }
        });

        // Título
        sheet.getCell('A1').value = '🚫 EMAILS PARA REMOVER IMEDIATAMENTE';
        sheet.getCell('A1').font = { size: 16, bold: true, color: { argb: this.colors.danger } };
        sheet.getRow(1).height = 30;

        sheet.getCell('A2').value = 'Estes emails têm score < 30 e devem ser removidos da sua lista';
        sheet.getCell('A2').font = { size: 12, italic: true };

        // Configurar colunas
        sheet.columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Score', key: 'score', width: 10 },
            { header: 'Motivo', key: 'reason', width: 50 },
            { header: 'Ação', key: 'action', width: 25 },
            { header: 'Linha Original', key: 'line', width: 12 }
        ];

        // Estilizar cabeçalho
        sheet.getRow(4).font = { bold: true, color: { argb: 'FFFFFFFF' } };
        sheet.getRow(4).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.danger }
        };
        sheet.getRow(4).alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(4).height = 25;

        // Adicionar dados
        let currentRow = 5;
        analysis.invalidEmails.forEach((item, index) => {
            const row = sheet.getRow(currentRow);
            row.values = {
                index: index + 1,
                email: item.email,
                score: item.score,
                reason: item.reason,
                action: item.action,
                line: item.originalLine
            };

            // Colorir linha
            row.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFFFE6E6' }
            };

            currentRow++;
        });

        // Resumo no final
        currentRow += 1;
        sheet.getCell(`A${currentRow}`).value = 'RESUMO:';
        sheet.getCell(`A${currentRow}`).font = { bold: true, size: 12 };
        currentRow++;
        sheet.getCell(`A${currentRow}`).value = `Total de emails para remover: ${analysis.invalidEmails.length}`;
        sheet.getCell(`A${currentRow}`).font = { bold: true, color: { argb: this.colors.danger } };

        return sheet;
    }

    // ================================================
    // NOVA ABA: EMAILS SUSPEITOS (PARA REVISAR)
    // ================================================
    async createSuspiciousEmailsSheet(results, analysis) {
        const sheet = this.workbook.addWorksheet('Emails Suspeitos', {
            properties: { tabColor: { argb: this.colors.warning } }
        });

        // Título
        sheet.getCell('A1').value = '⚠️ EMAILS QUE PRECISAM DE REVISÃO';
        sheet.getCell('A1').font = { size: 16, bold: true, color: { argb: this.colors.warning } };
        sheet.getRow(1).height = 30;

        sheet.getCell('A2').value = 'Emails com score 30-59 que precisam de análise manual antes do uso';
        sheet.getCell('A2').font = { size: 12, italic: true };

        // Configurar colunas
        sheet.columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Score', key: 'score', width: 10 },
            { header: 'Tipo', key: 'buyerType', width: 20 },
            { header: 'Risco', key: 'riskLevel', width: 15 },
            { header: 'Problema', key: 'reason', width: 50 },
            { header: 'Ação Sugerida', key: 'action', width: 30 }
        ];

        // Estilizar cabeçalho
        sheet.getRow(4).font = { bold: true, color: { argb: 'FFFFFFFF' } };
        sheet.getRow(4).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.warning }
        };
        sheet.getRow(4).alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(4).height = 25;

        // Adicionar dados
        let currentRow = 5;
        analysis.suspiciousEmails.forEach((item, index) => {
            const row = sheet.getRow(currentRow);
            row.values = {
                index: index + 1,
                email: item.email,
                score: item.score,
                buyerType: item.buyerType,
                riskLevel: item.riskLevel,
                reason: item.reason,
                action: item.action
            };

            // Colorir linha
            row.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFFFF3E6' }
            };

            currentRow++;
        });

        // Sugestões no final
        currentRow += 2;
        sheet.getCell(`A${currentRow}`).value = 'SUGESTÕES DE AÇÃO:';
        sheet.getCell(`A${currentRow}`).font = { bold: true, size: 12 };
        currentRow++;

        const suggestions = [
            '1. Envie campanha de reengajamento para estes emails',
            '2. Segmente em lista separada com conteúdo específico',
            '3. Monitore métricas de abertura e cliques',
            '4. Remova emails que não interagirem após 3 tentativas'
        ];

        suggestions.forEach(suggestion => {
            sheet.getCell(`A${currentRow}`).value = suggestion;
            currentRow++;
        });

        return sheet;
    }

    // ================================================
    // NOVA ABA: LISTA LIMPA (EMAILS APROVADOS)
    // ================================================
    async createCleanListSheet(results, analysis) {
        const sheet = this.workbook.addWorksheet('Lista Limpa', {
            properties: { tabColor: { argb: this.colors.success } }
        });

        // Título
        sheet.getCell('A1').value = '✅ LISTA LIMPA - EMAILS APROVADOS PARA USO';
        sheet.getCell('A1').font = { size: 16, bold: true, color: { argb: this.colors.success } };
        sheet.getRow(1).height = 30;

        sheet.getCell('A2').value = 'Apenas emails com score >= 60 - prontos para suas campanhas';
        sheet.getCell('A2').font = { size: 12, italic: true };

        // Filtrar emails aprovados
        const approvedEmails = results.filter(r => r.score >= 60);

        // Configurar colunas
        sheet.columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Score', key: 'score', width: 10 },
            { header: 'Qualidade', key: 'quality', width: 20 },
            { header: 'Status', key: 'status', width: 25 }
        ];

        // Estilizar cabeçalho
        sheet.getRow(4).font = { bold: true, color: { argb: 'FFFFFFFF' } };
        sheet.getRow(4).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.success }
        };
        sheet.getRow(4).alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(4).height = 25;

        // Adicionar dados
        let currentRow = 5;
        approvedEmails
            .sort((a, b) => b.score - a.score) // Ordenar por score
            .forEach((result, index) => {
                const row = sheet.getRow(currentRow);

                let quality = 'Boa';
                if (result.score >= 90) quality = 'Excelente';
                else if (result.score >= 80) quality = 'Muito Boa';
                else if (result.score >= 70) quality = 'Boa';
                else quality = 'Aceitável';

                row.values = {
                    index: index + 1,
                    email: result.correctedEmail || result.email,
                    score: result.score,
                    quality: quality,
                    status: 'APROVADO PARA CAMPANHAS'
                };

                // Colorir baseado na qualidade
                if (result.score >= 80) {
                    row.fill = {
                        type: 'pattern',
                        pattern: 'solid',
                        fgColor: { argb: 'FFE8F5E9' }
                    };
                }

                currentRow++;
            });

        // Resumo
        currentRow += 2;
        sheet.getCell(`A${currentRow}`).value = 'RESUMO DA LISTA LIMPA:';
        sheet.getCell(`A${currentRow}`).font = { bold: true, size: 12 };
        currentRow++;

        const stats = {
            total: approvedEmails.length,
            excellent: approvedEmails.filter(r => r.score >= 90).length,
            veryGood: approvedEmails.filter(r => r.score >= 80 && r.score < 90).length,
            good: approvedEmails.filter(r => r.score >= 70 && r.score < 80).length,
            acceptable: approvedEmails.filter(r => r.score >= 60 && r.score < 70).length
        };

        sheet.getCell(`A${currentRow}`).value = `Total de emails aprovados: ${stats.total}`;
        currentRow++;
        sheet.getCell(`A${currentRow}`).value = `Excelentes (90+): ${stats.excellent}`;
        currentRow++;
        sheet.getCell(`A${currentRow}`).value = `Muito Bons (80-89): ${stats.veryGood}`;
        currentRow++;
        sheet.getCell(`A${currentRow}`).value = `Bons (70-79): ${stats.good}`;
        currentRow++;
        sheet.getCell(`A${currentRow}`).value = `Aceitáveis (60-69): ${stats.acceptable}`;

        return sheet;
    }

    // ================================================
    // OUTROS MÉTODOS (continuam iguais)
    // ================================================

    async createDetailedDataSheet(results) {
        const sheet = this.workbook.addWorksheet('Dados Detalhados', {
            properties: { tabColor: { argb: this.colors.info } }
        });

        sheet.columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Válido', key: 'valid', width: 10 },
            { header: 'Pontuação', key: 'score', width: 12 },
            { header: 'Foi Corrigido?', key: 'corrected', width: 15 },
            { header: 'Email Original', key: 'originalEmail', width: 35 },
            { header: 'Tipo de Comprador', key: 'buyerType', width: 22 },
            { header: 'Nível de Risco', key: 'riskLevel', width: 18 },
            { header: 'Confiança', key: 'confidence', width: 15 },
            { header: 'Linha CSV', key: 'originalLine', width: 10 }
        ];

        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.primary }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 25;

        results.forEach((result, index) => {
            const currentEmail = (result.correctedEmail || result.email || '').toLowerCase().trim();
            const originalEmail = (result.originalEmail || result.normalizedEmail ||
                                 result.originalBeforeParse || '').toLowerCase().trim();

            const wasActuallyCorrect = originalEmail && currentEmail && currentEmail !== originalEmail;

            const row = sheet.addRow({
                index: index + 1,
                email: result.correctedEmail || result.email || '-----',
                valid: this.formatValue(result.valid, 'boolean'),
                score: this.formatValue(result.score, 'integer'),
                corrected: wasActuallyCorrect ? 'Sim' : 'Não',
                originalEmail: wasActuallyCorrect ?
                    (result.originalEmail || result.normalizedEmail || result.originalBeforeParse || '-----') :
                    '-----',
                buyerType: this.translate(
                    result.scoring?.buyerType || result.ecommerce?.buyerType || 'unknown',
                    'buyerTypes'
                ),
                riskLevel: this.translate(
                    result.scoring?.riskLevel || result.ecommerce?.riskLevel || 'unknown',
                    'riskLevels'
                ),
                confidence: this.translate(
                    result.scoring?.confidence || result.ecommerce?.confidence || 'unknown',
                    'confidence'
                ),
                originalLine: result.originalLine || index + 2
            });

            if (!result.valid && result.score < 50) {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFFFE6E6' }
                };
            } else if (wasActuallyCorrect) {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFF0E6FF' }
                };
            }

            const scoreCell = row.getCell('score');
            if (result.score >= 80) {
                scoreCell.font = { color: { argb: this.colors.success }, bold: true };
            } else if (result.score >= 60) {
                scoreCell.font = { color: { argb: this.colors.warning } };
            } else if (result.score >= 50) {
                scoreCell.font = { color: { argb: this.colors.info } };
            } else {
                scoreCell.font = { color: { argb: this.colors.danger } };
            }
        });

        sheet.autoFilter = {
            from: 'A1',
            to: `J${results.length + 1}`
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

        sheet.getCell('A1').value = 'ANÁLISE ESTATÍSTICA DETALHADA';
        sheet.getCell('A1').font = { size: 16, bold: true, color: { argb: this.colors.primary } };

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

        return sheet;
    }

    async createDomainAnalysisSheet(results) {
        const sheet = this.workbook.addWorksheet('Análise de Domínios', {
            properties: { tabColor: { argb: this.colors.warning } }
        });

        const domainStats = {};
        results.forEach(r => {
            const email = r.correctedEmail || r.email || '';
            const domain = email.includes('@') ? email.split('@')[1] : 'invalid';

            if (!domainStats[domain]) {
                domainStats[domain] = {
                    count: 0,
                    valid: 0,
                    invalid: 0,
                    corrected: 0,
                    avgScore: 0,
                    scores: []
                };
            }

            domainStats[domain].count++;
            domainStats[domain].scores.push(r.score || 0);

            if (r.valid || r.score >= 50) {
                domainStats[domain].valid++;
            } else {
                domainStats[domain].invalid++;
            }
        });

        Object.keys(domainStats).forEach(domain => {
            const scores = domainStats[domain].scores;
            domainStats[domain].avgScore = scores.length > 0
                ? (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(1)
                : '0';
        });

        sheet.columns = [
            { header: 'Domínio', key: 'domain', width: 30 },
            { header: 'Total', key: 'count', width: 12 },
            { header: 'Válidos', key: 'valid', width: 12 },
            { header: 'Inválidos', key: 'invalid', width: 12 },
            { header: 'Score Médio', key: 'avgScore', width: 15 },
            { header: 'Taxa de Validade', key: 'validRate', width: 18 }
        ];

        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.warning }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 25;

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

        return sheet;
    }

    async createCorrectionsSheet(results) {
        const sheet = this.workbook.addWorksheet('Correções Aplicadas', {
            properties: { tabColor: { argb: this.colors.correction } }
        });

        const correctedEmails = results.filter(r => {
            const currentEmail = (r.correctedEmail || r.email || '').toLowerCase();
            const originalEmail = (r.originalEmail || r.normalizedEmail || r.originalBeforeParse || '').toLowerCase();
            return originalEmail && currentEmail && currentEmail !== originalEmail;
        });

        if (correctedEmails.length === 0) {
            sheet.getCell('A1').value = 'Nenhuma correção foi aplicada';
            sheet.getCell('A1').font = { size: 14, italic: true };
            return sheet;
        }

        sheet.columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email Original', key: 'original', width: 35 },
            { header: 'Email Corrigido', key: 'corrected', width: 35 },
            { header: 'Tipo de Correção', key: 'correctionType', width: 20 },
            { header: 'Válido Após Correção?', key: 'validAfter', width: 20 },
            { header: 'Score Final', key: 'score', width: 12 }
        ];

        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.correction }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 25;

        correctedEmails.forEach((result, index) => {
            const row = sheet.addRow({
                index: index + 1,
                original: result.originalEmail || result.normalizedEmail || result.originalBeforeParse || '-----',
                corrected: result.correctedEmail || result.email || '-----',
                correctionType: 'Correção Automática',
                validAfter: (result.valid || result.score >= 50) ? 'Sim' : 'Não',
                score: this.formatValue(result.score, 'integer')
            });

            if (result.valid || result.score >= 50) {
                row.getCell('validAfter').font = { color: { argb: this.colors.success }, bold: true };
            } else {
                row.getCell('validAfter').font = { color: { argb: this.colors.danger }, bold: true };
            }
        });

        return sheet;
    }

    async createEcommerceSheet(results) {
        const sheet = this.workbook.addWorksheet('Análise E-commerce', {
            properties: { tabColor: { argb: this.colors.success } }
        });

        sheet.columns = [
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Score E-commerce', key: 'ecomScore', width: 18 },
            { header: 'Tipo de Comprador', key: 'buyerType', width: 25 },
            { header: 'Nível de Risco', key: 'riskLevel', width: 18 },
            { header: 'Confiança', key: 'confidence', width: 15 }
        ];

        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.success }
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 25;

        const scoringData = results.filter(r => r.scoring || r.ecommerce);

        scoringData.forEach(result => {
            const scoring = result.scoring || result.ecommerce || {};

            const row = sheet.addRow({
                email: result.correctedEmail || result.email || '-----',
                ecomScore: this.formatValue(scoring.finalScore || scoring.score || result.score, 'integer'),
                buyerType: this.translate(scoring.buyerType, 'buyerTypes'),
                riskLevel: this.translate(scoring.riskLevel, 'riskLevels'),
                confidence: this.translate(scoring.confidence, 'confidence')
            });

            const riskLevel = scoring.riskLevel;
            if (riskLevel === 'VERY_HIGH' || riskLevel === 'HIGH' || riskLevel === 'CRITICAL') {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFFFE6E6' }
                };
            }
        });

        return sheet;
    }

    // Métodos auxiliares
    translate(value, category) {
        if (!value) return 'Não Classificado';

        if (typeof value === 'string' && value.startsWith('CORRECTED_')) {
            value = value.replace('CORRECTED_', '');
        }

        return this.translations[category]?.[value] || value;
    }

    formatValue(value, type = 'text') {
        if (value === null || value === undefined || value === '') {
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

    formatCorrectionType(type) {
        const types = {
            'known_typo': 'Erro de Digitação',
            'similarity': 'Similaridade',
            'domain_typo': 'Erro no Domínio'
        };
        return types[type] || 'Correção Automática';
    }

    getRecommendation(avgScore, validPercentage, hasCorrections) {
        let recommendation = '';

        if (hasCorrections) {
            recommendation = 'Correções automáticas foram aplicadas. ';
        }

        if (avgScore >= 70 && validPercentage >= 95) {
            recommendation += `Excelente! ${validPercentage}% válidos. Use a aba "Lista Limpa" para suas campanhas.`;
        } else if (avgScore >= 60 && validPercentage >= 85) {
            recommendation += `Boa lista com ${validPercentage}% válidos. Revise a aba "Emails Suspeitos" antes de usar.`;
        } else if (avgScore >= 50 && validPercentage >= 70) {
            recommendation += `Lista regular. Use a aba "Lista Limpa" para emails aprovados. ` +
                           `Revise as abas "Emails Inválidos" e "Emails Suspeitos".`;
        } else {
            recommendation += `Lista problemática. Urgente: Use apenas emails da aba "Lista Limpa". ` +
                           `Remova todos da aba "Emails Inválidos".`;
        }

        return recommendation;
    }

    applyStyleToSheet(sheet) {
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
}

module.exports = ExcelReportGenerator;
