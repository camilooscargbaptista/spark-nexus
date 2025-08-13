// ================================================
// Report Email Service - Versão Completa com Suporte a Correções
// ================================================

const ExcelReportGenerator = require('./ExcelReportGenerator');
const fs = require('fs').promises;
const path = require('path');

class ReportEmailService {
    constructor() {
        this.reportGenerator = new ExcelReportGenerator();

        // EmailService será carregado dinamicamente se existir
        try {
            const EmailService = require('../emailService');
            this.emailService = new EmailService();
            console.log('✅ EmailService carregado com sucesso');
        } catch (e) {
            console.log('⚠️ EmailService não encontrado - relatórios serão salvos localmente');
            this.emailService = null;
        }

        // Configurações de relatório
        this.config = {
            outputDir: path.join(__dirname, '../../reports'),
            tempDir: path.join(__dirname, '../../temp'),
            maxEmailsInSummary: 10,
            enableDetailedStats: true
        };

        // Estatísticas internas
        this.stats = {
            reportsGenerated: 0,
            emailsSent: 0,
            errors: 0
        };
    }

    /**
     * Gera e envia relatório completo de validação
     */
    async generateAndSendReport(validationResults, recipientEmail, userInfo = {}) {
        try {
            console.log('📊 Iniciando geração de relatório...');
            console.log(`   Total de emails: ${validationResults.length}`);
            console.log(`   Destinatário: ${recipientEmail}`);

            // Validar entrada
            if (!validationResults || !Array.isArray(validationResults)) {
                throw new Error('Resultados de validação inválidos');
            }

            // Processar dados antes de gerar relatório
            const processedResults = this.preprocessResults(validationResults);

            // Gerar relatório Excel
            const reportResult = await this.reportGenerator.generateReport(processedResults, {
                outputDir: this.config.outputDir,
                filename: this.generateFilename(userInfo)
            });

            if (!reportResult.success) {
                throw new Error('Falha ao gerar relatório Excel');
            }

            this.stats.reportsGenerated++;
            console.log(`✅ Relatório gerado: ${reportResult.filename}`);

            // Preparar estatísticas para o email
            const emailStats = this.prepareEmailStats(processedResults, reportResult.stats);

            // Se EmailService existir e recipientEmail for fornecido, enviar email
            if (this.emailService && recipientEmail) {
                console.log('📧 Preparando envio por email...');

                const emailResult = await this.sendReportEmail(
                    recipientEmail,
                    reportResult,
                    emailStats,
                    userInfo
                );

                if (emailResult.success) {
                    this.stats.emailsSent++;
                    console.log('✅ Relatório enviado por email com sucesso!');
                } else {
                    console.warn('⚠️ Falha ao enviar email:', emailResult.error);
                }

                return {
                    success: true,
                    filepath: reportResult.filepath,
                    filename: reportResult.filename,
                    stats: emailStats,
                    emailSent: emailResult.success,
                    emailError: emailResult.error,
                    recipient: recipientEmail
                };
            } else {
                console.log('📁 Relatório salvo localmente (email não configurado ou destinatário não fornecido)');

                return {
                    success: true,
                    filepath: reportResult.filepath,
                    filename: reportResult.filename,
                    stats: emailStats,
                    emailSent: false,
                    message: 'Relatório gerado localmente'
                };
            }

        } catch (error) {
            this.stats.errors++;
            console.error('❌ Erro ao gerar/enviar relatório:', error);

            return {
                success: false,
                error: error.message,
                details: error.stack
            };
        }
    }

    /**
     * Pré-processa os resultados de validação
     */
    preprocessResults(results) {
        return results.map((result, index) => {
            // Garantir que todos os campos necessários existam
            const processed = {
                ...result,
                // Campos básicos
                email: result.email || result.correctedEmail || '',
                valid: result.valid || false,
                score: result.score || 0,

                // Informações de correção
                wasCorrected: result.wasCorrected || result.correctedDuringParse || false,
                correctedEmail: result.correctedEmail || result.email || '',
                originalEmail: result.originalEmail || result.originalBeforeParse || result.normalizedEmail || '',
                correctionDetails: result.correctionDetails || result.correctionAppliedDuringParse || null,

                // Informações de duplicados
                isDuplicate: result.isDuplicate || false,
                duplicateIndex: result.duplicateIndex || 0,
                duplicateCount: result.duplicateCount || 0,
                originalLine: result.originalLine || (index + 2),

                // Scoring e E-commerce
                scoring: result.scoring || {},
                ecommerce: result.ecommerce || {},

                // Recomendações
                recommendations: this.normalizeRecommendations(result)
            };

            // Garantir que scoring tenha campos necessários
            if (!processed.scoring.buyerType && processed.ecommerce.buyerType) {
                processed.scoring.buyerType = processed.ecommerce.buyerType;
            }
            if (!processed.scoring.riskLevel && processed.ecommerce.riskLevel) {
                processed.scoring.riskLevel = processed.ecommerce.riskLevel;
            }
            if (!processed.scoring.confidence && processed.ecommerce.confidence) {
                processed.scoring.confidence = processed.ecommerce.confidence;
            }
            if (!processed.scoring.fraudProbability && processed.ecommerce.fraudProbability) {
                processed.scoring.fraudProbability = processed.ecommerce.fraudProbability;
            }

            return processed;
        });
    }

