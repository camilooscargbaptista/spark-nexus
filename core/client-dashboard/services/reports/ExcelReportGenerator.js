// ================================================
// Excel Report Generator v2.0 - DESIGN PREMIUM
// Sistema completo com todas funcionalidades e visual moderno
// ================================================

const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');
const moment = require('moment');

class ExcelReportGenerator {
    constructor() {
        this.workbook = null;

        // ================================================
        // PALETA DE CORES MODERNA E PROFISSIONAL
        // ================================================
        this.colors = {
            // Cores principais - Gradiente moderno
            primary: 'FF6366F1',      // Indigo vibrante
            primaryDark: 'FF4F46E5',   // Indigo escuro
            primaryLight: 'FF818CF8',  // Indigo claro

            // Cores de status
            success: 'FF10B981',       // Verde esmeralda
            successLight: 'FF34D399',  // Verde claro
            successBg: 'FFF0FDF4',     // Verde background

            danger: 'FFEF4444',        // Vermelho moderno
            dangerLight: 'FFF87171',   // Vermelho claro
            dangerBg: 'FFFEF2F2',      // Vermelho background

            warning: 'FFF59E0B',       // Âmbar
            warningLight: 'FFFBBF24',  // Âmbar claro
            warningBg: 'FFFFFBEB',     // Âmbar background

            info: 'FF3B82F6',          // Azul
            infoLight: 'FF60A5FA',     // Azul claro
            infoBg: 'FFEFF6FF',        // Azul background

            // Cores especiais
            correction: 'FF8B5CF6',    // Roxo para correções
            correctionBg: 'FFF5F3FF',  // Roxo background

            catchAll: 'FFEC4899',      // Rosa para catch-all
            catchAllBg: 'FFFDF2F8',    // Rosa background

            spamtrap: 'FFDC2626',      // Vermelho escuro para spamtrap
            spamtrapBg: 'FFFEF2F2',    // Vermelho background

            roleBased: 'FF7C3AED',     // Violeta para role-based
            roleBasedBg: 'FFF9F5FF',   // Violeta background

            // Neutros
            dark: 'FF1F2937',          // Cinza escuro
            gray: 'FF6B7280',          // Cinza médio
            light: 'FFF3F4F6',         // Cinza claro
            white: 'FFFFFFFF',         // Branco
            black: 'FF000000',         // Preto

            // Backgrounds sutis
            grayBg: 'FFF9FAFB',        // Cinza muito claro
            borderColor: 'FFE5E7EB'   // Cor de borda
        };

        // ================================================
        // TRADUÇÕES EXPANDIDAS
        // ================================================
        this.translations = {
            buyerTypes: {
                'TRUSTED_BUYER': '⭐ Comprador Confiável',
                'REGULAR_BUYER': '✓ Comprador Regular',
                'NEW_BUYER': '🆕 Novo Comprador',
                'SUSPICIOUS_BUYER': '⚠️ Comprador Suspeito',
                'HIGH_RISK_BUYER': '🚫 Alto Risco',
                'CORRECTED_VALID_BUYER': '✏️ Corrigido - Válido',
                'CORRECTED_REGULAR_BUYER': '✏️ Corrigido - Regular',
                'CORRECTED_SUSPICIOUS_BUYER': '✏️ Corrigido - Revisar',
                'CORRECTED_HIGH_RISK_BUYER': '✏️ Corrigido - Alto Risco',
                'BLOCKED': '🚫 Bloqueado',
                'INVALID': '❌ Inválido',
                'unknown': '❓ Não Classificado'
            },
            riskLevels: {
                'VERY_LOW': '✅ Muito Baixo',
                'LOW': '✅ Baixo',
                'MEDIUM': '⚠️ Médio',
                'HIGH': '⚠️ Alto',
                'VERY_HIGH': '🚫 Muito Alto',
                'CRITICAL': '🔴 Crítico',
                'BLOCKED': '⛔ Bloqueado',
                'unknown': '❓ Não Avaliado'
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
            },
            roleCategories: {
                'administrative': '👤 Administrativo',
                'support': '💬 Suporte',
                'sales': '💼 Vendas',
                'marketing': '📢 Marketing',
                'info': 'ℹ️ Informações',
                'noreply': '🚫 Não Responder',
                'technical': '⚙️ Técnico',
                'hr': '👥 RH',
                'finance': '💰 Financeiro',
                'legal': '⚖️ Jurídico',
                'social': '📱 Redes Sociais',
                'personal': '👤 Pessoal'
            },
            emailQuality: {
                'EXCELLENT': '⭐⭐⭐⭐⭐ Excelente',
                'VERY_GOOD': '⭐⭐⭐⭐ Muito Boa',
                'GOOD': '⭐⭐⭐ Boa',
                'FAIR': '⭐⭐ Regular',
                'POOR': '⭐ Baixa',
                'VERY_POOR': '❌ Muito Baixa',
                'INVALID': '🚫 Inválida'
            }
        };

        // ================================================
        // ÍCONES E EMOJIS PARA VISUAL MODERNO
        // ================================================
        this.icons = {
            success: '✅',
            error: '❌',
            warning: '⚠️',
            info: 'ℹ️',
            email: '📧',
            chart: '📊',
            list: '📋',
            shield: '🛡️',
            rocket: '🚀',
            star: '⭐',
            fire: '🔥',
            alert: '🚨',
            magnifier: '🔍',
            pencil: '✏️',
            trash: '🗑️',
            clock: '⏰',
            trophy: '🏆',
            target: '🎯',
            check: '✓',
            cross: '✗',
            dot: '•'
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
        this.workbook.creator = 'Spark Nexus Premium';
        this.workbook.lastModifiedBy = 'Advanced Validation System';
        this.workbook.created = new Date();
        this.workbook.modified = new Date();

        // Configurar propriedades do workbook
        this.workbook.properties = {
            title: 'Email Validation Report',
            subject: 'Comprehensive Email Analysis',
            category: 'Report',
            keywords: 'email, validation, analysis, quality'
        };

        const stats = this.calculateStatistics(validationResults);
        const analysis = this.analyzeProblems(validationResults);
        const technicalAnalysis = this.analyzeTechnicalAspects(validationResults);

        // ================================================
        // CRIAR TODAS AS ABAS NA ORDEM OTIMIZADA
        // ================================================

        // Abas principais
        await this.createDashboardSheet(stats, analysis, technicalAnalysis);
        await this.createExecutiveSummarySheet(stats, analysis);
        await this.createActionPlanSheet(validationResults, stats, analysis, technicalAnalysis);

        // Abas de dados
        await this.createDetailedDataSheet(validationResults);
        await this.createCleanListSheet(validationResults, analysis);

        // Abas de problemas
        await this.createCriticalAlertsSheet(validationResults, technicalAnalysis);
        await this.createInvalidEmailsSheet(validationResults, analysis);
        await this.createSuspiciousEmailsSheet(validationResults, analysis);

        // Abas técnicas
        await this.createTechnicalAnalysisSheet(validationResults, technicalAnalysis);
        await this.createRoleBasedEmailsSheet(validationResults, technicalAnalysis);
        await this.createDomainAnalysisSheet(validationResults, technicalAnalysis);
        await this.createCorrectionsSheet(validationResults);

        // Abas de análise
        await this.createStatisticsSheet(stats, validationResults);
        await this.createEcommerceSheet(validationResults);
        await this.createQualityMetricsSheet(validationResults, stats);

        await this.workbook.xlsx.writeFile(filepath);
        console.log(`✅ Relatório Excel Premium gerado: ${filepath}`);

        return {
            success: true,
            filepath: filepath,
            filename: filename,
            stats: stats,
            summary: this.generateTextSummary(stats, analysis, technicalAnalysis)
        };
    }

    // ================================================
    // ANÁLISE TÉCNICA EXPANDIDA
    // ================================================
    analyzeTechnicalAspects(results) {
        const analysis = {
            // RFC Analysis
            rfcInvalid: [],
            rfcWarnings: [],

            // Catch-All Analysis
            catchAllDomains: [],
            rejectAllDomains: [],

            // Role-Based Analysis
            roleBasedEmails: {
                administrative: [],
                support: [],
                sales: [],
                marketing: [],
                noreply: [],
                technical: [],
                hr: [],
                finance: [],
                legal: [],
                social: [],
                info: [],
                other: []
            },

            // Spamtrap Analysis
            confirmedSpamtraps: [],
            likelySpamtraps: [],
            recycledEmails: [],

            // Bounce Analysis
            hardBounces: [],
            softBounces: [],

            // Domain Statistics
            domainStats: {},
            problematicDomains: [],

            // Quality Distribution
            qualityDistribution: {
                excellent: [],
                veryGood: [],
                good: [],
                fair: [],
                poor: [],
                veryPoor: [],
                invalid: []
            }
        };

        // Processar cada resultado
        results.forEach((r, index) => {
            const email = r.correctedEmail || r.email || '';
            const domain = email.includes('@') ? email.split('@')[1] : 'invalid';

            // RFC Analysis
            if (r.checks?.rfc) {
                if (!r.checks.rfc.valid) {
                    analysis.rfcInvalid.push({
                        email: email,
                        errors: r.checks.rfc.errors || [],
                        score: r.checks.rfc.score || 0,
                        line: r.originalLine || index + 2
                    });
                }
                if (r.checks.rfc.warnings?.length > 0) {
                    analysis.rfcWarnings.push({
                        email: email,
                        warnings: r.checks.rfc.warnings,
                        line: r.originalLine || index + 2
                    });
                }
            }

            // Catch-All Analysis
            if (r.checks?.catchAll) {
                if (r.checks.catchAll.isCatchAll) {
                    if (!analysis.catchAllDomains.find(d => d.domain === domain)) {
                        analysis.catchAllDomains.push({
                            domain: domain,
                            confidence: r.checks.catchAll.confidence,
                            emails: []
                        });
                    }
                    const catchAllDomain = analysis.catchAllDomains.find(d => d.domain === domain);
                    if (catchAllDomain) {
                        catchAllDomain.emails.push(email);
                    }
                }
                if (r.checks.catchAll.isRejectAll) {
                    analysis.rejectAllDomains.push(domain);
                }
            }

            // Role-Based Analysis
            if (r.checks?.roleBased?.isRoleBased) {
                const category = r.checks.roleBased.category || 'other';
                const roleEmail = {
                    email: email,
                    pattern: r.checks.roleBased.pattern,
                    risk: r.checks.roleBased.risk,
                    recommendation: r.checks.roleBased.recommendation,
                    line: r.originalLine || index + 2
                };

                if (analysis.roleBasedEmails[category]) {
                    analysis.roleBasedEmails[category].push(roleEmail);
                } else {
                    analysis.roleBasedEmails.other.push(roleEmail);
                }
            }

            // Spamtrap Analysis
            if (r.checks?.spamtrap) {
                if (r.checks.spamtrap.isSpamtrap) {
                    analysis.confirmedSpamtraps.push({
                        email: email,
                        confidence: r.checks.spamtrap.confidence,
                        indicators: r.checks.spamtrap.indicators || [],
                        risk: r.checks.spamtrap.risk,
                        line: r.originalLine || index + 2
                    });
                } else if (r.checks.spamtrap.isLikelySpamtrap) {
                    analysis.likelySpamtraps.push({
                        email: email,
                        confidence: r.checks.spamtrap.confidence,
                        indicators: r.checks.spamtrap.indicators || [],
                        line: r.originalLine || index + 2
                    });
                }
                if (r.checks.spamtrap.isRecycled) {
                    analysis.recycledEmails.push({
                        email: email,
                        line: r.originalLine || index + 2
                    });
                }
            }

            // Bounce Analysis
            if (r.checks?.bounce?.hasBounced) {
                const bounceData = {
                    email: email,
                    type: r.checks.bounce.bounceType,
                    category: r.checks.bounce.bounceCategory,
                    line: r.originalLine || index + 2
                };

                if (r.checks.bounce.isPermanent) {
                    analysis.hardBounces.push(bounceData);
                } else {
                    analysis.softBounces.push(bounceData);
                }
            }

            // Domain Statistics
            if (!analysis.domainStats[domain]) {
                analysis.domainStats[domain] = {
                    total: 0,
                    valid: 0,
                    invalid: 0,
                    corrected: 0,
                    scores: [],
                    issues: [],
                    isCatchAll: false,
                    hasSpamtraps: false,
                    roleBasedCount: 0
                };
            }

            analysis.domainStats[domain].total++;
            analysis.domainStats[domain].scores.push(r.score || 0);

            if (r.valid || r.score >= 45) {
                analysis.domainStats[domain].valid++;
            } else {
                analysis.domainStats[domain].invalid++;
            }

            if (this.wasEmailCorrected(r)) {
                analysis.domainStats[domain].corrected++;
            }

            if (r.checks?.catchAll?.isCatchAll) {
                analysis.domainStats[domain].isCatchAll = true;
            }

            if (r.checks?.spamtrap?.isSpamtrap || r.checks?.spamtrap?.isLikelySpamtrap) {
                analysis.domainStats[domain].hasSpamtraps = true;
            }

            if (r.checks?.roleBased?.isRoleBased) {
                analysis.domainStats[domain].roleBasedCount++;
            }

            // Quality Distribution
            const quality = r.insights?.emailQuality || this.getEmailQuality(r.score);
            switch(quality) {
                case 'EXCELLENT':
                    analysis.qualityDistribution.excellent.push(email);
                    break;
                case 'VERY_GOOD':
                    analysis.qualityDistribution.veryGood.push(email);
                    break;
                case 'GOOD':
                    analysis.qualityDistribution.good.push(email);
                    break;
                case 'FAIR':
                    analysis.qualityDistribution.fair.push(email);
                    break;
                case 'POOR':
                    analysis.qualityDistribution.poor.push(email);
                    break;
                case 'VERY_POOR':
                    analysis.qualityDistribution.veryPoor.push(email);
                    break;
                default:
                    analysis.qualityDistribution.invalid.push(email);
            }
        });

        // Identificar domínios problemáticos
        Object.entries(analysis.domainStats).forEach(([domain, stats]) => {
            const avgScore = stats.scores.reduce((a, b) => a + b, 0) / stats.scores.length;
            const problemRate = stats.invalid / stats.total;

            if (problemRate > 0.3 || stats.hasSpamtraps || avgScore < 40) {
                analysis.problematicDomains.push({
                    domain: domain,
                    total: stats.total,
                    problemRate: (problemRate * 100).toFixed(1),
                    avgScore: avgScore.toFixed(1),
                    issues: [
                        stats.hasSpamtraps ? 'Spamtraps detectados' : null,
                        stats.isCatchAll ? 'Domínio catch-all' : null,
                        problemRate > 0.3 ? 'Alta taxa de inválidos' : null,
                        avgScore < 40 ? 'Score médio baixo' : null
                    ].filter(Boolean)
                });
            }
        });

        return analysis;
    }

    // ================================================
    // ABA 1: DASHBOARD (NOVA)
    // ================================================
    async createDashboardSheet(stats, analysis, technicalAnalysis) {
        const sheet = this.workbook.addWorksheet('📊 Dashboard', {
            properties: { tabColor: { argb: this.colors.primary } },
            views: [{ showGridLines: false }]
        });

        // Configurar larguras das colunas para layout
        sheet.columns = [
            { width: 2 },   // A - Margem
            { width: 25 },  // B
            { width: 20 },  // C
            { width: 20 },  // D
            { width: 20 },  // E
            { width: 20 },  // F
            { width: 20 },  // G
            { width: 2 }    // H - Margem
        ];

        let currentRow = 2;

        // ================================================
        // HEADER COM GRADIENTE
        // ================================================
        sheet.mergeCells(`B${currentRow}:G${currentRow + 2}`);
        const headerCell = sheet.getCell(`B${currentRow}`);
        headerCell.value = '📊 DASHBOARD DE VALIDAÇÃO DE EMAILS';
        headerCell.font = {
            name: 'Segoe UI',
            size: 24,
            bold: true,
            color: { argb: this.colors.white }
        };
        headerCell.fill = {
            type: 'gradient',
            gradient: 'angle',
            degree: 135,
            stops: [
                { position: 0, color: { argb: this.colors.primary } },
                { position: 1, color: { argb: this.colors.primaryDark } }
            ]
        };
        headerCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(currentRow).height = 50;
        currentRow += 3;

        // Data e hora com estilo
        sheet.mergeCells(`B${currentRow}:G${currentRow}`);
        const dateCell = sheet.getCell(`B${currentRow}`);
        dateCell.value = `Relatório gerado em ${moment().format('DD/MM/YYYY às HH:mm:ss')}`;
        dateCell.font = { name: 'Segoe UI', size: 11, italic: true, color: { argb: this.colors.gray } };
        dateCell.alignment = { horizontal: 'center' };
        currentRow += 2;

        // ================================================
        // KPIs PRINCIPAIS - CARDS MODERNOS
        // ================================================
        const kpis = [
            {
                title: 'TOTAL PROCESSADO',
                value: stats.total.toLocaleString('pt-BR'),
                icon: '📧',
                color: this.colors.primary,
                bgColor: this.colors.infoBg
            },
            {
                title: 'TAXA DE VALIDADE',
                value: `${stats.validPercentage}%`,
                icon: '✅',
                color: stats.validPercentage >= 95 ? this.colors.success :
                       stats.validPercentage >= 85 ? this.colors.warning : this.colors.danger,
                bgColor: stats.validPercentage >= 95 ? this.colors.successBg :
                        stats.validPercentage >= 85 ? this.colors.warningBg : this.colors.dangerBg
            },
            {
                title: 'SCORE MÉDIO',
                value: stats.avgScore,
                icon: '⭐',
                color: stats.avgScore >= 70 ? this.colors.success :
                       stats.avgScore >= 50 ? this.colors.warning : this.colors.danger,
                bgColor: this.colors.grayBg
            },
            {
                title: 'EMAILS CORRIGIDOS',
                value: stats.corrected.toLocaleString('pt-BR'),
                icon: '✏️',
                color: this.colors.correction,
                bgColor: this.colors.correctionBg
            }
        ];

        // Renderizar KPIs em grid 2x2
        for (let i = 0; i < kpis.length; i++) {
            const kpi = kpis[i];
            const col = i % 2 === 0 ? 'B' : 'E';
            const endCol = i % 2 === 0 ? 'D' : 'G';
            const row = currentRow + Math.floor(i / 2) * 4;

            // Card container
            sheet.mergeCells(`${col}${row}:${endCol}${row + 2}`);
            const kpiCell = sheet.getCell(`${col}${row}`);

            kpiCell.value = {
                richText: [
                    { text: `${kpi.icon} ${kpi.title}\n`, font: { size: 10, color: { argb: this.colors.gray } } },
                    { text: kpi.value, font: { size: 20, bold: true, color: { argb: kpi.color } } }
                ]
            };

            kpiCell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: kpi.bgColor }
            };

            kpiCell.alignment = { horizontal: 'center', vertical: 'middle', wrapText: true };
            kpiCell.border = this.createModernBorder(this.colors.borderColor);

            sheet.getRow(row).height = 35;
        }

