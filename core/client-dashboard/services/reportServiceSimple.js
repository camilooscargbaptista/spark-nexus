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