    /**
     * Normaliza recomendações para formato consistente
     */
    normalizeRecommendations(result) {
        const recommendations = [];

        // Coletar recomendações de diferentes fontes
        const sources = [
            result.scoring?.recommendations,
            result.ecommerce?.recommendations,
            result.recommendations
        ];

        sources.forEach(source => {
            if (source && Array.isArray(source)) {
                source.forEach(rec => {
                    if (typeof rec === 'string') {
                        recommendations.push({
                            action: 'INFO',
                            message: rec,
                            priority: 'medium'
                        });
                    } else if (rec && typeof rec === 'object') {
                        recommendations.push({
                            action: rec.action || 'INFO',
                            message: rec.message || rec.text || '',
                            priority: rec.priority || 'medium'
                        });
                    }
                });
            }
        });

        // Adicionar recomendação especial para emails corrigidos
        if (result.wasCorrected || result.correctedDuringParse) {
            recommendations.unshift({
                action: 'CORRECTION_NOTICE',
                message: `Email corrigido automaticamente de "${result.originalEmail || 'original'}" para "${result.correctedEmail || result.email}"`,
                priority: 'info'
            });
        }

        // Remover duplicatas
        const uniqueRecommendations = [];
        const seen = new Set();

        recommendations.forEach(rec => {
            const key = `${rec.action}_${rec.message}`;
            if (!seen.has(key)) {
                seen.add(key);
                uniqueRecommendations.push(rec);
            }
        });

        return uniqueRecommendations;
    }

    /**
     * Prepara estatísticas para o email
     */
    prepareEmailStats(results, reportStats) {
        const stats = {
            ...reportStats,
            // Estatísticas adicionais
            highConfidenceEmails: results.filter(r => r.score >= 80).length,
            mediumConfidenceEmails: results.filter(r => r.score >= 60 && r.score < 80).length,
            lowConfidenceEmails: results.filter(r => r.score < 60).length,

            // Estatísticas de correção
            correctedEmails: results.filter(r => r.wasCorrected || r.correctedDuringParse).length,
            correctedValidEmails: results.filter(r => (r.wasCorrected || r.correctedDuringParse) && r.valid).length,
            correctedInvalidEmails: results.filter(r => (r.wasCorrected || r.correctedDuringParse) && !r.valid).length,

            // Estatísticas de duplicados
            duplicatedEmails: results.filter(r => r.isDuplicate).length,
            uniqueEmails: results.filter(r => !r.isDuplicate).length,

            // Top problemas
            topIssues: this.identifyTopIssues(results),

            // Recomendação geral
            overallRecommendation: this.generateOverallRecommendation(reportStats)
        };

        return stats;
    }