        currentRow += 9;

        // ================================================
        // ALERTAS CRÍTICOS
        // ================================================
        if (technicalAnalysis.confirmedSpamtraps.length > 0 ||
            technicalAnalysis.hardBounces.length > 0 ||
            analysis.invalidEmails.length > 50) {

            sheet.mergeCells(`B${currentRow}:G${currentRow}`);
            const alertHeader = sheet.getCell(`B${currentRow}`);
            alertHeader.value = '🚨 ALERTAS CRÍTICOS';
            alertHeader.font = { size: 14, bold: true, color: { argb: this.colors.danger } };
            alertHeader.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: this.colors.dangerBg }
            };
            alertHeader.alignment = { horizontal: 'center', vertical: 'middle' };
            alertHeader.border = this.createModernBorder(this.colors.danger);
            currentRow++;

            const alerts = [];

            if (technicalAnalysis.confirmedSpamtraps.length > 0) {
                alerts.push(`⛔ ${technicalAnalysis.confirmedSpamtraps.length} SPAMTRAPS DETECTADOS - Remover imediatamente!`);
            }

            if (technicalAnalysis.hardBounces.length > 0) {
                alerts.push(`📭 ${technicalAnalysis.hardBounces.length} HARD BOUNCES - Emails permanentemente inválidos`);
            }

            if (analysis.invalidEmails.length > 50) {
                alerts.push(`❌ ${analysis.invalidEmails.length} EMAILS INVÁLIDOS - Limpeza urgente necessária`);
            }

            alerts.forEach(alert => {
                sheet.mergeCells(`B${currentRow}:G${currentRow}`);
                sheet.getCell(`B${currentRow}`).value = alert;
                sheet.getCell(`B${currentRow}`).font = { size: 11, color: { argb: this.colors.danger } };
                sheet.getCell(`B${currentRow}`).alignment = { horizontal: 'left', vertical: 'middle' };
                currentRow++;
            });

            currentRow += 2;
        }

        // ================================================
        // MÉTRICAS TÉCNICAS - VISUAL MODERNO
        // ================================================
        sheet.mergeCells(`B${currentRow}:G${currentRow}`);
        const techHeader = sheet.getCell(`B${currentRow}`);
        techHeader.value = '🔍 ANÁLISE TÉCNICA AVANÇADA';
        techHeader.font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
        techHeader.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.light }
        };
        techHeader.alignment = { horizontal: 'center', vertical: 'middle' };
        currentRow += 2;

        // Grid de métricas técnicas
        const techMetrics = [
            {
                label: 'Domínios Catch-All',
                value: technicalAnalysis.catchAllDomains.length,
                icon: '📬',
                color: this.colors.catchAll
            },
            {
                label: 'Emails Funcionais',
                value: Object.values(technicalAnalysis.roleBasedEmails).flat().length,
                icon: '👤',
                color: this.colors.roleBased
            },
            {
                label: 'RFC Inválidos',
                value: technicalAnalysis.rfcInvalid.length,
                icon: '📝',
                color: this.colors.warning
            },
            {
                label: 'Possíveis Spamtraps',
                value: technicalAnalysis.likelySpamtraps.length,
                icon: '🪤',
                color: this.colors.danger
            },
            {
                label: 'Emails Reciclados',
                value: technicalAnalysis.recycledEmails.length,
                icon: '♻️',
                color: this.colors.warning
            },
            {
                label: 'Domínios Problemáticos',
                value: technicalAnalysis.problematicDomains.length,
                icon: '⚠️',
                color: this.colors.danger
            }
        ];

        // Renderizar em grid 3x2
        for (let i = 0; i < techMetrics.length; i++) {
            const metric = techMetrics[i];
            const col = i % 3;
            const startCol = String.fromCharCode(66 + col * 2); // B, D, F
            const endCol = String.fromCharCode(67 + col * 2);   // C, E, G
            const row = currentRow + Math.floor(i / 3) * 3;

            sheet.mergeCells(`${startCol}${row}:${endCol}${row + 1}`);
            const metricCell = sheet.getCell(`${startCol}${row}`);

            metricCell.value = `${metric.icon} ${metric.label}\n${metric.value}`;
            metricCell.font = { size: 10, color: { argb: metric.color } };
            metricCell.alignment = { horizontal: 'center', vertical: 'middle', wrapText: true };
            metricCell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: this.colors.white }
            };
            metricCell.border = this.createModernBorder(this.colors.borderColor);
        }

        currentRow += 7;

        // ================================================
        // DISTRIBUIÇÃO DE QUALIDADE - GRÁFICO VISUAL
        // ================================================
        sheet.mergeCells(`B${currentRow}:G${currentRow}`);
        const qualityHeader = sheet.getCell(`B${currentRow}`);
        qualityHeader.value = '📊 DISTRIBUIÇÃO DE QUALIDADE';
        qualityHeader.font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
        qualityHeader.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.light }
        };
        qualityHeader.alignment = { horizontal: 'center', vertical: 'middle' };
        currentRow += 2;

        const qualityData = [
            {
                label: 'Excelente (90-100)',
                count: technicalAnalysis.qualityDistribution.excellent.length,
                color: this.colors.success,
                icon: '⭐⭐⭐⭐⭐'
            },
            {
                label: 'Muito Bom (80-89)',
                count: technicalAnalysis.qualityDistribution.veryGood.length,
                color: this.colors.successLight,
                icon: '⭐⭐⭐⭐'
            },
            {
                label: 'Bom (70-79)',
                count: technicalAnalysis.qualityDistribution.good.length,
                color: this.colors.info,
                icon: '⭐⭐⭐'
            },
            {
                label: 'Regular (60-69)',
                count: technicalAnalysis.qualityDistribution.fair.length,
                color: this.colors.warning,
                icon: '⭐⭐'
            },
            {
                label: 'Baixo (40-59)',
                count: technicalAnalysis.qualityDistribution.poor.length,
                color: this.colors.warningLight,
                icon: '⭐'
            },
            {
                label: 'Muito Baixo (0-39)',
                count: technicalAnalysis.qualityDistribution.veryPoor.length +
                       technicalAnalysis.qualityDistribution.invalid.length,
                color: this.colors.danger,
                icon: '❌'
            }
        ];

        const maxCount = Math.max(...qualityData.map(q => q.count));

        qualityData.forEach((quality) => {
            // Label
            sheet.getCell(`B${currentRow}`).value = quality.icon;
            sheet.getCell(`C${currentRow}`).value = quality.label;
            sheet.getCell(`C${currentRow}`).font = { size: 10 };

            // Barra visual
            const barWidth = maxCount > 0 ? Math.round((quality.count / maxCount) * 100) : 0;
            const barCells = Math.ceil(barWidth / 33); // 3 células para 100%

            for (let i = 0; i < 3; i++) {
                const col = String.fromCharCode(68 + i); // D, E, F
                const cell = sheet.getCell(`${col}${currentRow}`);

                if (i < barCells) {
                    cell.fill = {
                        type: 'pattern',
                        pattern: 'solid',
                        fgColor: { argb: quality.color }
                    };
                }
            }

            // Valor
            sheet.getCell(`G${currentRow}`).value = quality.count;
            sheet.getCell(`G${currentRow}`).font = { bold: true, color: { argb: quality.color } };
            sheet.getCell(`G${currentRow}`).alignment = { horizontal: 'center' };

            currentRow++;
        });

        return sheet;
    }

    // ================================================
    // ABA 2: RESUMO EXECUTIVO
    // ================================================
    async createExecutiveSummarySheet(stats, analysis) {
        const sheet = this.workbook.addWorksheet('📋 Resumo Executivo', {
            properties: { tabColor: { argb: this.colors.primaryLight } },
            views: [{ showGridLines: false }]
        });

        sheet.columns = [
            { width: 3 },
            { width: 40 },
            { width: 30 },
            { width: 30 },
            { width: 3 }
        ];

        let currentRow = 3;

        // Header elegante
        sheet.mergeCells(`B${currentRow}:D${currentRow}`);
        const titleCell = sheet.getCell(`B${currentRow}`);
        titleCell.value = 'RESUMO EXECUTIVO';
        titleCell.font = { name: 'Segoe UI', size: 20, bold: true, color: { argb: this.colors.primaryDark } };
        titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(currentRow).height = 40;
        currentRow += 2;

        // Score visual da lista
        const listScore = this.calculateListScore(stats);
        const scoreColor = listScore >= 90 ? this.colors.success :
                          listScore >= 70 ? this.colors.warning :
                          this.colors.danger;

        sheet.mergeCells(`B${currentRow}:D${currentRow + 3}`);
        const scoreCard = sheet.getCell(`B${currentRow}`);
        scoreCard.value = {
            richText: [
                { text: 'SCORE GERAL DA LISTA\n', font: { size: 12, color: { argb: this.colors.gray } } },
                { text: `${listScore}`, font: { size: 36, bold: true, color: { argb: scoreColor } } },
                { text: '/100', font: { size: 20, color: { argb: this.colors.gray } } }
            ]
        };
        scoreCard.fill = {
            type: 'gradient',
            gradient: 'angle',
            degree: 135,
            stops: [
                { position: 0, color: { argb: this.colors.white } },
                { position: 1, color: { argb: this.colors.light } }
            ]
        };
        scoreCard.alignment = { horizontal: 'center', vertical: 'middle', wrapText: true };
        scoreCard.border = this.createModernBorder(scoreColor);
        currentRow += 5;

        // Classificação da lista
        const classification = this.getListClassification(listScore, stats);
        sheet.mergeCells(`B${currentRow}:D${currentRow}`);
        const classCell = sheet.getCell(`B${currentRow}`);
        classCell.value = classification.label;
        classCell.font = { size: 16, bold: true, color: { argb: classification.color } };
        classCell.alignment = { horizontal: 'center', vertical: 'middle' };
        classCell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: classification.bgColor }
        };
        sheet.getRow(currentRow).height = 35;
        currentRow += 2;

        // Descrição detalhada
        sheet.mergeCells(`B${currentRow}:D${currentRow + 2}`);
        const descCell = sheet.getCell(`B${currentRow}`);
        descCell.value = classification.description;
        descCell.font = { size: 12, italic: true, color: { argb: this.colors.dark } };
        descCell.alignment = { horizontal: 'left', vertical: 'top', wrapText: true };
        currentRow += 4;

        // Principais descobertas
        const findings = this.generateKeyFindings(stats, analysis);

        sheet.mergeCells(`B${currentRow}:D${currentRow}`);
        sheet.getCell(`B${currentRow}`).value = '🔍 PRINCIPAIS DESCOBERTAS';
        sheet.getCell(`B${currentRow}`).font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
        sheet.getCell(`B${currentRow}`).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.light }
        };
        currentRow += 2;

        findings.forEach(finding => {
            sheet.mergeCells(`B${currentRow}:D${currentRow}`);
            const findingCell = sheet.getCell(`B${currentRow}`);
            findingCell.value = `${finding.icon} ${finding.text}`;
            findingCell.font = { size: 11, color: { argb: finding.color } };
            findingCell.alignment = { horizontal: 'left', vertical: 'middle', wrapText: true };
            findingCell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: this.colors.white }
            };
            findingCell.border = {
                left: { style: 'thick', color: { argb: finding.color } }
            };
            sheet.getRow(currentRow).height = 25;
            currentRow++;
        });

        return sheet;
    }

    // ================================================
    // ABA 3: PLANO DE AÇÃO
    // ================================================
    async createActionPlanSheet(results, stats, analysis, technicalAnalysis) {
        const sheet = this.workbook.addWorksheet('🎯 Plano de Ação', {
            properties: { tabColor: { argb: this.colors.danger } },
            views: [{ showGridLines: false }]
        });

        sheet.columns = [
            { width: 2 },
            { width: 8 },
            { width: 35 },
            { width: 50 },
            { width: 20 },
            { width: 2 }
        ];

        let currentRow = 2;

        // Header
        sheet.mergeCells(`B${currentRow}:E${currentRow}`);
        const headerCell = sheet.getCell(`B${currentRow}`);
        headerCell.value = '🎯 PLANO DE AÇÃO PRIORITÁRIO';
        headerCell.font = { size: 20, bold: true, color: { argb: this.colors.white } };
        headerCell.fill = {
            type: 'gradient',
            gradient: 'angle',
            degree: 90,
            stops: [
                { position: 0, color: { argb: this.colors.danger } },
                { position: 1, color: { argb: this.colors.dangerLight } }
            ]
        };
        headerCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(currentRow).height = 40;
        currentRow += 2;

        // Gerar ações baseadas na análise
        const actions = this.generateActionPlan(stats, analysis, technicalAnalysis);

        // Renderizar ações por prioridade
        const priorities = ['CRÍTICA', 'ALTA', 'MÉDIA', 'BAIXA', 'INFO'];

        priorities.forEach(priority => {
            const priorityActions = actions.filter(a => a.priority === priority);

            if (priorityActions.length > 0) {
                // Header da prioridade
                sheet.mergeCells(`B${currentRow}:E${currentRow}`);
                const priorityHeader = sheet.getCell(`B${currentRow}`);

                const priorityConfig = this.getPriorityConfig(priority);
                priorityHeader.value = `${priorityConfig.icon} PRIORIDADE ${priority}`;
                priorityHeader.font = {
                    size: 14,
                    bold: true,
                    color: { argb: this.colors.white }
                };
                priorityHeader.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: priorityConfig.color }
                };
                priorityHeader.alignment = { horizontal: 'left', vertical: 'middle' };
                sheet.getRow(currentRow).height = 30;
                currentRow++;

                // Ações da prioridade
                priorityActions.forEach((action, index) => {
                    // Número da ação
                    sheet.getCell(`B${currentRow}`).value = `${index + 1}.`;
                    sheet.getCell(`B${currentRow}`).font = { bold: true, size: 12 };
                    sheet.getCell(`B${currentRow}`).alignment = { horizontal: 'center' };

                    // Título da ação
                    sheet.getCell(`C${currentRow}`).value = action.title;
                    sheet.getCell(`C${currentRow}`).font = { bold: true, size: 11 };

                    // Descrição
                    sheet.getCell(`D${currentRow}`).value = action.description;
                    sheet.getCell(`D${currentRow}`).font = { size: 10 };
                    sheet.getCell(`D${currentRow}`).alignment = { wrapText: true };

                    // Impacto
                    sheet.getCell(`E${currentRow}`).value = action.impact;
                    sheet.getCell(`E${currentRow}`).font = {
                        size: 10,
                        bold: true,
                        color: { argb: priorityConfig.color }
                    };
                    sheet.getCell(`E${currentRow}`).alignment = { horizontal: 'center' };

                    // Aplicar background alternado
                    if (index % 2 === 0) {
                        for (let col = 66; col <= 69; col++) { // B to E
                            sheet.getCell(`${String.fromCharCode(col)}${currentRow}`).fill = {
                                type: 'pattern',
                                pattern: 'solid',
                                fgColor: { argb: this.colors.grayBg }
                            };
                        }
                    }

                    sheet.getRow(currentRow).height = 30;
                    currentRow++;
                });

                currentRow++;
            }
        });

        // Resumo de impacto
        currentRow++;
        sheet.mergeCells(`B${currentRow}:E${currentRow}`);
        const impactHeader = sheet.getCell(`B${currentRow}`);
        impactHeader.value = '📊 IMPACTO ESPERADO';
        impactHeader.font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
        impactHeader.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.light }
        };
        currentRow += 2;

        const impactSummary = this.calculateExpectedImpact(stats, analysis, technicalAnalysis);

        impactSummary.forEach(impact => {
            sheet.mergeCells(`B${currentRow}:E${currentRow}`);
            const impactCell = sheet.getCell(`B${currentRow}`);
            impactCell.value = `${impact.icon} ${impact.text}`;
            impactCell.font = { size: 11, color: { argb: impact.color } };
            impactCell.alignment = { horizontal: 'left', vertical: 'middle' };
            currentRow++;
        });

        return sheet;
    }

    // ================================================
    // ABA 4: DADOS DETALHADOS (MELHORADA)
    // ================================================
    async createDetailedDataSheet(results) {
        const sheet = this.workbook.addWorksheet('📑 Dados Completos', {
            properties: { tabColor: { argb: this.colors.info } }
        });

        // Colunas expandidas com todas as novas informações
        sheet.columns = [
            { header: '#', key: 'index', width: 8 },
            { header: 'Email', key: 'email', width: 35 },
            { header: 'Válido', key: 'valid', width: 10 },
            { header: 'Score', key: 'score', width: 10 },
            { header: 'Qualidade', key: 'quality', width: 15 },
            { header: 'RFC', key: 'rfc', width: 8 },
            { header: 'Catch-All', key: 'catchAll', width: 12 },
            { header: 'Role-Based', key: 'roleBased', width: 20 },
            { header: 'Spamtrap', key: 'spamtrap', width: 12 },
            { header: 'Bounce', key: 'bounce', width: 12 },
            { header: 'Corrigido', key: 'corrected', width: 12 },
            { header: 'Original', key: 'originalEmail', width: 35 },
            { header: 'Tipo Comprador', key: 'buyerType', width: 25 },
            { header: 'Risco', key: 'riskLevel', width: 15 },
            { header: 'Linha', key: 'originalLine', width: 8 }
        ];

        // Header estilizado
        const headerRow = sheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: this.colors.white } };
        headerRow.fill = {
            type: 'gradient',
            gradient: 'angle',
            degree: 90,
            stops: [
                { position: 0, color: { argb: this.colors.primary } },
                { position: 1, color: { argb: this.colors.primaryDark } }
            ]
        };
        headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
        headerRow.height = 30;

        // Adicionar dados com formatação condicional
        results.forEach((result, index) => {
            const wasCorrected = this.wasEmailCorrected(result);
            const quality = result.insights?.emailQuality || this.getEmailQuality(result.score);

            const row = sheet.addRow({
                index: index + 1,
                email: result.correctedEmail || result.email || '-----',
                valid: result.valid || result.score >= 45 ? '✅' : '❌',
                score: result.score || 0,
                quality: this.translations.emailQuality[quality] || quality,
                rfc: result.checks?.rfc?.valid ? '✅' : '❌',
                catchAll: result.checks?.catchAll?.isCatchAll ? '⚠️ Sim' :
                         result.checks?.catchAll?.isRejectAll ? '🚫 Reject' : '✅ Não',
                roleBased: result.checks?.roleBased?.isRoleBased ?
                          this.translations.roleCategories[result.checks.roleBased.category] ||
                          result.checks.roleBased.category : '-----',
                spamtrap: result.checks?.spamtrap?.isSpamtrap ? '🚨 SIM' :
                         result.checks?.spamtrap?.isLikelySpamtrap ? '⚠️ Possível' : '✅ Não',
                bounce: result.checks?.bounce?.hasBounced ?
                       (result.checks.bounce.isPermanent ? '🚫 Hard' : '⚠️ Soft') : '✅ Não',
                corrected: wasCorrected ? '✏️ Sim' : '-----',
                originalEmail: wasCorrected ?
                              (result.originalEmail || result.normalizedEmail || '-----') : '-----',
                buyerType: this.translations.buyerTypes[result.scoring?.buyerType] || '-----',
                riskLevel: this.translations.riskLevels[result.scoring?.riskLevel] || '-----',
                originalLine: result.originalLine || index + 2
            });

            // Aplicar formatação condicional baseada no score
            const scoreCell = row.getCell('score');
            if (result.score >= 80) {
                scoreCell.font = { color: { argb: this.colors.success }, bold: true };
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: this.colors.successBg }
                };
            } else if (result.score >= 60) {
                scoreCell.font = { color: { argb: this.colors.info } };
            } else if (result.score >= 40) {
                scoreCell.font = { color: { argb: this.colors.warning } };
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: this.colors.warningBg }
                };
            } else {
                scoreCell.font = { color: { argb: this.colors.danger }, bold: true };
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: this.colors.dangerBg }
                };
            }

            // Destacar emails corrigidos
            if (wasCorrected) {
                row.getCell('email').fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: this.colors.correctionBg }
                };
            }

            // Destacar spamtraps
            if (result.checks?.spamtrap?.isSpamtrap) {
                row.getCell('spamtrap').font = {
                    color: { argb: this.colors.white },
                    bold: true
                };
                row.getCell('spamtrap').fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: this.colors.danger }
                };
            }
        });

        // Adicionar filtros
        sheet.autoFilter = {
            from: 'A1',
            to: `O${results.length + 1}`
        };

        // Freeze header row
        sheet.views = [
            { state: 'frozen', xSplit: 0, ySplit: 1 }
        ];

        return sheet;
    }

    // ================================================
    // ABA 5: LISTA LIMPA (MELHORADA)
    // ================================================
    async createCleanListSheet(results, analysis) {
        const sheet = this.workbook.addWorksheet('✅ Lista Limpa', {
            properties: { tabColor: { argb: this.colors.success } },
            views: [{ showGridLines: false }]
        });

        // Filtrar apenas emails aprovados
        const approvedEmails = results.filter(r =>
            r.score >= 60 &&
            !r.checks?.spamtrap?.isSpamtrap &&
            !r.checks?.bounce?.isPermanent
        );

        sheet.columns = [
            { width: 2 },
            { header: '#', key: 'index', width: 8 },
            { header: 'Email Aprovado', key: 'email', width: 40 },
            { header: 'Score', key: 'score', width: 12 },
            { header: 'Qualidade', key: 'quality', width: 20 },
            { header: 'Status', key: 'status', width: 25 },
            { width: 2 }
        ];

        // Header premium
        let currentRow = 2;
        sheet.mergeCells(`B${currentRow}:F${currentRow}`);
        const titleCell = sheet.getCell(`B${currentRow}`);
        titleCell.value = '✅ LISTA LIMPA - EMAILS APROVADOS PARA CAMPANHAS';
        titleCell.font = { size: 16, bold: true, color: { argb: this.colors.white } };
        titleCell.fill = {
            type: 'gradient',
            gradient: 'angle',
            degree: 90,
            stops: [
                { position: 0, color: { argb: this.colors.success } },
                { position: 1, color: { argb: this.colors.successLight } }
            ]
        };
        titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(currentRow).height = 40;
        currentRow += 2;

        // Estatísticas da lista limpa
        sheet.mergeCells(`B${currentRow}:F${currentRow}`);
        const statsCell = sheet.getCell(`B${currentRow}`);
        statsCell.value = `📊 Total de emails aprovados: ${approvedEmails.length} de ${results.length} (${((approvedEmails.length / results.length) * 100).toFixed(1)}%)`;
        statsCell.font = { size: 12, italic: true, color: { argb: this.colors.gray } };
        statsCell.alignment = { horizontal: 'center' };
        statsCell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.successBg }
        };
        currentRow += 2;

        // Headers da tabela
        const headerRow = sheet.getRow(currentRow);
        ['', '#', 'Email Aprovado', 'Score', 'Qualidade', 'Status', ''].forEach((header, index) => {
            const cell = headerRow.getCell(index + 1);
            if (header) {
                cell.value = header;
                cell.font = { bold: true, color: { argb: this.colors.white } };
                cell.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: this.colors.success }
                };
                cell.alignment = { horizontal: 'center', vertical: 'middle' };
            }
        });
        headerRow.height = 25;
        currentRow++;

        // Adicionar emails aprovados (ordenados por score)
        approvedEmails
            .sort((a, b) => b.score - a.score)
            .forEach((result, index) => {
                const quality = this.getEmailQualityLabel(result.score);
                const qualityColor = result.score >= 80 ? this.colors.success :
                                   result.score >= 70 ? this.colors.info : this.colors.warning;

                const row = sheet.getRow(currentRow);
                row.getCell(2).value = index + 1;
                row.getCell(3).value = result.correctedEmail || result.email;
                row.getCell(4).value = result.score;
                row.getCell(5).value = quality;
                row.getCell(6).value = '✅ APROVADO';

                // Estilo
                row.getCell(4).font = { bold: true, color: { argb: qualityColor } };
                row.getCell(5).font = { color: { argb: qualityColor } };
                row.getCell(6).font = { color: { argb: this.colors.success } };

                // Background alternado
                if (index % 2 === 0) {
                    for (let col = 2; col <= 6; col++) {
                        row.getCell(col).fill = {
                            type: 'pattern',
                            pattern: 'solid',
                            fgColor: { argb: this.colors.grayBg }
                        };
                    }
                }

                currentRow++;
            });

        // Resumo final
        currentRow += 2;
        sheet.mergeCells(`B${currentRow}:F${currentRow + 3}`);
        const summaryCell = sheet.getCell(`B${currentRow}`);
        summaryCell.value = `📋 RESUMO DA LISTA LIMPA:\n` +
                           `• Excelentes (90+): ${approvedEmails.filter(r => r.score >= 90).length}\n` +
                           `• Muito Bons (80-89): ${approvedEmails.filter(r => r.score >= 80 && r.score < 90).length}\n` +
                           `• Bons (70-79): ${approvedEmails.filter(r => r.score >= 70 && r.score < 80).length}\n` +
                           `• Aceitáveis (60-69): ${approvedEmails.filter(r => r.score >= 60 && r.score < 70).length}`;
        summaryCell.font = { size: 11 };
        summaryCell.alignment = { horizontal: 'left', vertical: 'top', wrapText: true };
        summaryCell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.successBg }
        };
        summaryCell.border = this.createModernBorder(this.colors.success);

        return sheet;
    }

    // ================================================
    // ABA 6: ALERTAS CRÍTICOS (NOVA)
    // ================================================
    async createCriticalAlertsSheet(results, technicalAnalysis) {
        const sheet = this.workbook.addWorksheet('🚨 Alertas Críticos', {
            properties: { tabColor: { argb: this.colors.danger } },
            views: [{ showGridLines: false }]
        });

        sheet.columns = [
            { width: 2 },
            { width: 40 },
            { width: 20 },
            { width: 40 },
            { width: 20 },
            { width: 2 }
        ];

        let currentRow = 2;

        // Header
        sheet.mergeCells(`B${currentRow}:E${currentRow}`);
        const headerCell = sheet.getCell(`B${currentRow}`);
        headerCell.value = '🚨 ALERTAS CRÍTICOS E AÇÕES IMEDIATAS';
        headerCell.font = { size: 18, bold: true, color: { argb: this.colors.white } };
        headerCell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: this.colors.danger }
        };
        headerCell.alignment = { horizontal: 'center', vertical: 'middle' };
        sheet.getRow(currentRow).height = 40;
        currentRow += 2;

        // ================================================
        // SPAMTRAPS
        // ================================================
        if (technicalAnalysis.confirmedSpamtraps.length > 0 ||
            technicalAnalysis.likelySpamtraps.length > 0) {

            sheet.mergeCells(`B${currentRow}:E${currentRow}`);
            const spamtrapHeader = sheet.getCell(`B${currentRow}`);
            spamtrapHeader.value = '🪤 SPAMTRAPS DETECTADOS';
            spamtrapHeader.font = { size: 14, bold: true, color: { argb: this.colors.white } };
            spamtrapHeader.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: this.colors.spamtrap }
            };
            currentRow++;

            // Spamtraps confirmados
            if (technicalAnalysis.confirmedSpamtraps.length > 0) {
                sheet.getCell(`B${currentRow}`).value = 'CONFIRMADOS (Remover Imediatamente!)';
                sheet.getCell(`B${currentRow}`).font = { bold: true, color: { argb: this.colors.danger } };
                currentRow++;

                technicalAnalysis.confirmedSpamtraps.forEach(trap => {
                    sheet.getCell(`B${currentRow}`).value = trap.email;
                    sheet.getCell(`C${currentRow}`).value = `Confiança: ${(trap.confidence * 100).toFixed(0)}%`;
                    sheet.getCell(`D${currentRow}`).value = trap.indicators.join(', ');
                    sheet.getCell(`E${currentRow}`).value = `Linha: ${trap.line}`;

                    for (let col = 66; col <= 69; col++) {
                        sheet.getCell(`${String.fromCharCode(col)}${currentRow}`).fill = {
                            type: 'pattern',
                            pattern: 'solid',
                            fgColor: { argb: this.colors.dangerBg }
                        };
                    }
                    currentRow++;
                });
            }

            // Possíveis spamtraps
           if (technicalAnalysis.likelySpamtraps.length > 0) {
               currentRow++;
               sheet.getCell(`B${currentRow}`).value = 'POSSÍVEIS (Revisar com Urgência)';
               sheet.getCell(`B${currentRow}`).font = { bold: true, color: { argb: this.colors.warning } };
               currentRow++;

               technicalAnalysis.likelySpamtraps.slice(0, 10).forEach(trap => {
                   sheet.getCell(`B${currentRow}`).value = trap.email;
                   sheet.getCell(`C${currentRow}`).value = `Confiança: ${(trap.confidence * 100).toFixed(0)}%`;
                   sheet.getCell(`D${currentRow}`).value = trap.indicators.slice(0, 2).join(', ');
                   sheet.getCell(`E${currentRow}`).value = `Linha: ${trap.line}`;

                   for (let col = 66; col <= 69; col++) {
                       sheet.getCell(`${String.fromCharCode(col)}${currentRow}`).fill = {
                           type: 'pattern',
                           pattern: 'solid',
                           fgColor: { argb: this.colors.warningBg }
                       };
                   }
                   currentRow++;
               });

               if (technicalAnalysis.likelySpamtraps.length > 10) {
                   sheet.getCell(`B${currentRow}`).value = `... e mais ${technicalAnalysis.likelySpamtraps.length - 10} possíveis spamtraps`;
                   sheet.getCell(`B${currentRow}`).font = { italic: true, color: { argb: this.colors.gray } };
                   currentRow++;
               }
           }
           currentRow += 2;
       }

       // ================================================
       // HARD BOUNCES
       // ================================================
       if (technicalAnalysis.hardBounces.length > 0) {
           sheet.mergeCells(`B${currentRow}:E${currentRow}`);
           const bounceHeader = sheet.getCell(`B${currentRow}`);
           bounceHeader.value = '📭 HARD BOUNCES - EMAILS PERMANENTEMENTE INVÁLIDOS';
           bounceHeader.font = { size: 14, bold: true, color: { argb: this.colors.white } };
           bounceHeader.fill = {
               type: 'pattern',
               pattern: 'solid',
               fgColor: { argb: this.colors.danger }
           };
           currentRow++;

           technicalAnalysis.hardBounces.slice(0, 20).forEach(bounce => {
               sheet.getCell(`B${currentRow}`).value = bounce.email;
               sheet.getCell(`C${currentRow}`).value = bounce.type || 'Hard Bounce';
               sheet.getCell(`D${currentRow}`).value = bounce.category || 'Mailbox não existe';
               sheet.getCell(`E${currentRow}`).value = `Linha: ${bounce.line}`;

               for (let col = 66; col <= 69; col++) {
                   sheet.getCell(`${String.fromCharCode(col)}${currentRow}`).fill = {
                       type: 'pattern',
                       pattern: 'solid',
                       fgColor: { argb: this.colors.dangerBg }
                   };
               }
               currentRow++;
           });

           if (technicalAnalysis.hardBounces.length > 20) {
               sheet.getCell(`B${currentRow}`).value = `... e mais ${technicalAnalysis.hardBounces.length - 20} hard bounces`;
               sheet.getCell(`B${currentRow}`).font = { italic: true, color: { argb: this.colors.gray } };
               currentRow++;
           }
           currentRow += 2;
       }

       // ================================================
       // DOMÍNIOS PROBLEMÁTICOS
       // ================================================
       if (technicalAnalysis.problematicDomains.length > 0) {
           sheet.mergeCells(`B${currentRow}:E${currentRow}`);
           const domainHeader = sheet.getCell(`B${currentRow}`);
           domainHeader.value = '⚠️ DOMÍNIOS PROBLEMÁTICOS';
           domainHeader.font = { size: 14, bold: true, color: { argb: this.colors.white } };
           domainHeader.fill = {
               type: 'pattern',
               pattern: 'solid',
               fgColor: { argb: this.colors.warning }
           };
           currentRow++;

           sheet.getCell(`B${currentRow}`).value = 'Domínio';
           sheet.getCell(`C${currentRow}`).value = 'Total';
           sheet.getCell(`D${currentRow}`).value = 'Problemas';
           sheet.getCell(`E${currentRow}`).value = 'Score Médio';
           sheet.getRow(currentRow).font = { bold: true };
           currentRow++;

           technicalAnalysis.problematicDomains.forEach(domain => {
               sheet.getCell(`B${currentRow}`).value = domain.domain;
               sheet.getCell(`C${currentRow}`).value = domain.total;
               sheet.getCell(`D${currentRow}`).value = domain.issues.join(', ');
               sheet.getCell(`E${currentRow}`).value = domain.avgScore;

               for (let col = 66; col <= 69; col++) {
                   sheet.getCell(`${String.fromCharCode(col)}${currentRow}`).fill = {
                       type: 'pattern',
                       pattern: 'solid',
                       fgColor: { argb: this.colors.warningBg }
                   };
               }
               currentRow++;
           });
       }

       // ================================================
       // RESUMO DE AÇÕES CRÍTICAS
       // ================================================
       currentRow += 2;
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       const actionHeader = sheet.getCell(`B${currentRow}`);
       actionHeader.value = '⚡ AÇÕES IMEDIATAS NECESSÁRIAS';
       actionHeader.font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
       actionHeader.fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.light }
       };
       currentRow += 2;

       const criticalActions = [
           {
               condition: technicalAnalysis.confirmedSpamtraps.length > 0,
               action: `1. REMOVER IMEDIATAMENTE ${technicalAnalysis.confirmedSpamtraps.length} spamtraps confirmados`,
               color: this.colors.danger
           },
           {
               condition: technicalAnalysis.hardBounces.length > 0,
               action: `2. REMOVER ${technicalAnalysis.hardBounces.length} emails com hard bounce`,
               color: this.colors.danger
           },
           {
               condition: technicalAnalysis.likelySpamtraps.length > 5,
               action: `3. REVISAR ${technicalAnalysis.likelySpamtraps.length} possíveis spamtraps`,
               color: this.colors.warning
           },
           {
               condition: technicalAnalysis.problematicDomains.length > 0,
               action: `4. INVESTIGAR ${technicalAnalysis.problematicDomains.length} domínios problemáticos`,
               color: this.colors.warning
           }
       ];

       criticalActions.filter(a => a.condition).forEach(action => {
           sheet.mergeCells(`B${currentRow}:E${currentRow}`);
           const actionCell = sheet.getCell(`B${currentRow}`);
           actionCell.value = action.action;
           actionCell.font = { size: 12, bold: true, color: { argb: action.color } };
           actionCell.border = {
               left: { style: 'thick', color: { argb: action.color } }
           };
           currentRow++;
       });

       return sheet;
   }

   // ================================================
   // ABA 7: EMAILS INVÁLIDOS (MELHORADA)
   // ================================================
   async createInvalidEmailsSheet(results, analysis) {
       const sheet = this.workbook.addWorksheet('❌ Emails Inválidos', {
           properties: { tabColor: { argb: this.colors.danger } }
       });

       sheet.columns = [
           { header: '#', key: 'index', width: 8 },
           { header: 'Email', key: 'email', width: 35 },
           { header: 'Score', key: 'score', width: 10 },
           { header: 'Motivo Principal', key: 'reason', width: 40 },
           { header: 'Problemas Detectados', key: 'problems', width: 35 },
           { header: 'Ação', key: 'action', width: 20 },
           { header: 'Linha', key: 'line', width: 10 }
       ];

       // Header estilizado
       const headerRow = sheet.getRow(1);
       headerRow.font = { bold: true, color: { argb: this.colors.white } };
       headerRow.fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.danger }
       };
       headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
       headerRow.height = 25;

       // Adicionar emails inválidos
       analysis.invalidEmails.forEach((item, index) => {
           const result = results.find(r => (r.correctedEmail || r.email) === item.email);

           // Coletar todos os problemas
           const problems = [];
           if (result?.checks?.rfc && !result.checks.rfc.valid) problems.push('RFC inválido');
           if (result?.checks?.spamtrap?.isSpamtrap) problems.push('🚨 SPAMTRAP');
           if (result?.checks?.bounce?.isPermanent) problems.push('Hard bounce');
           if (result?.checks?.disposable?.isDisposable) problems.push('Email descartável');
           if (result?.checks?.dns && !result.checks.dns.valid) problems.push('DNS inválido');

           const row = sheet.addRow({
               index: index + 1,
               email: item.email,
               score: item.score,
               reason: item.reason,
               problems: problems.join(', ') || 'Score muito baixo',
               action: 'REMOVER',
               line: item.originalLine
           });

           // Destacar spamtraps
           if (problems.includes('🚨 SPAMTRAP')) {
               row.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: this.colors.spamtrapBg }
               };
               row.font = { bold: true, color: { argb: this.colors.danger } };
           } else {
               row.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: this.colors.dangerBg }
               };
           }
       });

       // Adicionar filtros
       sheet.autoFilter = {
           from: 'A1',
           to: `G${analysis.invalidEmails.length + 1}`
       };

       // Resumo
       const summaryRow = analysis.invalidEmails.length + 3;
       sheet.mergeCells(`A${summaryRow}:G${summaryRow}`);
       const summaryCell = sheet.getCell(`A${summaryRow}`);
       summaryCell.value = `⚠️ TOTAL DE EMAILS PARA REMOVER: ${analysis.invalidEmails.length}`;
       summaryCell.font = { size: 14, bold: true, color: { argb: this.colors.white } };
       summaryCell.fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.danger }
       };
       summaryCell.alignment = { horizontal: 'center', vertical: 'middle' };

       return sheet;
   }

   // ================================================
   // ABA 8: EMAILS SUSPEITOS (MELHORADA)
   // ================================================
   async createSuspiciousEmailsSheet(results, analysis) {
       const sheet = this.workbook.addWorksheet('⚠️ Emails Suspeitos', {
           properties: { tabColor: { argb: this.colors.warning } }
       });

       sheet.columns = [
           { header: '#', key: 'index', width: 8 },
           { header: 'Email', key: 'email', width: 35 },
           { header: 'Score', key: 'score', width: 10 },
           { header: 'Corrigido?', key: 'corrected', width: 12 },
           { header: 'Alertas', key: 'alerts', width: 30 },
           { header: 'Tipo', key: 'buyerType', width: 25 },
           { header: 'Ação Sugerida', key: 'action', width: 30 }
       ];

       // Header
       const headerRow = sheet.getRow(1);
       headerRow.font = { bold: true, color: { argb: this.colors.white } };
       headerRow.fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.warning }
       };
       headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
       headerRow.height = 25;

       // Separar emails corrigidos dos não corrigidos
       const correctedSuspicious = analysis.suspiciousEmails.filter(e => e.wasCorrected);
       const uncorrectedSuspicious = analysis.suspiciousEmails.filter(e => !e.wasCorrected);

       let rowIndex = 2;

       // Emails corrigidos primeiro
       if (correctedSuspicious.length > 0) {
           correctedSuspicious.forEach((item, index) => {
               const result = results.find(r => (r.correctedEmail || r.email) === item.email);
               const alerts = [];

               if (result?.checks?.catchAll?.isCatchAll) alerts.push('📬 Catch-all');
               if (result?.checks?.roleBased?.isRoleBased) alerts.push('👤 Role-based');
               if (result?.checks?.spamtrap?.isLikelySpamtrap) alerts.push('🪤 Possível spamtrap');

               const row = sheet.getRow(rowIndex);
               row.values = {
                   index: index + 1,
                   email: item.email,
                   score: item.score,
                   corrected: '✏️ SIM',
                   alerts: alerts.join(', ') || 'Score baixo',
                   buyerType: item.buyerType,
                   action: 'VERIFICAR CORREÇÃO'
               };

               row.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: this.colors.correctionBg }
               };

               rowIndex++;
           });
       }

       // Emails não corrigidos
       uncorrectedSuspicious.forEach((item, index) => {
           const result = results.find(r => (r.correctedEmail || r.email) === item.email);
           const alerts = [];

           if (result?.checks?.catchAll?.isCatchAll) alerts.push('📬 Catch-all');
           if (result?.checks?.roleBased?.isRoleBased) alerts.push('👤 Role-based');
           if (result?.checks?.spamtrap?.isLikelySpamtrap) alerts.push('🪤 Possível spamtrap');
           if (result?.checks?.bounce?.hasBounced) alerts.push('📭 Bounce histórico');

           const row = sheet.getRow(rowIndex);
           row.values = {
               index: correctedSuspicious.length + index + 1,
               email: item.email,
               score: item.score,
               corrected: 'NÃO',
               alerts: alerts.join(', ') || 'Score baixo',
               buyerType: item.buyerType,
               action: item.action
           };

           row.fill = {
               type: 'pattern',
               pattern: 'solid',
               fgColor: { argb: this.colors.warningBg }
           };

           rowIndex++;
       });

       // Adicionar filtros
       sheet.autoFilter = {
           from: 'A1',
           to: `G${rowIndex - 1}`
       };

       return sheet;
   }

   // ================================================
   // ABA 9: ANÁLISE TÉCNICA (NOVA)
   // ================================================
   async createTechnicalAnalysisSheet(results, technicalAnalysis) {
       const sheet = this.workbook.addWorksheet('🔧 Análise Técnica', {
           properties: { tabColor: { argb: this.colors.primaryDark } },
           views: [{ showGridLines: false }]
       });

       sheet.columns = [
           { width: 2 },
           { width: 30 },
           { width: 20 },
           { width: 30 },
           { width: 20 },
           { width: 2 }
       ];

       let currentRow = 2;

       // Header
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       const headerCell = sheet.getCell(`B${currentRow}`);
       headerCell.value = '🔧 ANÁLISE TÉCNICA AVANÇADA';
       headerCell.font = { size: 18, bold: true, color: { argb: this.colors.white } };
       headerCell.fill = {
           type: 'gradient',
           gradient: 'angle',
           degree: 90,
           stops: [
               { position: 0, color: { argb: this.colors.primaryDark } },
               { position: 1, color: { argb: this.colors.primary } }
           ]
       };
       headerCell.alignment = { horizontal: 'center', vertical: 'middle' };
       sheet.getRow(currentRow).height = 40;
       currentRow += 2;

       // ================================================
       // RFC COMPLIANCE
       // ================================================
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       sheet.getCell(`B${currentRow}`).value = '📝 RFC 5321/5322 COMPLIANCE';
       sheet.getCell(`B${currentRow}`).font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
       sheet.getCell(`B${currentRow}`).fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.light }
       };
       currentRow++;

       const rfcStats = {
           total: results.length,
           valid: results.filter(r => r.checks?.rfc?.valid).length,
           invalid: technicalAnalysis.rfcInvalid.length,
           warnings: technicalAnalysis.rfcWarnings.length
       };

       sheet.getCell(`B${currentRow}`).value = 'RFC Válidos:';
       sheet.getCell(`C${currentRow}`).value = `${rfcStats.valid} (${((rfcStats.valid / rfcStats.total) * 100).toFixed(1)}%)`;
       sheet.getCell(`C${currentRow}`).font = { color: { argb: this.colors.success } };
       currentRow++;

       sheet.getCell(`B${currentRow}`).value = 'RFC Inválidos:';
       sheet.getCell(`C${currentRow}`).value = rfcStats.invalid;
       sheet.getCell(`C${currentRow}`).font = { color: { argb: this.colors.danger } };
       currentRow++;

       sheet.getCell(`B${currentRow}`).value = 'Com Warnings:';
       sheet.getCell(`C${currentRow}`).value = rfcStats.warnings;
       sheet.getCell(`C${currentRow}`).font = { color: { argb: this.colors.warning } };
       currentRow += 2;

       // ================================================
       // CATCH-ALL DOMAINS
       // ================================================
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       sheet.getCell(`B${currentRow}`).value = '📬 DOMÍNIOS CATCH-ALL';
       sheet.getCell(`B${currentRow}`).font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
       sheet.getCell(`B${currentRow}`).fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.catchAllBg }
       };
       currentRow++;

       if (technicalAnalysis.catchAllDomains.length > 0) {
           sheet.getCell(`B${currentRow}`).value = 'Domínio';
           sheet.getCell(`C${currentRow}`).value = 'Confiança';
           sheet.getCell(`D${currentRow}`).value = 'Emails';
           sheet.getRow(currentRow).font = { bold: true };
           currentRow++;

           technicalAnalysis.catchAllDomains.slice(0, 10).forEach(catchAll => {
               sheet.getCell(`B${currentRow}`).value = catchAll.domain;
               sheet.getCell(`C${currentRow}`).value = `${(catchAll.confidence * 100).toFixed(0)}%`;
               sheet.getCell(`D${currentRow}`).value = catchAll.emails.length;
               currentRow++;
           });
       } else {
           sheet.getCell(`B${currentRow}`).value = 'Nenhum domínio catch-all detectado';
           sheet.getCell(`B${currentRow}`).font = { italic: true, color: { argb: this.colors.gray } };
           currentRow++;
       }
       currentRow += 2;

       // ================================================
       // MX ANALYSIS
       // ================================================
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       sheet.getCell(`B${currentRow}`).value = '📮 ANÁLISE DE MX RECORDS';
       sheet.getCell(`B${currentRow}`).font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
       sheet.getCell(`B${currentRow}`).fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.light }
       };
       currentRow++;

       // Agrupar por provedor de email
       const providerStats = {};
       results.forEach(r => {
           const provider = r.checks?.dns?.details?.emailProvider || 'Unknown';
           if (!providerStats[provider]) {
               providerStats[provider] = { count: 0, valid: 0, invalid: 0 };
           }
           providerStats[provider].count++;
           if (r.valid || r.score >= 45) {
               providerStats[provider].valid++;
           } else {
               providerStats[provider].invalid++;
           }
       });

       sheet.getCell(`B${currentRow}`).value = 'Provedor';
       sheet.getCell(`C${currentRow}`).value = 'Total';
       sheet.getCell(`D${currentRow}`).value = 'Válidos';
       sheet.getCell(`E${currentRow}`).value = 'Taxa';
       sheet.getRow(currentRow).font = { bold: true };
       currentRow++;

       Object.entries(providerStats)
           .sort((a, b) => b[1].count - a[1].count)
           .slice(0, 10)
           .forEach(([provider, stats]) => {
               const validRate = ((stats.valid / stats.count) * 100).toFixed(1);
               sheet.getCell(`B${currentRow}`).value = provider;
               sheet.getCell(`C${currentRow}`).value = stats.count;
               sheet.getCell(`D${currentRow}`).value = stats.valid;
               sheet.getCell(`E${currentRow}`).value = `${validRate}%`;

               if (parseFloat(validRate) >= 90) {
                   sheet.getCell(`E${currentRow}`).font = { color: { argb: this.colors.success } };
               } else if (parseFloat(validRate) < 70) {
                   sheet.getCell(`E${currentRow}`).font = { color: { argb: this.colors.danger } };
               }
               currentRow++;
           });

       return sheet;
   }

   // ================================================
   // ABA 10: EMAILS FUNCIONAIS/ROLE-BASED (NOVA)
   // ================================================
   async createRoleBasedEmailsSheet(results, technicalAnalysis) {
       const sheet = this.workbook.addWorksheet('👤 Emails Funcionais', {
           properties: { tabColor: { argb: this.colors.roleBased } }
       });

       sheet.columns = [
           { header: 'Email', key: 'email', width: 35 },
           { header: 'Categoria', key: 'category', width: 20 },
           { header: 'Padrão', key: 'pattern', width: 15 },
           { header: 'Risco', key: 'risk', width: 15 },
           { header: 'Recomendação', key: 'recommendation', width: 40 },
           { header: 'Score', key: 'score', width: 10 }
       ];

       // Header
       const headerRow = sheet.getRow(1);
       headerRow.font = { bold: true, color: { argb: this.colors.white } };
       headerRow.fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.roleBased }
       };
       headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
       headerRow.height = 25;

       // Adicionar emails role-based por categoria
       const categories = [
           { key: 'noreply', label: '🚫 Não Responder', color: this.colors.danger },
           { key: 'administrative', label: '👤 Administrativo', color: this.colors.warning },
           { key: 'support', label: '💬 Suporte', color: this.colors.info },
           { key: 'sales', label: '💼 Vendas', color: this.colors.success },
           { key: 'marketing', label: '📢 Marketing', color: this.colors.success },
           { key: 'technical', label: '⚙️ Técnico', color: this.colors.warning },
           { key: 'hr', label: '👥 RH', color: this.colors.info },
           { key: 'finance', label: '💰 Financeiro', color: this.colors.warning },
           { key: 'legal', label: '⚖️ Jurídico', color: this.colors.warning },
           { key: 'social', label: '📱 Redes Sociais', color: this.colors.info },
           { key: 'info', label: 'ℹ️ Informações', color: this.colors.info }
       ];

       let currentRow = 2;

       categories.forEach(category => {
           const emails = technicalAnalysis.roleBasedEmails[category.key] || [];

           if (emails.length > 0) {
               // Adicionar header da categoria
               sheet.mergeCells(`A${currentRow}:F${currentRow}`);
               const categoryHeader = sheet.getCell(`A${currentRow}`);
               categoryHeader.value = `${category.label} (${emails.length} emails)`;
               categoryHeader.font = { bold: true, color: { argb: this.colors.white } };
               categoryHeader.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: category.color }
               };
               currentRow++;

               // Adicionar emails da categoria
               emails.forEach(roleEmail => {
                   const result = results.find(r =>
                       (r.correctedEmail || r.email) === roleEmail.email
                   );

                   const row = sheet.addRow({
                       email: roleEmail.email,
                       category: this.translations.roleCategories[category.key] || category.key,
                       pattern: roleEmail.pattern,
                       risk: this.translateRisk(roleEmail.risk),
                       recommendation: roleEmail.recommendation,
                       score: result?.score || 0
                   });

                   // Colorir baseado no risco
                   if (roleEmail.risk === 'critical') {
                       row.fill = {
                           type: 'pattern',
                           pattern: 'solid',
                           fgColor: { argb: this.colors.dangerBg }
                       };
                   } else if (roleEmail.risk === 'high') {
                       row.fill = {
                           type: 'pattern',
                           pattern: 'solid',
                           fgColor: { argb: this.colors.warningBg }
                       };
                   }

                   currentRow++;
               });
               currentRow++;
           }
       });

       // Resumo
       const summaryRow = currentRow + 1;
       sheet.mergeCells(`A${summaryRow}:F${summaryRow}`);
       const summaryCell = sheet.getCell(`A${summaryRow}`);

       const totalRoleBased = Object.values(technicalAnalysis.roleBasedEmails)
           .reduce((sum, emails) => sum + emails.length, 0);

       summaryCell.value = `📊 RESUMO: ${totalRoleBased} emails funcionais detectados`;
       summaryCell.font = { size: 12, bold: true };
       summaryCell.fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.roleBasedBg }
       };

       return sheet;
   }

   // ================================================
   // ABA 11: ANÁLISE DE DOMÍNIOS (MELHORADA)
   // ================================================
   async createDomainAnalysisSheet(results, technicalAnalysis) {
       const sheet = this.workbook.addWorksheet('🌐 Análise de Domínios', {
           properties: { tabColor: { argb: this.colors.info } }
       });

       sheet.columns = [
           { header: 'Domínio', key: 'domain', width: 30 },
           { header: 'Total', key: 'total', width: 10 },
           { header: 'Válidos', key: 'valid', width: 10 },
           { header: 'Inválidos', key: 'invalid', width: 10 },
           { header: 'Corrigidos', key: 'corrected', width: 12 },
           { header: 'Score Médio', key: 'avgScore', width: 12 },
           { header: 'Catch-All', key: 'catchAll', width: 12 },
           { header: 'Spamtraps', key: 'spamtraps', width: 12 },
           { header: 'Role-Based', key: 'roleBased', width: 12 },
           { header: 'Status', key: 'status', width: 15 }
       ];

       // Header
       const headerRow = sheet.getRow(1);
       headerRow.font = { bold: true, color: { argb: this.colors.white } };
       headerRow.fill = {
           type: 'gradient',
           gradient: 'angle',
           degree: 90,
           stops: [
               { position: 0, color: { argb: this.colors.info } },
               { position: 1, color: { argb: this.colors.infoLight } }
           ]
       };
       headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
       headerRow.height = 25;

       // Adicionar dados dos domínios
       Object.entries(technicalAnalysis.domainStats)
           .sort((a, b) => b[1].total - a[1].total)
           .forEach(([domain, stats]) => {
               const avgScore = stats.scores.length > 0
                   ? (stats.scores.reduce((a, b) => a + b, 0) / stats.scores.length).toFixed(1)
                   : 0;

               const validRate = (stats.valid / stats.total) * 100;
               let status = '✅ OK';
               let statusColor = this.colors.success;

               if (stats.hasSpamtraps) {
                   status = '🚨 CRÍTICO';
                   statusColor = this.colors.danger;
               } else if (validRate < 70) {
                   status = '⚠️ PROBLEMÁTICO';
                   statusColor = this.colors.warning;
               } else if (stats.isCatchAll) {
                   status = '📬 CATCH-ALL';
                   statusColor = this.colors.info;
               }

               const row = sheet.addRow({
                   domain: domain,
                   total: stats.total,
                   valid: stats.valid,
                   invalid: stats.invalid,
                   corrected: stats.corrected,
                   avgScore: avgScore,
                   catchAll: stats.isCatchAll ? '✅' : '-----',
                   spamtraps: stats.hasSpamtraps ? '🚨' : '-----',
                   roleBased: stats.roleBasedCount || 0,
                   status: status
               });

               // Colorir linha baseado no status
               if (stats.hasSpamtraps) {
                   row.fill = {
                       type: 'pattern',
                       pattern: 'solid',
                       fgColor: { argb: this.colors.dangerBg }
                   };
               } else if (validRate < 70) {
                   row.fill = {
                       type: 'pattern',
                       pattern: 'solid',
                       fgColor: { argb: this.colors.warningBg }
                   };
               } else if (stats.isCatchAll) {
                   row.fill = {
                       type: 'pattern',
                       pattern: 'solid',
                       fgColor: { argb: this.colors.catchAllBg }
                   };
               }

               row.getCell('status').font = { color: { argb: statusColor }, bold: true };
           });

       // Adicionar filtros
       sheet.autoFilter = {
           from: 'A1',
           to: 'J' + (Object.keys(technicalAnalysis.domainStats).length + 1)
       };

       return sheet;
   }

   // ================================================
   // ABA 12: CORREÇÕES (MELHORADA)
   // ================================================
   async createCorrectionsSheet(results) {
       const sheet = this.workbook.addWorksheet('✏️ Correções', {
           properties: { tabColor: { argb: this.colors.correction } }
       });

       const correctedEmails = results.filter(r => this.wasEmailCorrected(r));

       if (correctedEmails.length === 0) {
           sheet.getCell('A1').value = '📝 Nenhuma correção automática foi aplicada';
           sheet.getCell('A1').font = { size: 14, italic: true, color: { argb: this.colors.gray } };
           return sheet;
       }

       sheet.columns = [
           { header: '#', key: 'index', width: 8 },
           { header: 'Email Original', key: 'original', width: 35 },
           { header: 'Email Corrigido', key: 'corrected', width: 35 },
           { header: 'Tipo de Correção', key: 'correctionType', width: 20 },
           { header: 'Confiança', key: 'confidence', width: 12 },
           { header: 'Válido Após?', key: 'validAfter', width: 12 },
           { header: 'Score Final', key: 'score', width: 12 },
           { header: 'Melhoria', key: 'improvement', width: 15 }
       ];

       // Header
       const headerRow = sheet.getRow(1);
       headerRow.font = { bold: true, color: { argb: this.colors.white } };
       headerRow.fill = {
           type: 'gradient',
           gradient: 'angle',
           degree: 90,
           stops: [
               { position: 0, color: { argb: this.colors.correction } },
               { position: 1, color: { argb: this.colors.primaryDark } }
           ]
       };
       headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
       headerRow.height = 25;

       // Adicionar correções
       correctedEmails.forEach((result, index) => {
           const correctionDetails = result.correctionDetails || {};
           const isValidAfter = result.valid || result.score >= 45;

           const row = sheet.addRow({
               index: index + 1,
               original: result.originalEmail || result.normalizedEmail || result.email,
               corrected: result.correctedEmail,
               correctionType: this.formatCorrectionType(correctionDetails.type),
               confidence: correctionDetails.confidence ?
                   `${(correctionDetails.confidence * 100).toFixed(0)}%` : '-----',
               validAfter: isValidAfter ? '✅ SIM' : '❌ NÃO',
               score: result.score || 0,
               improvement: isValidAfter ? '✅ SUCESSO' : '⚠️ REVISAR'
           });

           // Colorir baseado no sucesso
           if (isValidAfter) {
               row.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: this.colors.successBg }
               };
               row.getCell('validAfter').font = { color: { argb: this.colors.success }, bold: true };
               row.getCell('improvement').font = { color: { argb: this.colors.success }, bold: true };
           } else {
               row.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: this.colors.warningBg }
               };
               row.getCell('validAfter').font = { color: { argb: this.colors.danger }, bold: true };
               row.getCell('improvement').font = { color: { argb: this.colors.warning }, bold: true };
           }
       });

       // Estatísticas de correção
       const validAfterCorrection = correctedEmails.filter(r => r.valid || r.score >= 45).length;
       const successRate = ((validAfterCorrection / correctedEmails.length) * 100).toFixed(1);

       const statsRow = correctedEmails.length + 3;
       sheet.mergeCells(`A${statsRow}:H${statsRow}`);
       const statsCell = sheet.getCell(`A${statsRow}`);
       statsCell.value = `📊 ESTATÍSTICAS: ${correctedEmails.length} correções aplicadas | ` +
                        `${validAfterCorrection} válidos após correção | ` +
                        `Taxa de sucesso: ${successRate}%`;
       statsCell.font = { size: 12, bold: true };
       statsCell.fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.correctionBg }
       };
       statsCell.alignment = { horizontal: 'center', vertical: 'middle' };

       return sheet;
   }

   // ================================================
   // ABA 13: ESTATÍSTICAS (MELHORADA)
   // ================================================
   async createStatisticsSheet(stats, results) {
       const sheet = this.workbook.addWorksheet('📊 Estatísticas', {
           properties: { tabColor: { argb: this.colors.secondary } },
           views: [{ showGridLines: false }]
       });

       sheet.columns = [
           { width: 2 },
           { width: 35 },
           { width: 20 },
           { width: 20 },
           { width: 20 },
           { width: 2 }
       ];

       let currentRow = 2;

       // Header principal
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       const headerCell = sheet.getCell(`B${currentRow}`);
       headerCell.value = '📊 ANÁLISE ESTATÍSTICA COMPLETA';
       headerCell.font = { size: 20, bold: true, color: { argb: this.colors.white } };
       headerCell.fill = {
           type: 'gradient',
           gradient: 'angle',
           degree: 135,
           stops: [
               { position: 0, color: { argb: this.colors.secondary } },
               { position: 1, color: { argb: this.colors.primary } }
           ]
       };
       headerCell.alignment = { horizontal: 'center', vertical: 'middle' };
       sheet.getRow(currentRow).height = 40;
       currentRow += 2;

       // ================================================
       // DISTRIBUIÇÃO DE SCORES
       // ================================================
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       sheet.getCell(`B${currentRow}`).value = '📈 DISTRIBUIÇÃO DE PONTUAÇÕES';
       sheet.getCell(`B${currentRow}`).font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
       sheet.getCell(`B${currentRow}`).fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.light }
       };
       currentRow++;

       const scoreRanges = [
           { range: '90-100 (Excelente)', count: results.filter(r => r.score >= 90).length, color: this.colors.success },
           { range: '80-89 (Muito Bom)', count: results.filter(r => r.score >= 80 && r.score < 90).length, color: this.colors.successLight },
           { range: '70-79 (Bom)', count: results.filter(r => r.score >= 70 && r.score < 80).length, color: this.colors.info },
           { range: '60-69 (Regular)', count: results.filter(r => r.score >= 60 && r.score < 70).length, color: this.colors.infoLight },
           { range: '40-59 (Baixo)', count: results.filter(r => r.score >= 40 && r.score < 60).length, color: this.colors.warning },
           { range: '20-39 (Muito Baixo)', count: results.filter(r => r.score >= 20 && r.score < 40).length, color: this.colors.warningLight },
           { range: '0-19 (Crítico)', count: results.filter(r => r.score < 20).length, color: this.colors.danger }
       ];

       const maxCount = Math.max(...scoreRanges.map(r => r.count));

       scoreRanges.forEach(range => {
           sheet.getCell(`B${currentRow}`).value = range.range;
           sheet.getCell(`B${currentRow}`).font = { size: 10 };

           // Barra visual
           const barWidth = maxCount > 0 ? (range.count / maxCount) : 0;
           const barLength = Math.round(barWidth * 20);
           const bar = '█'.repeat(barLength) + '░'.repeat(20 - barLength);

           sheet.getCell(`C${currentRow}`).value = bar;
           sheet.getCell(`C${currentRow}`).font = { color: { argb: range.color }, name: 'Consolas' };

           sheet.getCell(`D${currentRow}`).value = range.count;
           sheet.getCell(`D${currentRow}`).font = { bold: true };

           const percentage = stats.total > 0 ? ((range.count / stats.total) * 100).toFixed(1) : '0';
           sheet.getCell(`E${currentRow}`).value = `${percentage}%`;

           currentRow++;
       });
       currentRow += 2;

       // ================================================
       // MÉTRICAS PRINCIPAIS
       // ================================================
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       sheet.getCell(`B${currentRow}`).value = '🎯 MÉTRICAS PRINCIPAIS';
       sheet.getCell(`B${currentRow}`).font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
       sheet.getCell(`B${currentRow}`).fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.light }
       };
       currentRow++;

       const metrics = [
           { label: 'Total de Emails', value: stats.total, icon: '📧' },
           { label: 'Emails Válidos', value: `${stats.valid} (${stats.validPercentage}%)`, icon: '✅' },
           { label: 'Emails Inválidos', value: `${stats.invalid} (${stats.invalidPercentage}%)`, icon: '❌' },
           { label: 'Emails Corrigidos', value: `${stats.corrected} (${stats.correctionPercentage}%)`, icon: '✏️' },
           { label: 'Score Médio', value: stats.avgScore, icon: '⭐' },
           { label: 'Taxa de Confiabilidade', value: `${stats.reliabilityRate}%`, icon: '🎯' }
       ];

       metrics.forEach(metric => {
           sheet.getCell(`B${currentRow}`).value = `${metric.icon} ${metric.label}`;
           sheet.getCell(`C${currentRow}`).value = metric.value;
           sheet.getCell(`C${currentRow}`).font = { bold: true, color: { argb: this.colors.primaryDark } };
           currentRow++;
       });
       currentRow += 2;

       // ================================================
       // TOP DOMÍNIOS
       // ================================================
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       sheet.getCell(`B${currentRow}`).value = '🌐 TOP 10 DOMÍNIOS';
       sheet.getCell(`B${currentRow}`).font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
       sheet.getCell(`B${currentRow}`).fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.light }
       };
       currentRow++;

       sheet.getCell(`B${currentRow}`).value = 'Domínio';
       sheet.getCell(`C${currentRow}`).value = 'Quantidade';
       sheet.getCell(`D${currentRow}`).value = 'Percentual';
       sheet.getRow(currentRow).font = { bold: true };
       currentRow++;

       stats.topDomains.forEach(([domain, count], index) => {
           const percentage = stats.total > 0 ? ((count / stats.total) * 100).toFixed(1) : '0';
           sheet.getCell(`B${currentRow}`).value = `${index + 1}. ${domain}`;
           sheet.getCell(`C${currentRow}`).value = count;
           sheet.getCell(`D${currentRow}`).value = `${percentage}%`;

           if (index < 3) {
               sheet.getRow(currentRow).font = { bold: true, color: { argb: this.colors.primary } };
           }
           currentRow++;
       });

       return sheet;
   }

   // ================================================
   // ABA 14: E-COMMERCE (MELHORADA)
   // ================================================
   async createEcommerceSheet(results) {
       const sheet = this.workbook.addWorksheet('💰 E-commerce', {
           properties: { tabColor: { argb: this.colors.success } }
       });

       sheet.columns = [
           { header: 'Email', key: 'email', width: 35 },
           { header: 'Score E-commerce', key: 'ecomScore', width: 18 },
           { header: 'Tipo de Comprador', key: 'buyerType', width: 30 },
           { header: 'Nível de Risco', key: 'riskLevel', width: 20 },
           { header: 'Fraude %', key: 'fraud', width: 12 },
           { header: 'Recomendação', key: 'recommendation', width: 30 }
       ];

       // Header
       const headerRow = sheet.getRow(1);
       headerRow.font = { bold: true, color: { argb: this.colors.white } };
       headerRow.fill = {
           type: 'gradient',
           gradient: 'angle',
           degree: 90,
           stops: [
               { position: 0, color: { argb: this.colors.success } },
               { position: 1, color: { argb: this.colors.successLight } }
           ]
       };
       headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
       headerRow.height = 25;

       // Adicionar dados
       const scoringData = results.filter(r => r.scoring || r.ecommerce);

       scoringData.forEach(result => {
           const scoring = result.scoring || result.ecommerce || {};
           const fraudProb = scoring.fraudProbability || 0;

           let recommendation = '✅ Aprovar';
           if (fraudProb > 70) recommendation = '🚫 Bloquear';
           else if (fraudProb > 50) recommendation = '⚠️ Revisar';
           else if (fraudProb > 30) recommendation = '👁️ Monitorar';

           const row = sheet.addRow({
               email: result.correctedEmail || result.email,
               ecomScore: scoring.finalScore || scoring.score || result.score || 0,
               buyerType: this.translations.buyerTypes[scoring.buyerType] || '-----',
               riskLevel: this.translations.riskLevels[scoring.riskLevel] || '-----',
               fraud: `${fraudProb.toFixed(0)}%`,
               recommendation: recommendation
           });

           // Colorir baseado no risco
           if (scoring.riskLevel === 'CRITICAL' || scoring.riskLevel === 'VERY_HIGH') {
               row.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: this.colors.dangerBg }
               };
           } else if (scoring.riskLevel === 'HIGH') {
               row.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: this.colors.warningBg }
               };
           } else if (scoring.buyerType === 'TRUSTED_BUYER') {
               row.fill = {
                   type: 'pattern',
                   pattern: 'solid',
                   fgColor: { argb: this.colors.successBg }
               };
           }
       });

       // Adicionar filtros
       sheet.autoFilter = {
           from: 'A1',
           to: 'F' + (scoringData.length + 1)
       };

       return sheet;
   }

   // ================================================
   // ABA 15: MÉTRICAS DE QUALIDADE (NOVA)
   // ================================================
   async createQualityMetricsSheet(results, stats) {
       const sheet = this.workbook.addWorksheet('🏆 Métricas de Qualidade', {
           properties: { tabColor: { argb: this.colors.primaryLight } },
           views: [{ showGridLines: false }]
       });

       sheet.columns = [
           { width: 2 },
           { width: 30 },
           { width: 25 },
           { width: 25 },
           { width: 25 },
           { width: 2 }
       ];

       let currentRow = 2;

       // Header
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       const headerCell = sheet.getCell(`B${currentRow}`);
       headerCell.value = '🏆 MÉTRICAS DE QUALIDADE DA LISTA';
       headerCell.font = { size: 18, bold: true, color: { argb: this.colors.white } };
       headerCell.fill = {
           type: 'gradient',
           gradient: 'angle',
           degree: 90,
           stops: [
               { position: 0, color: { argb: this.colors.primaryLight } },
               { position: 1, color: { argb: this.colors.primary } }
           ]
       };
       headerCell.alignment = { horizontal: 'center', vertical: 'middle' };
       sheet.getRow(currentRow).height = 40;
       currentRow += 2;

       // Score Cards de Qualidade
       const qualityMetrics = [
           {
               title: 'ÍNDICE DE QUALIDADE GERAL',
               value: this.calculateListScore(stats),
               max: 100,
               icon: '🎯',
               description: 'Score combinado de todos os fatores'
           },
           {
               title: 'TAXA DE ENTREGABILIDADE',
               value: Math.round((stats.valid / stats.total) * 100),
               max: 100,
               icon: '📬',
               description: 'Emails que chegarão ao destino'
           },
           {
               title: 'LIMPEZA DA LISTA',
               value: 100 - Math.round((results.filter(r =>
                   r.checks?.spamtrap?.isSpamtrap ||
                   r.checks?.bounce?.isPermanent
               ).length / stats.total) * 100),
               max: 100,
               icon: '🧹',
               description: 'Livre de spamtraps e hard bounces'
           },
           {
               title: 'CONFIABILIDADE TÉCNICA',
               value: Math.round((results.filter(r =>
                   r.checks?.rfc?.valid &&
                   r.checks?.dns?.valid
               ).length / stats.total) * 100),
               max: 100,
               icon: '⚙️',
               description: 'Conformidade com padrões técnicos'
           }
       ];

       // Renderizar métricas
       qualityMetrics.forEach((metric, index) => {
           const startRow = currentRow;

           // Título
           sheet.mergeCells(`B${currentRow}:E${currentRow}`);
           sheet.getCell(`B${currentRow}`).value = `${metric.icon} ${metric.title}`;
           sheet.getCell(`B${currentRow}`).font = { size: 12, bold: true };
           sheet.getCell(`B${currentRow}`).fill = {
               type: 'pattern',
               pattern: 'solid',
               fgColor: { argb: this.colors.light }
           };
           currentRow++;

           // Barra de progresso visual
           sheet.mergeCells(`B${currentRow}:D${currentRow}`);
           const progressBar = this.createProgressBar(metric.value, metric.max);
           sheet.getCell(`B${currentRow}`).value = progressBar;
           sheet.getCell(`B${currentRow}`).font = { name: 'Consolas', size: 14 };

           // Valor
           sheet.getCell(`E${currentRow}`).value = `${metric.value}/${metric.max}`;
           sheet.getCell(`E${currentRow}`).font = {
               size: 16,
               bold: true,
               color: { argb: this.getScoreColor(metric.value) }
           };
           sheet.getCell(`E${currentRow}`).alignment = { horizontal: 'center', vertical: 'middle' };
           currentRow++;

           // Descrição
           sheet.mergeCells(`B${currentRow}:E${currentRow}`);
           sheet.getCell(`B${currentRow}`).value = metric.description;
           sheet.getCell(`B${currentRow}`).font = { size: 10, italic: true, color: { argb: this.colors.gray } };
           currentRow += 2;
       });

       // Análise comparativa
       currentRow++;
       sheet.mergeCells(`B${currentRow}:E${currentRow}`);
       sheet.getCell(`B${currentRow}`).value = '📊 ANÁLISE COMPARATIVA';
       sheet.getCell(`B${currentRow}`).font = { size: 14, bold: true, color: { argb: this.colors.primaryDark } };
       sheet.getCell(`B${currentRow}`).fill = {
           type: 'pattern',
           pattern: 'solid',
           fgColor: { argb: this.colors.light }
       };
       currentRow += 2;

       const comparison = this.getListComparison(stats);
       comparison.forEach(comp => {
           sheet.mergeCells(`B${currentRow}:E${currentRow}`);
           sheet.getCell(`B${currentRow}`).value = `${comp.icon} ${comp.text}`;
           sheet.getCell(`B${currentRow}`).font = { size: 11, color: { argb: comp.color } };
           currentRow++;
       });

       return sheet;
   }

   // ================================================
   // MÉTODOS AUXILIARES EXPANDIDOS
   // ================================================

   wasEmailCorrected(result) {
       if (result.wasCorrected === true) {
           const current = (result.correctedEmail || result.email || '').toLowerCase().trim();
           const original = (result.originalEmail || result.normalizedEmail ||
                           result.originalBeforeParse || result.email || '').toLowerCase().trim();
           return current !== original && original !== '';
       }

       if (result.correctionDetails && result.correctionDetails.type) {
           const current = (result.correctedEmail || result.email || '').toLowerCase().trim();
           const original = (result.originalEmail || result.normalizedEmail ||
                           result.originalBeforeParse || result.email || '').toLowerCase().trim();
           return current !== original && original !== '';
       }

       if (result.correctedEmail) {
           const corrected = result.correctedEmail.toLowerCase().trim();
           const original = (result.email || '').toLowerCase().trim();
           return corrected !== original && original !== '';
       }

       return false;
   }

   calculateStatistics(results) {
       const total = results.length || 0;
       const validEmails = results.filter(r =>
           r.valid === true || r.score >= 45 || (this.wasEmailCorrected(r) && r.score >= 40)
       );

       const valid = validEmails.length;
       const invalid = total - valid;
       const corrected = results.filter(r => this.wasEmailCorrected(r)).length;

       let reliabilityRate = '0.00';
       if (total > 0) {
           const validPercentage = (valid / total) * 100;
           if (validPercentage >= 95) {
               reliabilityRate = validPercentage.toFixed(2);
           } else {
               const avgScore = results.reduce((sum, r) => sum + (r.score || 0), 0) / total;
               reliabilityRate = avgScore.toFixed(2);
           }
       }

       const avgScore = total > 0
           ? results.reduce((sum, r) => sum + (r.score || 0), 0) / total
           : 0;

       const buyerTypes = {};
       const riskLevels = {};

       results.forEach(r => {
           const buyerType = r.scoring?.buyerType || r.ecommerce?.buyerType || 'unknown';
           const translatedType = this.translations.buyerTypes[buyerType] || buyerType;
           buyerTypes[translatedType] = (buyerTypes[translatedType] || 0) + 1;

           const riskLevel = r.scoring?.riskLevel || r.ecommerce?.riskLevel || 'unknown';
           const translatedRisk = this.translations.riskLevels[riskLevel] || riskLevel;
           riskLevels[translatedRisk] = (riskLevels[translatedRisk] || 0) + 1;
       });

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
           highConfidenceCount: validEmails.length,
           buyerTypes,
           riskLevels,
           topDomains,
           timestamp: new Date().toISOString()
       };
   }

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
           const wasCorrected = this.wasEmailCorrected(r);

           const emailDetail = {
               email: email,
               score: r.score || 0,
               valid: r.valid,
               reason: '',
               action: '',
               originalLine: r.originalLine || index + 2,
               buyerType: this.translations.buyerTypes[r.scoring?.buyerType || r.ecommerce?.buyerType || 'unknown'],
               riskLevel: this.translations.riskLevels[r.scoring?.riskLevel || r.ecommerce?.riskLevel || 'unknown'],
               wasCorrected: wasCorrected
           };

           // Classificar emails por qualidade
           if (r.score < 30 || (!r.valid && r.score < 40)) {
               emailDetail.reason = `Score muito baixo (${r.score}). Email inválido ou inexistente.`;
               emailDetail.action = 'REMOVER IMEDIATAMENTE';
               analysis.invalidEmails.push(emailDetail);
           } else if (r.score >= 30 && r.score < 60) {
               if (wasCorrected) {
                   emailDetail.reason = `Email corrigido com score ${r.score}. Verificar se correção está correta.`;
                   emailDetail.action = 'VERIFICAR CORREÇÃO';
               } else {
                   emailDetail.reason = `Score baixo (${r.score}). Possível problema no email.`;
                   emailDetail.action = 'REVISAR MANUALMENTE';
               }
               analysis.suspiciousEmails.push(emailDetail);
           } else if (r.score >= 60) {
               emailDetail.reason = 'Email de boa qualidade';
               emailDetail.action = 'APROVADO PARA USO';
               analysis.highQualityEmails.push(emailDetail);
           }

           // Emails corrigidos
           if (wasCorrected) {
               const original = r.originalEmail || r.normalizedEmail ||
                              r.originalBeforeParse || r.email;
               analysis.correctedEmails.push({
                   original: original,
                   corrected: email,
                   score: r.score,
                   valid: r.valid || r.score >= 45,
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
               if (!r.valid && r.score < 45) {
                   domainStats[domain].problems++;
               }
           }

           // Contar duplicados
           emailCounts[email] = (emailCounts[email] || 0) + 1;
       });

       // Domínios problemáticos
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

       // Emails duplicados
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
   // MÉTODOS DE SUPORTE PARA VISUAL
   // ================================================

   createModernBorder(color) {
       return {
           top: { style: 'thin', color: { argb: color } },
           left: { style: 'thin', color: { argb: color } },
           bottom: { style: 'thin', color: { argb: color } },
           right: { style: 'thin', color: { argb: color } }
       };
   }

   createProgressBar(value, max) {
       const percentage = (value / max) * 100;
       const filled = Math.round(percentage / 5);
       const empty = 20 - filled;

       let bar = '';
       if (percentage >= 80) {
           bar = '🟩'.repeat(filled) + '⬜'.repeat(empty);
       } else if (percentage >= 60) {
           bar = '🟨'.repeat(filled) + '⬜'.repeat(empty);
       } else {
           bar = '🟥'.repeat(filled) + '⬜'.repeat(empty);
       }

       return bar;
   }

   getScoreColor(score) {
       if (score >= 80) return this.colors.success;
       if (score >= 60) return this.colors.info;
       if (score >= 40) return this.colors.warning;
       return this.colors.danger;
   }

   calculateListScore(stats) {
       const validWeight = 0.4;
       const avgScoreWeight = 0.3;
       const reliabilityWeight = 0.3;

       const validScore = parseFloat(stats.validPercentage);
       const avgScore = parseFloat(stats.avgScore);
       const reliabilityScore = parseFloat(stats.reliabilityRate);

       const finalScore = (validScore * validWeight) +
                         (avgScore * avgScoreWeight) +
                         (reliabilityScore * reliabilityWeight);

       return Math.round(finalScore);
   }

   getListClassification(score, stats) {
       if (score >= 90) {
           return {
               label: '🏆 LISTA PREMIUM - QUALIDADE EXCEPCIONAL',
               description: `Parabéns! Sua lista está entre as melhores. Com ${stats.validPercentage}% de emails válidos e score médio de ${stats.avgScore}, você tem uma base de altíssima qualidade para suas campanhas.`,
               color: this.colors.success,
               bgColor: this.colors.successBg
           };
       } else if (score >= 80) {
           return {
               label: '⭐ LISTA EXCELENTE - PRONTA PARA USO',
               description: `Excelente qualidade! ${stats.validPercentage}% dos emails são válidos. Pequenos ajustes podem elevar ainda mais a performance.`,
               color: this.colors.successLight,
               bgColor: this.colors.successBg
           };
       } else if (score >= 70) {
           return {
               label: '✅ LISTA BOA - NECESSITA PEQUENOS AJUSTES',
               description: `Boa lista com ${stats.validPercentage}% de validade. Remova os emails problemáticos identificados para melhorar os resultados.`,
               color: this.colors.info,
               bgColor: this.colors.infoBg
           };
       } else if (score >= 60) {
           return {
               label: '⚠️ LISTA REGULAR - LIMPEZA RECOMENDADA',
               description: `Lista com qualidade regular. ${stats.invalidPercentage}% dos emails são inválidos. Uma limpeza cuidadosa melhorará significativamente seus resultados.`,
               color: this.colors.warning,
               bgColor: this.colors.warningBg
           };
       } else {
           return {
               label: '🚫 LISTA PROBLEMÁTICA - LIMPEZA URGENTE',
               description: `Atenção! Apenas ${stats.validPercentage}% dos emails são válidos. É essencial fazer uma limpeza profunda antes de usar esta lista.`,
               color: this.colors.danger,
               bgColor: this.colors.dangerBg
           };
       }
   }

   generateKeyFindings(stats, analysis) {
       const findings = [];

       if (stats.corrected > 0) {
           findings.push({
               icon: '✏️',
               text: `${stats.corrected} emails foram corrigidos automaticamente, melhorando a taxa de entrega`,
               color: this.colors.correction
           });
       }

       if (stats.validPercentage >= 95) {
           findings.push({
               icon: '🎯',
               text: `Taxa de validade excepcional: ${stats.validPercentage}% dos emails são válidos`,
               color: this.colors.success
           });
       } else if (stats.validPercentage < 70) {
           findings.push({
               icon: '⚠️',
               text: `Taxa de validade baixa: apenas ${stats.validPercentage}% são válidos`,
               color: this.colors.danger
           });
       }

       if (analysis.duplicateEmails.length > 10) {
           findings.push({
               icon: '🔄',
               text: `${analysis.duplicateEmails.length} emails duplicados encontrados - remover para otimizar`,
               color: this.colors.warning
           });
       }

       if (analysis.problematicDomains.length > 0) {
           findings.push({
               icon: '🌐',
               text: `${analysis.problematicDomains.length} domínios problemáticos identificados`,
               color: this.colors.warning
           });
       }

       const avgScore = parseFloat(stats.avgScore);
       if (avgScore >= 70) {
           findings.push({
               icon: '⭐',
               text: `Score médio alto (${stats.avgScore}) indica boa qualidade geral`,
               color: this.colors.info
           });
       }

       return findings;
   }

   generateActionPlan(stats, analysis, technicalAnalysis) {
       const actions = [];

       // Ações críticas
       if (technicalAnalysis.confirmedSpamtraps.length > 0) {
           actions.push({
               priority: 'CRÍTICA',
               title: 'Remover Spamtraps Imediatamente',
               description: `${technicalAnalysis.confirmedSpamtraps.length} spamtraps confirmados devem ser removidos imediatamente para evitar blacklist`,
               impact: `${technicalAnalysis.confirmedSpamtraps.length} emails`,
               icon: '🚨'
           });
       }

       if (technicalAnalysis.hardBounces.length > 0) {
           actions.push({
               priority: 'CRÍTICA',
               title: 'Remover Hard Bounces',
               description: `${technicalAnalysis.hardBounces.length} emails com hard bounce são permanentemente inválidos`,
               impact: `${technicalAnalysis.hardBounces.length} emails`,
               icon: '📭'
           });
       }

       // Ações de alta prioridade
       if (analysis.invalidEmails.length > 20) {
           actions.push({
               priority: 'ALTA',
               title: 'Limpar Emails Inválidos',
               description: `Remover ${analysis.invalidEmails.length} emails com score < 30 para melhorar entregabilidade`,
               impact: `${analysis.invalidEmails.length} emails`,
               icon: '❌'
           });
       }

       if (stats.corrected > 10) {
           actions.push({
               priority: 'ALTA',
               title: 'Verificar Correções Automáticas',
               description: `${stats.corrected} emails foram corrigidos. Revisar para garantir precisão`,
               impact: `${stats.corrected} correções`,
               icon: '✏️'
           });
       }

       // Ações de média prioridade
       if (technicalAnalysis.catchAllDomains.length > 0) {
           actions.push({
               priority: 'MÉDIA',
               title: 'Revisar Domínios Catch-All',
               description: `${technicalAnalysis.catchAllDomains.length} domínios aceitam todos os emails. Considerar verificação adicional`,
               impact: `${technicalAnalysis.catchAllDomains.length} domínios`,
               icon: '📬'
           });
       }

       const roleBasedCount = Object.values(technicalAnalysis.roleBasedEmails)
           .reduce((sum, emails) => sum + emails.length, 0);
       if (roleBasedCount > 20) {
           actions.push({
               priority: 'MÉDIA',
               title: 'Segmentar Emails Funcionais',
               description: `${roleBasedCount} emails funcionais detectados. Criar segmentação específica`,
               impact: `${roleBasedCount} emails`,
               icon: '👤'
           });
       }

       // Ações informativas
       if (analysis.highQualityEmails.length > 0) {
           actions.push({
               priority: 'INFO',
               title: 'Usar Lista Limpa',
               description: `${analysis.highQualityEmails.length} emails de alta qualidade prontos para campanhas`,
               impact: `${analysis.highQualityEmails.length} emails aprovados`,
               icon: '✅'
           });
       }

       return actions;
   }

   getPriorityConfig(priority) {
       const configs = {
           'CRÍTICA': { icon: '🚨', color: this.colors.danger },
           'ALTA': { icon: '⚠️', color: this.colors.warning },
           'MÉDIA': { icon: '📋', color: this.colors.info },
           'BAIXA': { icon: 'ℹ️', color: this.colors.primaryLight },
           'INFO': { icon: '💡', color: this.colors.success }
       };
       return configs[priority] || configs.INFO;
   }

   calculateExpectedImpact(stats, analysis, technicalAnalysis) {
       const impact = [];

       const totalToRemove = analysis.invalidEmails.length +
                            technicalAnalysis.confirmedSpamtraps.length +
                            technicalAnalysis.hardBounces.length;

       if (totalToRemove > 0) {
           const newTotal = stats.total - totalToRemove;
           const newValidRate = ((stats.valid / newTotal) * 100).toFixed(1);

           impact.push({
               icon: '📈',
               text: `Após limpeza: taxa de validade aumentará para ~${newValidRate}%`,
               color: this.colors.success
           });
       }

       if (stats.corrected > 0) {
           const correctionSuccess = analysis.correctedEmails.filter(e => e.valid).length;
           const successRate = ((correctionSuccess / stats.corrected) * 100).toFixed(0);

           impact.push({
               icon: '✏️',
               text: `${successRate}% das correções resultaram em emails válidos`,
               color: this.colors.correction
           });
       }

       impact.push({
           icon: '🎯',
           text: `Lista final terá aproximadamente ${stats.valid} emails de qualidade`,
           color: this.colors.info
       });

       return impact;
   }

   translateRisk(risk) {
       const risks = {
           'critical': '🔴 Crítico',
           'high': '🟠 Alto',
           'medium': '🟡 Médio',
           'low': '🟢 Baixo',
           'none': '✅ Nenhum'
       };
       return risks[risk] || risk;
   }

   getEmailQuality(score) {
       if (score >= 90) return 'EXCELLENT';
       if (score >= 80) return 'VERY_GOOD';
       if (score >= 70) return 'GOOD';
       if (score >= 60) return 'FAIR';
       if (score >= 40) return 'POOR';
       if (score >= 20) return 'VERY_POOR';
       return 'INVALID';
   }

   getEmailQualityLabel(score) {
       if (score >= 90) return '⭐⭐⭐⭐⭐ Excelente';
       if (score >= 80) return '⭐⭐⭐⭐ Muito Bom';
       if (score >= 70) return '⭐⭐⭐ Bom';
       if (score >= 60) return '⭐⭐ Aceitável';
       return '⭐ Baixo';
   }

   formatCorrectionType(type) {
       const types = {
           'known_typo': 'Erro de Digitação Conhecido',
           'similarity': 'Correção por Similaridade',
           'domain_typo': 'Erro no Domínio',
           'tld_correction': 'Correção de TLD',
           'common_mistake': 'Erro Comum',
           'unknown': 'Correção Automática'
       };
       return types[type] || type || 'Correção Aplicada';
   }

   getListComparison(stats) {
       const comparison = [];
       const avgScore = parseFloat(stats.avgScore);
       const validRate = parseFloat(stats.validPercentage);

       if (validRate >= 95) {
           comparison.push({
               icon: '🏆',
               text: 'Sua lista está no TOP 5% de qualidade do mercado',
               color: this.colors.success
           });
       } else if (validRate >= 85) {
           comparison.push({
               icon: '⭐',
               text: 'Sua lista está acima da média do mercado (75%)',
               color: this.colors.info
           });
       } else if (validRate >= 70) {
           comparison.push({
               icon: '📊',
               text: 'Sua lista está próxima da média do mercado',
               color: this.colors.warning
           });
       } else {
           comparison.push({
               icon: '⚠️',
               text: 'Sua lista está abaixo da média do mercado',
               color: this.colors.danger
           });
       }

       if (stats.corrected > stats.total * 0.05) {
           comparison.push({
               icon: '✏️',
               text: `${stats.correctionPercentage}% de correções aplicadas (acima da média de 2%)`,
               color: this.colors.correction
           });
       }

       return comparison;
   }

   generateTextSummary(stats, analysis, technicalAnalysis) {
       const summary = [];

       summary.push(`📊 RESUMO DA VALIDAÇÃO`);
       summary.push(`========================`);
       summary.push(`Total de emails: ${stats.total}`);
       summary.push(`Emails válidos: ${stats.valid} (${stats.validPercentage}%)`);
       summary.push(`Emails inválidos: ${stats.invalid} (${stats.invalidPercentage}%)`);
       summary.push(`Emails corrigidos: ${stats.corrected}`);
       summary.push(`Score médio: ${stats.avgScore}`);
       summary.push(``);

       if (technicalAnalysis.confirmedSpamtraps.length > 0) {
           summary.push(`⚠️ ALERTA: ${technicalAnalysis.confirmedSpamtraps.length} spamtraps detectados!`);
       }

       if (technicalAnalysis.hardBounces.length > 0) {
           summary.push(`⚠️ ${technicalAnalysis.hardBounces.length} hard bounces encontrados`);
       }

       summary.push(``);
       summary.push(`✅ AÇÕES RECOMENDADAS:`);

       if (analysis.invalidEmails.length > 0) {
           summary.push(`- Remover ${analysis.invalidEmails.length} emails inválidos`);
       }

       if (stats.corrected > 0) {
           summary.push(`- Verificar ${stats.corrected} correções aplicadas`);
       }

       summary.push(`- Usar ${analysis.highQualityEmails.length} emails da lista limpa`);

       return summary.join('\n');
   }

   translate(value, category) {
       if (!value) return 'Não Classificado';
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

   applyStyleToSheet(sheet) {
       sheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
           row.eachCell({ includeEmpty: false }, (cell) => {
               if (!cell.border) {
                   cell.border = {
                       top: { style: 'thin', color: { argb: this.colors.borderColor } },
                       left: { style: 'thin', color: { argb: this.colors.borderColor } },
                       bottom: { style: 'thin', color: { argb: this.colors.borderColor } },
                       right: { style: 'thin', color: { argb: this.colors.borderColor } }
                   };
               }
           });
       });
   }
}

module.exports = ExcelReportGenerator;
