// ================================================
// Report Email Service - Versão Simplificada
// ================================================

const ExcelReportGenerator = require('./ExcelReportGenerator');
const fs = require('fs');
const path = require('path');

class ReportEmailService {
    constructor() {
        this.reportGenerator = new ExcelReportGenerator();
        // EmailService será carregado dinamicamente se existir
        try {
            const EmailService = require('../emailService');
            this.emailService = new EmailService();
        } catch (e) {
            console.log('EmailService não encontrado - relatórios serão salvos localmente');
            this.emailService = null;
        }
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

            console.log('emailService: ', this.emailService);
            console.log('recipientEmail: ', recipientEmail);


            // Se EmailService existir, enviar email
            if (this.emailService && recipientEmail) {
                console.log('📧 Enviando relatório por email...');

                const reportData = {
                    filename: reportResult.filename,
                    stats: reportResult.stats
                };

                const emailResult = await this.emailService.sendValidationReport(
                    recipientEmail,
                    reportData,
                    reportResult.filepath,
                    userInfo
                );

                if (emailResult.success) {
                    console.log('✅ Relatório enviado com sucesso!');
                }

                return {
                    success: emailResult.success,
                    filepath: reportResult.filepath,
                    filename: reportResult.filename,
                    stats: reportResult.stats
                };
            } else {
                console.log('📁 Relatório salvo localmente:', reportResult.filepath);
                return reportResult;
            }

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