    /**
     * Identifica os principais problemas na lista
     */
    identifyTopIssues(results) {
        const issues = {
            'Emails inválidos': results.filter(r => !r.valid).length,
            'Emails corrigidos': results.filter(r => r.wasCorrected || r.correctedDuringParse).length,
            'Emails duplicados': results.filter(r => r.isDuplicate).length,
            'Alto risco de fraude': results.filter(r =>
                r.scoring?.riskLevel === 'HIGH' ||
                r.scoring?.riskLevel === 'VERY_HIGH'
            ).length,
            'Domínios bloqueados': results.filter(r =>
                r.scoring?.buyerType === 'BLOCKED'
            ).length,
            'Baixa pontuação (<50)': results.filter(r => r.score < 50).length
        };

        // Retornar top 3 problemas
        return Object.entries(issues)
            .filter(([, count]) => count > 0)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 3)
            .map(([issue, count]) => ({
                issue,
                count,
                percentage: ((count / results.length) * 100).toFixed(1)
            }));
    }

    /**
     * Gera recomendação geral baseada nas estatísticas
     */
    generateOverallRecommendation(stats) {
        const score = parseFloat(stats.avgScore);
        const correctionRate = parseFloat(stats.correctionPercentage || 0);

        let recommendation = '';

        // Adicionar nota sobre correções se houver
        if (correctionRate > 10) {
            recommendation += `🔧 ${correctionRate}% dos emails foram corrigidos automaticamente. `;
        }

        // Recomendação baseada no score
        if (score >= 80) {
            recommendation += '✅ Lista de excelente qualidade! Pronta para uso em campanhas.';
        } else if (score >= 70) {
            recommendation += '👍 Lista boa, mas recomendamos remover emails inválidos antes do uso.';
        } else if (score >= 60) {
            recommendation += '⚠️ Lista regular - necessita limpeza antes de campanhas importantes.';
        } else if (score >= 50) {
            recommendation += '⛔ Lista problemática - limpeza essencial antes de qualquer uso.';
        } else {
            recommendation += '❌ Lista de baixa qualidade - considere reconstruir sua base de dados.';
        }

        return recommendation;
    }

    /**
     * Envia o relatório por email
     */
    async sendReportEmail(recipientEmail, reportResult, stats, userInfo) {
        try {
            // Preparar dados do relatório para o email
            const reportData = {
                filename: reportResult.filename,
                stats: stats,
                generatedAt: new Date().toISOString()
            };

            // Verificar se o arquivo existe
            try {
                await fs.access(reportResult.filepath);
            } catch (error) {
                console.error('Arquivo de relatório não encontrado:', reportResult.filepath);
                return { success: false, error: 'Arquivo de relatório não encontrado' };
            }

            // Enviar email usando EmailService
            const emailResult = await this.emailService.sendValidationReport(
                recipientEmail,
                reportData,
                reportResult.filepath,
                userInfo
            );

            return emailResult;

        } catch (error) {
            console.error('Erro ao enviar email:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    /**
     * Gera nome de arquivo único
     */
    generateFilename(userInfo) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
        const company = userInfo.company ?
            userInfo.company.replace(/[^a-zA-Z0-9]/g, '_').toLowerCase() :
            'report';

        return `validation_${company}_${timestamp}.xlsx`;
    }

    /**
     * Obtém estatísticas do serviço
     */
    getServiceStats() {
        return {
            ...this.stats,
            uptime: process.uptime(),
            memoryUsage: process.memoryUsage(),
            config: this.config
        };
    }

    /**
     * Limpa relatórios antigos
     */
    async cleanupOldReports(daysToKeep = 30) {
        try {
            const files = await fs.readdir(this.config.outputDir);
            const now = Date.now();
            const maxAge = daysToKeep * 24 * 60 * 60 * 1000;
            let deleted = 0;

            for (const file of files) {
                if (file.endsWith('.xlsx')) {
                    const filepath = path.join(this.config.outputDir, file);
                    const stats = await fs.stat(filepath);

                    if (now - stats.mtimeMs > maxAge) {
                        await fs.unlink(filepath);
                        deleted++;
                        console.log(`🗑️ Relatório antigo removido: ${file}`);
                    }
                }
            }

            console.log(`✅ Limpeza concluída: ${deleted} relatórios removidos`);
            return { success: true, deleted };

        } catch (error) {
            console.error('Erro na limpeza de relatórios:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Gera relatório simplificado (JSON)
     */
    async generateJSONReport(validationResults, outputPath = null) {
        try {
            const processedResults = this.preprocessResults(validationResults);
            const stats = this.prepareEmailStats(processedResults, {});

            const jsonReport = {
                metadata: {
                    generatedAt: new Date().toISOString(),
                    totalEmails: processedResults.length,
                    version: '2.0'
                },
                summary: stats,
                results: processedResults.map(r => ({
                    email: r.email,
                    valid: r.valid,
                    score: r.score,
                    wasCorrected: r.wasCorrected,
                    originalEmail: r.wasCorrected ? r.originalEmail : undefined,
                    buyerType: r.scoring?.buyerType,
                    riskLevel: r.scoring?.riskLevel,
                    recommendations: r.recommendations
                }))
            };

            if (outputPath) {
                await fs.writeFile(
                    outputPath,
                    JSON.stringify(jsonReport, null, 2)
                );
                console.log(`✅ Relatório JSON salvo: ${outputPath}`);
            }

            return jsonReport;

        } catch (error) {
            console.error('Erro ao gerar relatório JSON:', error);
            throw error;
        }
    }
}

module.exports = ReportEmailService;
