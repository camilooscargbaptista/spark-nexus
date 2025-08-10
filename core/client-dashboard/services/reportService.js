// ================================================
// Report Service - Geração de Relatórios Excel
// ================================================

const ExcelJS = require('exceljs');
const fs = require('fs').promises;
const path = require('path');
const { ChartJSNodeCanvas } = require('chartjs-node-canvas');

class ReportService {
    constructor() {
        this.chartRenderer = new ChartJSNodeCanvas({ 
            width: 800, 
            height: 400,
            backgroundColour: 'white'
        });
        
        // Diretório para relatórios temporários
        this.reportsDir = path.join(__dirname, '../reports');
        this.ensureReportsDir();
    }

    async ensureReportsDir() {
        try {
            await fs.mkdir(this.reportsDir, { recursive: true });
        } catch (error) {
            console.error('Erro ao criar diretório de relatórios:', error);
        }
    }

    // ================================================
    // Método principal para gerar relatório
    // ================================================
    async generateValidationReport(validationResults, userInfo = {}) {
        const workbook = new ExcelJS.Workbook();
        
        // Metadados do arquivo
        workbook.creator = 'Spark Nexus';
        workbook.lastModifiedBy = 'Spark Nexus System';
        workbook.created = new Date();
        workbook.modified = new Date();
        workbook.properties.date1904 = true;
        
        // Adicionar abas
        await this.addSummarySheet(workbook, validationResults, userInfo);
        await this.addDetailedSheet(workbook, validationResults);
        await this.addStatisticsSheet(workbook, validationResults);
        await this.addDomainAnalysisSheet(workbook, validationResults);
        await this.addRecommendationsSheet(workbook, validationResults);
        
        // Salvar arquivo
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const filename = `validation_report_${timestamp}.xlsx`;
        const filepath = path.join(this.reportsDir, filename);
        
        await workbook.xlsx.writeFile(filepath);
        
        // Gerar gráficos como imagens
        const charts = await this.generateCharts(validationResults);
        
        return {
            filepath,
            filename,
            charts,
            stats: this.calculateStatistics(validationResults)
        };
    }

    // ================================================
    // Aba 1: Resumo Executivo
    // ================================================
    async addSummarySheet(workbook, results, userInfo) {
        const sheet = workbook.addWorksheet('Resumo Executivo');
        
        // Configurar largura das colunas
        sheet.columns = [
            { width: 30 },
            { width: 20 },
            { width: 15 },
            { width: 40 }
        ];
        
        // Título
        sheet.mergeCells('A1:D1');
        const titleCell = sheet.getCell('A1');
        titleCell.value = '📊 RELATÓRIO DE VALIDAÇÃO DE EMAILS';
        titleCell.font = { name: 'Arial', size: 16, bold: true, color: { argb: 'FF667EEA' } };
        titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
        titleCell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FFF0F4FF' }
        };
        
        // Informações do relatório
        sheet.getCell('A3').value = 'Data do Relatório:';
        sheet.getCell('B3').value = new Date().toLocaleString('pt-BR');
        
        sheet.getCell('A4').value = 'Cliente:';
        sheet.getCell('B4').value = userInfo.company || 'Spark Nexus User';
        
        sheet.getCell('A5').value = 'Responsável:';
        sheet.getCell('B5').value = userInfo.name || userInfo.email || 'N/A';
        
        // Estatísticas principais
        const stats = this.calculateStatistics(results);
        
        sheet.getCell('A7').value = 'ESTATÍSTICAS GERAIS';
        sheet.getCell('A7').font = { bold: true, size: 14 };
        
        const statsData = [
            ['Total de Emails Analisados', stats.total],
            ['Emails Válidos', stats.valid, `${stats.validPercentage}%`],
            ['Emails Inválidos', stats.invalid, `${stats.invalidPercentage}%`],
            ['Score Médio', stats.avgScore.toFixed(1)],
            ['Taxa de Confiabilidade', `${stats.reliabilityRate}%`]
        ];
        
        let row = 9;
        statsData.forEach(stat => {
            sheet.getCell(`A${row}`).value = stat[0];
            sheet.getCell(`B${row}`).value = stat[1];
            if (stat[2]) sheet.getCell(`C${row}`).value = stat[2];
            
            // Aplicar cores baseadas nos valores
            if (stat[0].includes('Válidos')) {
                sheet.getCell(`B${row}`).font = { color: { argb: 'FF00A652' } };
            } else if (stat[0].includes('Inválidos')) {
                sheet.getCell(`B${row}`).font = { color: { argb: 'FFE74C3C' } };
            }
            
            row++;
        });
        
        // Adicionar mini-gráfico de distribuição
        sheet.getCell('A15').value = 'DISTRIBUIÇÃO POR CATEGORIA';
        sheet.getCell('A15').font = { bold: true, size: 14 };
        
        const distribution = this.calculateDistribution(results);
        row = 17;
        
        Object.entries(distribution).forEach(([category, count]) => {
            sheet.getCell(`A${row}`).value = category;
            sheet.getCell(`B${row}`).value = count;
            sheet.getCell(`C${row}`).value = `${((count/stats.total)*100).toFixed(1)}%`;
            
            // Barra visual
            const barLength = Math.round((count/stats.total) * 20);
            sheet.getCell(`D${row}`).value = '█'.repeat(barLength);
            sheet.getCell(`D${row}`).font = { color: { argb: 'FF667EEA' } };
            
            row++;
        });
        
        // Formatar toda a planilha
        this.formatSheet(sheet);
    }

    // ================================================
    // Aba 2: Dados Detalhados
    // ================================================
    async addDetailedSheet(workbook, results) {
        const sheet = workbook.addWorksheet('Dados Detalhados');
        
        // Cabeçalhos
        const headers = [
            'Email',
            'Válido',
            'Score',
            'Recomendação',
            'Domínio',
            'TLD',
            'MX Records',
            'Descartável',
            'Role-based',
            'Categoria',
            'Confiança',
            'Detalhes'
        ];
        
        // Adicionar cabeçalhos com formatação
        headers.forEach((header, index) => {
            const cell = sheet.getCell(1, index + 1);
            cell.value = header;
            cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
            cell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FF667EEA' }
            };
            cell.alignment = { horizontal: 'center', vertical: 'middle' };
        });
        
        // Adicionar dados
        results.forEach((result, index) => {
            const row = index + 2;
            const domain = result.email.split('@')[1] || 'N/A';
            
            sheet.getCell(row, 1).value = result.email;
            sheet.getCell(row, 2).value = result.valid ? 'SIM' : 'NÃO';
            sheet.getCell(row, 3).value = result.score;
            sheet.getCell(row, 4).value = result.recommendation?.message || 'N/A';
            sheet.getCell(row, 5).value = domain;
            sheet.getCell(row, 6).value = result.validations?.tld?.analysis?.tld || 'N/A';
            sheet.getCell(row, 7).value = result.validations?.mx?.valid ? 'SIM' : 'NÃO';
            sheet.getCell(row, 8).value = result.validations?.disposable?.isDisposable ? 'SIM' : 'NÃO';
            sheet.getCell(row, 9).value = result.validations?.roleBased?.isRoleBased ? 'SIM' : 'NÃO';
            sheet.getCell(row, 10).value = result.validations?.tld?.analysis?.factors?.tldCategory || 'N/A';
            sheet.getCell(row, 11).value = result.validations?.tld?.trust || 'N/A';
            
            // Montar detalhes
            const penalties = result.breakdown?.penalties || [];
            const bonuses = result.breakdown?.bonuses || [];
            let details = '';
            
            if (penalties.length > 0) {
                details += 'Penalidades: ' + penalties.map(p => p.reason).join(', ');
            }
            if (bonuses.length > 0) {
                details += (details ? ' | ' : '') + 'Bônus: ' + bonuses.map(b => b.reason).join(', ');
            }
            
            sheet.getCell(row, 12).value = details || 'Sem observações';
            
            // Aplicar formatação condicional
            if (result.valid) {
                sheet.getCell(row, 2).font = { color: { argb: 'FF00A652' } };
            } else {
                sheet.getCell(row, 2).font = { color: { argb: 'FFE74C3C' } };
            }
            
            // Colorir score
            const scoreCell = sheet.getCell(row, 3);
            if (result.score >= 80) {
                scoreCell.font = { color: { argb: 'FF00A652' }, bold: true };
            } else if (result.score >= 40) {
                scoreCell.font = { color: { argb: 'FFF39C12' }, bold: true };
            } else {
                scoreCell.font = { color: { argb: 'FFE74C3C' }, bold: true };
            }
            
            // Zebra striping
            if (index % 2 === 0) {
                for (let col = 1; col <= 12; col++) {
                    sheet.getCell(row, col).fill = {
                        type: 'pattern',
                        pattern: 'solid',
                        fgColor: { argb: 'FFF8F9FA' }
                    };
                }
            }
        });
        
        // Auto-ajustar colunas
        sheet.columns.forEach((column, index) => {
            if (index === 0) column.width = 30; // Email
            else if (index === 3) column.width = 35; // Recomendação
            else if (index === 11) column.width = 50; // Detalhes
            else column.width = 15;
        });
        
        // Adicionar filtros
        sheet.autoFilter = {
            from: 'A1',
            to: `L${results.length + 1}`
        };
        
        // Congelar painel
        sheet.views = [
            {
                state: 'frozen',
                xSplit: 0,
                ySplit: 1
            }
        ];
    }

    // ================================================
    // Aba 3: Estatísticas
    // ================================================
    async addStatisticsSheet(workbook, results) {
        const sheet = workbook.addWorksheet('Estatísticas');
        const stats = this.calculateAdvancedStatistics(results);
        
        // Título
        sheet.mergeCells('A1:D1');
        sheet.getCell('A1').value = '📈 ANÁLISE ESTATÍSTICA DETALHADA';
        sheet.getCell('A1').font = { size: 16, bold: true };
        sheet.getCell('A1').alignment = { horizontal: 'center' };
        
        // Estatísticas por Score Range
        sheet.getCell('A3').value = 'DISTRIBUIÇÃO POR FAIXA DE SCORE';
        sheet.getCell('A3').font = { bold: true, size: 14 };
        
        const scoreRanges = [
            { range: 'Excelente (80-100)', ...stats.scoreRanges.excellent },
            { range: 'Bom (60-79)', ...stats.scoreRanges.good },
            { range: 'Aceitável (40-59)', ...stats.scoreRanges.acceptable },
            { range: 'Ruim (20-39)', ...stats.scoreRanges.poor },
            { range: 'Inválido (0-19)', ...stats.scoreRanges.invalid }
        ];
        
        // Cabeçalhos
        sheet.getCell('A5').value = 'Faixa';
        sheet.getCell('B5').value = 'Quantidade';
        sheet.getCell('C5').value = 'Percentual';
        sheet.getCell('D5').value = 'Visualização';
        
        ['A5', 'B5', 'C5', 'D5'].forEach(cell => {
            sheet.getCell(cell).font = { bold: true };
            sheet.getCell(cell).fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFE8EAED' }
            };
        });
        
        scoreRanges.forEach((range, index) => {
            const row = 6 + index;
            sheet.getCell(`A${row}`).value = range.range;
            sheet.getCell(`B${row}`).value = range.count;
            sheet.getCell(`C${row}`).value = `${range.percentage}%`;
            
            // Barra visual
            const barLength = Math.round((range.percentage / 100) * 30);
            sheet.getCell(`D${row}`).value = '▓'.repeat(barLength) + '░'.repeat(30 - barLength);
            
            // Colorir baseado na faixa
            let color = 'FF666666';
            if (range.range.includes('Excelente')) color = 'FF00A652';
            else if (range.range.includes('Bom')) color = 'FF3498DB';
            else if (range.range.includes('Aceitável')) color = 'FFF39C12';
            else if (range.range.includes('Ruim')) color = 'FFE67E22';
            else if (range.range.includes('Inválido')) color = 'FFE74C3C';
            
            sheet.getCell(`D${row}`).font = { color: { argb: color } };
        });
        
        // Top domínios
        sheet.getCell('A13').value = 'TOP 10 DOMÍNIOS MAIS FREQUENTES';
        sheet.getCell('A13').font = { bold: true, size: 14 };
        
        sheet.getCell('A15').value = 'Domínio';
        sheet.getCell('B15').value = 'Ocorrências';
        sheet.getCell('C15').value = 'Score Médio';
        
        stats.topDomains.slice(0, 10).forEach((domain, index) => {
            const row = 16 + index;
            sheet.getCell(`A${row}`).value = domain.domain;
            sheet.getCell(`B${row}`).value = domain.count;
            sheet.getCell(`C${row}`).value = domain.avgScore.toFixed(1);
        });
        
        // Problemas mais comuns
        sheet.getCell('F3').value = 'PROBLEMAS MAIS COMUNS';
        sheet.getCell('F3').font = { bold: true, size: 14 };
        
        sheet.getCell('F5').value = 'Problema';
        sheet.getCell('G5').value = 'Ocorrências';
        
        stats.commonIssues.forEach((issue, index) => {
            const row = 6 + index;
            sheet.getCell(`F${row}`).value = issue.issue;
            sheet.getCell(`G${row}`).value = issue.count;
        });
        
        // Ajustar larguras
        sheet.columns = [
            { width: 25 }, { width: 15 }, { width: 15 }, 
            { width: 35 }, { width: 5 }, { width: 30 }, { width: 15 }
        ];
    }

    // ================================================
    // Aba 4: Análise de Domínios
    // ================================================
    async addDomainAnalysisSheet(workbook, results) {
        const sheet = workbook.addWorksheet('Análise de Domínios');
        
        const domainAnalysis = this.analyzeDomains(results);
        
        // Título
        sheet.mergeCells('A1:E1');
        sheet.getCell('A1').value = '🌐 ANÁLISE DETALHADA DE DOMÍNIOS';
        sheet.getCell('A1').font = { size: 16, bold: true };
        sheet.getCell('A1').alignment = { horizontal: 'center' };
        
        // Por categoria de TLD
        sheet.getCell('A3').value = 'ANÁLISE POR CATEGORIA DE TLD';
        sheet.getCell('A3').font = { bold: true, size: 14 };
        
        const headers = ['Categoria', 'Quantidade', '%', 'Score Médio', 'Taxa de Validade'];
        headers.forEach((header, index) => {
            const cell = sheet.getCell(5, index + 1);
            cell.value = header;
            cell.font = { bold: true };
            cell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFE8EAED' }
            };
        });
        
        let row = 6;
        Object.entries(domainAnalysis.byCategory).forEach(([category, data]) => {
            sheet.getCell(row, 1).value = category;
            sheet.getCell(row, 2).value = data.count;
            sheet.getCell(row, 3).value = `${data.percentage}%`;
            sheet.getCell(row, 4).value = data.avgScore.toFixed(1);
            sheet.getCell(row, 5).value = `${data.validityRate}%`;
            row++;
        });
        
        // Domínios suspeitos
        sheet.getCell('A15').value = 'DOMÍNIOS SUSPEITOS DETECTADOS';
        sheet.getCell('A15').font = { bold: true, size: 14, color: { argb: 'FFE74C3C' } };
        
        sheet.getCell('A17').value = 'Email';
        sheet.getCell('B17').value = 'Razão';
        sheet.getCell('C17').value = 'Score';
        
        row = 18;
        domainAnalysis.suspicious.forEach(item => {
            sheet.getCell(row, 1).value = item.email;
            sheet.getCell(row, 2).value = item.reason;
            sheet.getCell(row, 3).value = item.score;
            sheet.getCell(row, 3).font = { color: { argb: 'FFE74C3C' } };
            row++;
        });
        
        // Ajustar larguras
        sheet.columns = [
            { width: 35 }, { width: 15 }, { width: 10 }, { width: 15 }, { width: 20 }
        ];
    }

    // ================================================
    // Aba 5: Recomendações
    // ================================================
    async addRecommendationsSheet(workbook, results) {
        const sheet = workbook.addWorksheet('Recomendações');
        const recommendations = this.generateRecommendations(results);
        
        // Título
        sheet.mergeCells('A1:D1');
        sheet.getCell('A1').value = '💡 RECOMENDAÇÕES E AÇÕES SUGERIDAS';
        sheet.getCell('A1').font = { size: 16, bold: true };
        sheet.getCell('A1').alignment = { horizontal: 'center' };
        
        // Resumo de qualidade
        sheet.getCell('A3').value = 'ÍNDICE DE QUALIDADE DA LISTA';
        sheet.getCell('A3').font = { bold: true, size: 14 };
        
        const qualityScore = recommendations.qualityScore;
        sheet.getCell('A5').value = 'Score de Qualidade:';
        sheet.getCell('B5').value = `${qualityScore}/100`;
        sheet.getCell('B5').font = { 
            bold: true, 
            size: 20,
            color: { argb: qualityScore >= 70 ? 'FF00A652' : qualityScore >= 40 ? 'FFF39C12' : 'FFE74C3C' }
        };
        
        sheet.getCell('A6').value = 'Classificação:';
        sheet.getCell('B6').value = recommendations.classification;
        
        // Ações recomendadas
        sheet.getCell('A9').value = 'AÇÕES RECOMENDADAS';
        sheet.getCell('A9').font = { bold: true, size: 14 };
        
        let row = 11;
        recommendations.actions.forEach((action, index) => {
            sheet.getCell(`A${row}`).value = `${index + 1}. ${action.title}`;
            sheet.getCell(`A${row}`).font = { bold: true };
            row++;
            
            sheet.getCell(`B${row}`).value = action.description;
            sheet.getCell(`B${row}`).alignment = { wrapText: true };
            sheet.mergeCells(`B${row}:D${row}`);
            row++;
            
            sheet.getCell(`B${row}`).value = `Prioridade: ${action.priority}`;
            sheet.getCell(`B${row}`).font = { 
                italic: true,
                color: { argb: action.priority === 'Alta' ? 'FFE74C3C' : action.priority === 'Média' ? 'FFF39C12' : 'FF95A5A6' }
            };
            row += 2;
        });
        
        // Emails para remover
        if (recommendations.toRemove.length > 0) {
            sheet.getCell(`A${row}`).value = 'EMAILS RECOMENDADOS PARA REMOÇÃO';
            sheet.getCell(`A${row}`).font = { bold: true, size: 14, color: { argb: 'FFE74C3C' } };
            row += 2;
            
            sheet.getCell(`A${row}`).value = 'Email';
            sheet.getCell(`B${row}`).value = 'Motivo';
            sheet.getCell(`C${row}`).value = 'Score';
            row++;
            
            recommendations.toRemove.forEach(email => {
                sheet.getCell(`A${row}`).value = email.email;
                sheet.getCell(`B${row}`).value = email.reason;
                sheet.getCell(`C${row}`).value = email.score;
                row++;
            });
        }
        
        // Ajustar larguras
        sheet.columns = [
            { width: 40 }, { width: 50 }, { width: 15 }, { width: 30 }
        ];
    }

    // ================================================
    // Gerar gráficos
    // ================================================
    async generateCharts(results) {
        const charts = {};
        const stats = this.calculateStatistics(results);
        
        // Gráfico de Pizza - Válidos vs Inválidos
        const pieConfig = {
            type: 'pie',
            data: {
                labels: ['Válidos', 'Inválidos'],
                datasets: [{
                    data: [stats.valid, stats.invalid],
                    backgroundColor: ['#00A652', '#E74C3C'],
                    borderWidth: 2,
                    borderColor: '#fff'
                }]
            },
            options: {
                plugins: {
                    title: {
                        display: true,
                        text: 'Distribuição de Validade',
                        font: { size: 20 }
                    },
                    legend: {
                        position: 'bottom',
                        labels: { font: { size: 14 } }
                    }
                }
            }
        };
        
        charts.pieChart = await this.chartRenderer.renderToBuffer(pieConfig);
        
        // Gráfico de Barras - Score Distribution
        const distribution = this.calculateScoreDistribution(results);
        const barConfig = {
            type: 'bar',
            data: {
                labels: Object.keys(distribution),
                datasets: [{
                    label: 'Quantidade de Emails',
                    data: Object.values(distribution),
                    backgroundColor: [
                        '#00A652', '#3498DB', '#F39C12', '#E67E22', '#E74C3C'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                plugins: {
                    title: {
                        display: true,
                        text: 'Distribuição por Faixa de Score',
                        font: { size: 20 }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: { stepSize: 1 }
                    }
                }
            }
        };
        
        charts.barChart = await this.chartRenderer.renderToBuffer(barConfig);
        
        // Gráfico de Linha - Top Domínios
        const topDomains = this.getTopDomains(results, 5);
        const lineConfig = {
            type: 'line',
            data: {
                labels: topDomains.map(d => d.domain),
                datasets: [{
                    label: 'Score Médio',
                    data: topDomains.map(d => d.avgScore),
                    borderColor: '#667EEA',
                    backgroundColor: 'rgba(102, 126, 234, 0.1)',
                    tension: 0.4,
                    fill: true
                }]
            },
            options: {
                plugins: {
                    title: {
                        display: true,
                        text: 'Score Médio por Domínio (Top 5)',
                        font: { size: 20 }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100
                    }
                }
            }
        };
        
        charts.lineChart = await this.chartRenderer.renderToBuffer(lineConfig);
        
        return charts;
    }

    // ================================================
    // Métodos auxiliares de cálculo
    // ================================================
    calculateStatistics(results) {
        const total = results.length;
        const valid = results.filter(r => r.valid).length;
        const invalid = total - valid;
        const avgScore = results.reduce((sum, r) => sum + r.score, 0) / total;
        const highScore = results.filter(r => r.score >= 70).length;
        
        return {
            total,
            valid,
            invalid,
            validPercentage: ((valid / total) * 100).toFixed(1),
            invalidPercentage: ((invalid / total) * 100).toFixed(1),
            avgScore,
            reliabilityRate: ((highScore / total) * 100).toFixed(1)
        };
    }

    calculateAdvancedStatistics(results) {
        const scoreRanges = {
            excellent: { count: 0, percentage: 0 },
            good: { count: 0, percentage: 0 },
            acceptable: { count: 0, percentage: 0 },
            poor: { count: 0, percentage: 0 },
            invalid: { count: 0, percentage: 0 }
        };
        
        const domainMap = new Map();
        const issues = new Map();
        
        results.forEach(result => {
            // Score ranges
            if (result.score >= 80) scoreRanges.excellent.count++;
            else if (result.score >= 60) scoreRanges.good.count++;
            else if (result.score >= 40) scoreRanges.acceptable.count++;
            else if (result.score >= 20) scoreRanges.poor.count++;
            else scoreRanges.invalid.count++;
            
            // Domínios
            const domain = result.email.split('@')[1];
            if (domain) {
                if (!domainMap.has(domain)) {
                    domainMap.set(domain, { count: 0, totalScore: 0 });
                }
                const domainData = domainMap.get(domain);
                domainData.count++;
                domainData.totalScore += result.score;
            }
            
            // Issues
            if (result.breakdown?.penalties) {
                result.breakdown.penalties.forEach(penalty => {
                    issues.set(penalty.reason, (issues.get(penalty.reason) || 0) + 1);
                });
            }
        });
        
        // Calcular percentuais
        const total = results.length;
        Object.keys(scoreRanges).forEach(range => {
            scoreRanges[range].percentage = ((scoreRanges[range].count / total) * 100).toFixed(1);
        });
        
        // Top domínios
        const topDomains = Array.from(domainMap.entries())
            .map(([domain, data]) => ({
                domain,
                count: data.count,
                avgScore: data.totalScore / data.count
            }))
            .sort((a, b) => b.count - a.count);
        
        // Issues comuns
        const commonIssues = Array.from(issues.entries())
            .map(([issue, count]) => ({ issue, count }))
            .sort((a, b) => b.count - a.count);
        
        return {
            scoreRanges,
            topDomains,
            commonIssues
        };
    }

    calculateDistribution(results) {
        const distribution = {
            'Excelente (80-100)': 0,
            'Bom (60-79)': 0,
            'Aceitável (40-59)': 0,
            'Ruim (20-39)': 0,
            'Inválido (0-19)': 0
        };
        
        results.forEach(result => {
            if (result.score >= 80) distribution['Excelente (80-100)']++;
            else if (result.score >= 60) distribution['Bom (60-79)']++;
            else if (result.score >= 40) distribution['Aceitável (40-59)']++;
            else if (result.score >= 20) distribution['Ruim (20-39)']++;
            else distribution['Inválido (0-19)']++;
        });
        
        return distribution;
    }

    calculateScoreDistribution(results) {
        return this.calculateDistribution(results);
    }

    getTopDomains(results, limit = 10) {
        const domainMap = new Map();
        
        results.forEach(result => {
            const domain = result.email.split('@')[1];
            if (domain) {
                if (!domainMap.has(domain)) {
                    domainMap.set(domain, { count: 0, totalScore: 0 });
                }
                const data = domainMap.get(domain);
                data.count++;
                data.totalScore += result.score;
            }
        });
        
        return Array.from(domainMap.entries())
            .map(([domain, data]) => ({
                domain,
                count: data.count,
                avgScore: data.totalScore / data.count
            }))
            .sort((a, b) => b.count - a.count)
            .slice(0, limit);
    }

    analyzeDomains(results) {
        const analysis = {
            byCategory: {},
            suspicious: [],
            byTLD: {}
        };
        
        results.forEach(result => {
            const category = result.validations?.tld?.analysis?.factors?.tldCategory || 'unknown';
            
            if (!analysis.byCategory[category]) {
                analysis.byCategory[category] = {
                    count: 0,
                    validCount: 0,
                    totalScore: 0
                };
            }
            
            analysis.byCategory[category].count++;
            if (result.valid) analysis.byCategory[category].validCount++;
            analysis.byCategory[category].totalScore += result.score;
            
            // Detectar suspeitos
            if (result.score < 30 || result.validations?.disposable?.isDisposable) {
                analysis.suspicious.push({
                    email: result.email,
                    score: result.score,
                    reason: result.validations?.disposable?.isDisposable ? 
                        'Email descartável' : 'Score muito baixo'
                });
            }
        });
        
        // Calcular estatísticas
        const total = results.length;
        Object.keys(analysis.byCategory).forEach(category => {
            const data = analysis.byCategory[category];
            data.percentage = ((data.count / total) * 100).toFixed(1);
            data.avgScore = data.totalScore / data.count;
            data.validityRate = ((data.validCount / data.count) * 100).toFixed(1);
        });
        
        return analysis;
    }

    generateRecommendations(results) {
        const stats = this.calculateStatistics(results);
        const qualityScore = Math.round(
            (stats.validPercentage * 0.4) + 
            (stats.avgScore * 0.6)
        );
        
        let classification = 'Excelente';
        if (qualityScore < 70) classification = 'Boa';
        if (qualityScore < 50) classification = 'Regular';
        if (qualityScore < 30) classification = 'Ruim';
        
        const actions = [];
        
        // Recomendações baseadas na qualidade
        if (stats.invalidPercentage > 30) {
            actions.push({
                title: 'Limpeza Urgente da Base',
                description: 'Mais de 30% dos emails são inválidos. Recomenda-se uma limpeza imediata da base para evitar problemas de reputação.',
                priority: 'Alta'
            });
        }
        
        if (stats.avgScore < 50) {
            actions.push({
                title: 'Revisão da Origem dos Dados',
                description: 'O score médio está baixo. Verifique a origem dos emails e considere implementar validação em tempo real na captura.',
                priority: 'Alta'
            });
        }
        
        const disposableCount = results.filter(r => r.validations?.disposable?.isDisposable).length;
        if (disposableCount > results.length * 0.1) {
            actions.push({
                title: 'Bloqueio de Emails Temporários',
                description: `${((disposableCount/results.length)*100).toFixed(1)}% dos emails são temporários. Implemente bloqueio desses domínios no formulário de cadastro.`,
                priority: 'Média'
            });
        }
        
        const roleBasedCount = results.filter(r => r.validations?.roleBased?.isRoleBased).length;
        if (roleBasedCount > results.length * 0.2) {
            actions.push({
                title: 'Segmentação de Emails Role-based',
                description: 'Muitos emails genéricos detectados (info@, contact@). Considere campanhas separadas para esses contatos.',
                priority: 'Baixa'
            });
        }
        
        // Emails para remover
        const toRemove = results
            .filter(r => !r.valid || r.score < 20)
            .map(r => ({
                email: r.email,
                score: r.score,
                reason: !r.valid ? 'Email inválido' : 'Score muito baixo'
            }))
            .slice(0, 20); // Limitar a 20 para não poluir
        
        return {
            qualityScore,
            classification,
            actions,
            toRemove
        };
    }

    formatSheet(sheet) {
        // Adicionar bordas e alinhamento
        sheet.eachRow((row, rowNumber) => {
            row.eachCell((cell) => {
                cell.border = {
                    top: { style: 'thin' },
                    left: { style: 'thin' },
                    bottom: { style: 'thin' },
                    right: { style: 'thin' }
                };
                
                if (typeof cell.value === 'number') {
                    cell.alignment = { horizontal: 'right' };
                }
            });
        });
    }
}

module.exports = ReportService;
