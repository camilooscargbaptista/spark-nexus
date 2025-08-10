#!/bin/bash

# ================================================
# CORREÇÃO DO SISTEMA DE RELATÓRIOS
# Versão sem dependência de canvas/chartjs
# ================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 CORRIGINDO SISTEMA DE RELATÓRIOS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ================================================
# PASSO 1: Remover dependência problemática
# ================================================
echo -e "${YELLOW}1. Removendo dependências problemáticas...${NC}"

docker exec sparknexus-client sh -c "npm uninstall chartjs-node-canvas canvas 2>/dev/null || true"

# ================================================
# PASSO 2: Criar versão simplificada do ReportService
# ================================================
echo -e "\n${YELLOW}2. Criando ReportService otimizado (sem gráficos complexos)...${NC}"

cat > reportService_fixed.js << 'EOF'
// ================================================
// Report Service - Versão Otimizada
// Gera Excel profissional sem dependências pesadas
// ================================================

const ExcelJS = require('exceljs');
const fs = require('fs').promises;
const path = require('path');

class ReportService {
    constructor() {
        // Diretório para relatórios
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
        console.log('📊 Gerando relatório Excel...');
        const workbook = new ExcelJS.Workbook();
        
        // Metadados
        workbook.creator = 'Spark Nexus';
        workbook.lastModifiedBy = 'Spark Nexus System';
        workbook.created = new Date();
        workbook.modified = new Date();
        
        // Adicionar todas as abas
        await this.addSummarySheet(workbook, validationResults, userInfo);
        await this.addDetailedSheet(workbook, validationResults);
        await this.addStatisticsSheet(workbook, validationResults);
        await this.addDomainAnalysisSheet(workbook, validationResults);
        await this.addRecommendationsSheet(workbook, validationResults);
        
        // Salvar arquivo
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').substring(0, 19);
        const filename = `validation_report_${timestamp}.xlsx`;
        const filepath = path.join(this.reportsDir, filename);
        
        await workbook.xlsx.writeFile(filepath);
        console.log(`✅ Relatório salvo: ${filename}`);
        
        return {
            filepath,
            filename,
            stats: this.calculateStatistics(validationResults)
        };
    }

    // ================================================
    // Aba 1: Resumo Executivo com Visual Charts
    // ================================================
    async addSummarySheet(workbook, results, userInfo) {
        const sheet = workbook.addWorksheet('📊 Resumo Executivo');
        const stats = this.calculateStatistics(results);
        
        // Logo/Header
        sheet.mergeCells('A1:F2');
        const titleCell = sheet.getCell('A1');
        titleCell.value = '🚀 SPARK NEXUS - RELATÓRIO DE VALIDAÇÃO';
        titleCell.font = { name: 'Arial Black', size: 18, bold: true, color: { argb: 'FFFFFFFF' } };
        titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
        titleCell.fill = {
            type: 'gradient',
            gradient: 'angle',
            degree: 135,
            stops: [
                { position: 0, color: { argb: 'FF667EEA' } },
                { position: 0.5, color: { argb: 'FF8B5CF6' } },
                { position: 1, color: { argb: 'FF764BA2' } }
            ]
        };
        
        // Info Cards
        const infoCards = [
            { cell: 'A4', label: '📅 Data:', value: new Date().toLocaleString('pt-BR') },
            { cell: 'A5', label: '🏢 Empresa:', value: userInfo.company || 'Spark Nexus' },
            { cell: 'A6', label: '👤 Responsável:', value: userInfo.name || 'Sistema' },
            { cell: 'D4', label: '📧 Total Analisado:', value: stats.total },
            { cell: 'D5', label: '✅ Taxa de Validade:', value: `${stats.validPercentage}%` },
            { cell: 'D6', label: '⭐ Score Médio:', value: stats.avgScore.toFixed(1) }
        ];
        
        infoCards.forEach(card => {
            const [col, row] = [card.cell[0], parseInt(card.cell.substring(1))];
            sheet.getCell(card.cell).value = card.label;
            sheet.getCell(card.cell).font = { bold: true, size: 11 };
            sheet.getCell(`${String.fromCharCode(col.charCodeAt(0) + 1)}${row}`).value = card.value;
            sheet.getCell(`${String.fromCharCode(col.charCodeAt(0) + 1)}${row}`).font = { size: 11 };
        });
        
        // Score Visual (ASCII Art Style)
        sheet.mergeCells('A8:F8');
        sheet.getCell('A8').value = '═══════════════════ SCORE DE QUALIDADE ═══════════════════';
        sheet.getCell('A8').alignment = { horizontal: 'center' };
        sheet.getCell('A8').font = { bold: true, size: 12 };
        
        // Score Bar
        const scorePercent = Math.round(stats.avgScore);
        const barLength = 50;
        const filledBars = Math.round((scorePercent / 100) * barLength);
        const emptyBars = barLength - filledBars;
        
        sheet.mergeCells('A10:F10');
        const scoreBar = '█'.repeat(filledBars) + '░'.repeat(emptyBars);
        sheet.getCell('A10').value = scoreBar + ` ${scorePercent}%`;
        sheet.getCell('A10').font = { 
            name: 'Courier New', 
            size: 14,
            color: { argb: scorePercent >= 70 ? 'FF00A652' : scorePercent >= 40 ? 'FFF39C12' : 'FFE74C3C' }
        };
        sheet.getCell('A10').alignment = { horizontal: 'center' };
        
        // Classificação
        sheet.mergeCells('A11:F11');
        let classification = 'EXCELENTE';
        if (scorePercent < 70) classification = 'BOM';
        if (scorePercent < 50) classification = 'REGULAR';
        if (scorePercent < 30) classification = 'NECESSITA ATENÇÃO';
        sheet.getCell('A11').value = `Classificação: ${classification}`;
        sheet.getCell('A11').alignment = { horizontal: 'center' };
        sheet.getCell('A11').font = { bold: true, size: 14 };
        
        // Estatísticas em Cards
        sheet.getCell('A13').value = 'ESTATÍSTICAS PRINCIPAIS';
        sheet.getCell('A13').font = { bold: true, size: 14 };
        
        // Card Layout
        const statsCards = [
            { row: 15, col: 'A', title: 'EMAILS VÁLIDOS', value: stats.valid, percent: stats.validPercentage, color: 'FF00A652' },
            { row: 15, col: 'D', title: 'EMAILS INVÁLIDOS', value: stats.invalid, percent: stats.invalidPercentage, color: 'FFE74C3C' },
            { row: 20, col: 'A', title: 'ALTA CONFIANÇA', value: stats.highConfidence, percent: stats.highConfidencePercent, color: 'FF3498DB' },
            { row: 20, col: 'D', title: 'BAIXA CONFIANÇA', value: stats.lowConfidence, percent: stats.lowConfidencePercent, color: 'FFE67E22' }
        ];
        
        statsCards.forEach(card => {
            const titleCell = sheet.getCell(`${card.col}${card.row}`);
            titleCell.value = card.title;
            titleCell.font = { bold: true, size: 10 };
            
            const valueCell = sheet.getCell(`${card.col}${card.row + 1}`);
            valueCell.value = card.value;
            valueCell.font = { bold: true, size: 24, color: { argb: card.color } };
            
            const percentCell = sheet.getCell(`${card.col}${card.row + 2}`);
            percentCell.value = `${card.percent}% do total`;
            percentCell.font = { size: 10, italic: true };
            
            // Card border
            for (let i = 0; i < 3; i++) {
                for (let j = 0; j < 3; j++) {
                    const cell = sheet.getCell(card.row + i, card.col.charCodeAt(0) - 65 + j + 1);
                    cell.fill = {
                        type: 'pattern',
                        pattern: 'solid',
                        fgColor: { argb: 'FFF8F9FA' }
                    };
                    cell.border = {
                        top: { style: 'thin', color: { argb: 'FFE0E0E0' } },
                        left: { style: 'thin', color: { argb: 'FFE0E0E0' } },
                        bottom: { style: 'thin', color: { argb: 'FFE0E0E0' } },
                        right: { style: 'thin', color: { argb: 'FFE0E0E0' } }
                    };
                }
            }
        });
        
        // Visual Chart (Text-based)
        sheet.getCell('A25').value = 'DISTRIBUIÇÃO VISUAL';
        sheet.getCell('A25').font = { bold: true, size: 14 };
        
        const distribution = this.calculateDistribution(results);
        let row = 27;
        Object.entries(distribution).forEach(([range, count]) => {
            sheet.getCell(`A${row}`).value = range;
            sheet.getCell(`B${row}`).value = count;
            
            // Visual bar
            const barSize = Math.round((count / stats.total) * 20);
            sheet.getCell(`C${row}`).value = '▓'.repeat(barSize) + '░'.repeat(20 - barSize);
            sheet.getCell(`D${row}`).value = `${((count/stats.total)*100).toFixed(1)}%`;
            
            row++;
        });
        
        // Ajustar larguras
        sheet.columns = [
            { width: 25 }, { width: 15 }, { width: 25 }, 
            { width: 15 }, { width: 15 }, { width: 20 }
        ];
    }

    // ================================================
    // Aba 2: Dados Detalhados
    // ================================================
    async addDetailedSheet(workbook, results) {
        const sheet = workbook.addWorksheet('📋 Dados Detalhados');
        
        // Headers com estilo
        const headers = [
            '📧 Email', '✓ Válido', '📊 Score', '💡 Recomendação',
            '🌐 Domínio', '🏷️ TLD', '📮 MX', '🗑️ Descartável',
            '👥 Role-based', '📁 Categoria', '🔒 Confiança'
        ];
        
        headers.forEach((header, index) => {
            const cell = sheet.getCell(1, index + 1);
            cell.value = header;
            cell.font = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11 };
            cell.fill = {
                type: 'gradient',
                gradient: 'angle',
                degree: 90,
                stops: [
                    { position: 0, color: { argb: 'FF667EEA' } },
                    { position: 1, color: { argb: 'FF764BA2' } }
                ]
            };
            cell.alignment = { horizontal: 'center', vertical: 'middle' };
            cell.border = {
                bottom: { style: 'thick', color: { argb: 'FF333333' } }
            };
        });
        
        // Dados com formatação condicional
        results.forEach((result, index) => {
            const row = index + 2;
            const domain = result.email.split('@')[1] || 'N/A';
            
            // Email
            sheet.getCell(row, 1).value = result.email;
            
            // Válido com ícone
            const validCell = sheet.getCell(row, 2);
            validCell.value = result.valid ? '✅ SIM' : '❌ NÃO';
            validCell.font = { 
                bold: true,
                color: { argb: result.valid ? 'FF00A652' : 'FFE74C3C' }
            };
            
            // Score com cor
            const scoreCell = sheet.getCell(row, 3);
            scoreCell.value = result.score;
            scoreCell.font = { 
                bold: true,
                size: 12,
                color: { 
                    argb: result.score >= 80 ? 'FF00A652' : 
                          result.score >= 40 ? 'FFF39C12' : 'FFE74C3C' 
                }
            };
            scoreCell.alignment = { horizontal: 'center' };
            
            // Recomendação
            sheet.getCell(row, 4).value = result.recommendation?.message || 'N/A';
            
            // Domínio e TLD
            sheet.getCell(row, 5).value = domain;
            sheet.getCell(row, 6).value = result.validations?.tld?.analysis?.tld || 'N/A';
            
            // MX
            sheet.getCell(row, 7).value = result.validations?.mx?.valid ? '✅' : '❌';
            sheet.getCell(row, 7).alignment = { horizontal: 'center' };
            
            // Descartável
            const disposableCell = sheet.getCell(row, 8);
            disposableCell.value = result.validations?.disposable?.isDisposable ? '⚠️ SIM' : '✓ NÃO';
            disposableCell.font = {
                color: { argb: result.validations?.disposable?.isDisposable ? 'FFE74C3C' : 'FF00A652' }
            };
            
            // Role-based
            sheet.getCell(row, 9).value = result.validations?.roleBased?.isRoleBased ? '⚠️ SIM' : '✓ NÃO';
            
            // Categoria
            sheet.getCell(row, 10).value = result.validations?.tld?.analysis?.factors?.tldCategory || 'N/A';
            
            // Confiança
            const trustCell = sheet.getCell(row, 11);
            const trust = result.validations?.tld?.trust || 'unknown';
            trustCell.value = trust.toUpperCase();
            trustCell.font = {
                bold: true,
                color: { 
                    argb: trust === 'very_high' ? 'FF00A652' :
                          trust === 'high' ? 'FF3498DB' :
                          trust === 'medium' ? 'FFF39C12' : 'FFE74C3C'
                }
            };
            
            // Zebra striping
            if (index % 2 === 0) {
                for (let col = 1; col <= 11; col++) {
                    sheet.getCell(row, col).fill = {
                        type: 'pattern',
                        pattern: 'solid',
                        fgColor: { argb: 'FFF0F4FF' }
                    };
                }
            }
        });
        
        // Auto filtros
        sheet.autoFilter = {
            from: { row: 1, column: 1 },
            to: { row: results.length + 1, column: 11 }
        };
        
        // Congelar painel
        sheet.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];
        
        // Ajustar larguras
        sheet.columns = [
            { width: 30 }, { width: 10 }, { width: 10 }, { width: 35 },
            { width: 20 }, { width: 12 }, { width: 8 }, { width: 15 },
            { width: 15 }, { width: 15 }, { width: 15 }
        ];
    }

    // ================================================
    // Aba 3: Estatísticas
    // ================================================
    async addStatisticsSheet(workbook, results) {
        const sheet = workbook.addWorksheet('📈 Estatísticas');
        const stats = this.calculateAdvancedStatistics(results);
        
        // Título
        sheet.mergeCells('A1:E1');
        sheet.getCell('A1').value = '📊 ANÁLISE ESTATÍSTICA COMPLETA';
        sheet.getCell('A1').font = { size: 16, bold: true };
        sheet.getCell('A1').alignment = { horizontal: 'center' };
        sheet.getCell('A1').fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FFE8EAED' }
        };
        
        // Score Ranges
        sheet.getCell('A3').value = '📊 DISTRIBUIÇÃO POR FAIXA DE SCORE';
        sheet.getCell('A3').font = { bold: true, size: 14 };
        
        const scoreHeaders = ['Faixa', 'Quantidade', '%', 'Visual'];
        scoreHeaders.forEach((header, index) => {
            const cell = sheet.getCell(5, index + 1);
            cell.value = header;
            cell.font = { bold: true };
            cell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFD3D3D3' }
            };
        });
        
        const scoreRanges = [
            { range: '⭐⭐⭐⭐⭐ Excelente (80-100)', ...stats.scoreRanges.excellent, color: 'FF00A652' },
            { range: '⭐⭐⭐⭐ Bom (60-79)', ...stats.scoreRanges.good, color: 'FF3498DB' },
            { range: '⭐⭐⭐ Aceitável (40-59)', ...stats.scoreRanges.acceptable, color: 'FFF39C12' },
            { range: '⭐⭐ Ruim (20-39)', ...stats.scoreRanges.poor, color: 'FFE67E22' },
            { range: '⭐ Inválido (0-19)', ...stats.scoreRanges.invalid, color: 'FFE74C3C' }
        ];
        
        scoreRanges.forEach((range, index) => {
            const row = 6 + index;
            sheet.getCell(row, 1).value = range.range;
            sheet.getCell(row, 2).value = range.count;
            sheet.getCell(row, 3).value = `${range.percentage}%`;
            
            // Visual bar
            const barLength = Math.round(parseFloat(range.percentage) / 5);
            sheet.getCell(row, 4).value = '█'.repeat(barLength) + '░'.repeat(20 - barLength);
            sheet.getCell(row, 4).font = { 
                name: 'Courier New',
                color: { argb: range.color }
            };
        });
        
        // Top Domínios
        sheet.getCell('A13').value = '🏆 TOP 10 DOMÍNIOS';
        sheet.getCell('A13').font = { bold: true, size: 14 };
        
        const domainHeaders = ['#', 'Domínio', 'Emails', 'Score Médio'];
        domainHeaders.forEach((header, index) => {
            const cell = sheet.getCell(15, index + 1);
            cell.value = header;
            cell.font = { bold: true };
            cell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFD3D3D3' }
            };
        });
        
        stats.topDomains.slice(0, 10).forEach((domain, index) => {
            const row = 16 + index;
            sheet.getCell(row, 1).value = index + 1;
            sheet.getCell(row, 2).value = domain.domain;
            sheet.getCell(row, 3).value = domain.count;
            sheet.getCell(row, 4).value = domain.avgScore.toFixed(1);
            
            // Medalhas para top 3
            if (index === 0) sheet.getCell(row, 1).value = '🥇';
            if (index === 1) sheet.getCell(row, 1).value = '🥈';
            if (index === 2) sheet.getCell(row, 1).value = '🥉';
        });
        
        // Problemas Comuns
        sheet.getCell('F3').value = '⚠️ PROBLEMAS DETECTADOS';
        sheet.getCell('F3').font = { bold: true, size: 14, color: { argb: 'FFE74C3C' } };
        
        const issueHeaders = ['Problema', 'Ocorrências'];
        issueHeaders.forEach((header, index) => {
            const cell = sheet.getCell(5, index + 6);
            cell.value = header;
            cell.font = { bold: true };
            cell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFD3D3D3' }
            };
        });
        
        stats.commonIssues.forEach((issue, index) => {
            const row = 6 + index;
            sheet.getCell(row, 6).value = issue.issue;
            sheet.getCell(row, 7).value = issue.count;
        });
        
        // Ajustar larguras
        sheet.columns = [
            { width: 30 }, { width: 20 }, { width: 12 }, { width: 25 },
            { width: 5 }, { width: 35 }, { width: 15 }
        ];
    }

    // ================================================
    // Aba 4: Análise de Domínios
    // ================================================
    async addDomainAnalysisSheet(workbook, results) {
        const sheet = workbook.addWorksheet('🌐 Análise de Domínios');
        const analysis = this.analyzeDomains(results);
        
        // Título
        sheet.mergeCells('A1:E1');
        sheet.getCell('A1').value = '🌍 ANÁLISE DETALHADA DE DOMÍNIOS E TLDs';
        sheet.getCell('A1').font = { size: 16, bold: true };
        sheet.getCell('A1').alignment = { horizontal: 'center' };
        
        // Por Categoria
        sheet.getCell('A3').value = '📂 DISTRIBUIÇÃO POR CATEGORIA';
        sheet.getCell('A3').font = { bold: true, size: 14 };
        
        const catHeaders = ['Categoria', 'Qtd', '%', 'Score Médio', 'Taxa Válidos'];
        catHeaders.forEach((header, index) => {
            const cell = sheet.getCell(5, index + 1);
            cell.value = header;
            cell.font = { bold: true };
            cell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FF667EEA' }
            };
            cell.font.color = { argb: 'FFFFFFFF' };
        });
        
        let row = 6;
        Object.entries(analysis.byCategory).forEach(([category, data]) => {
            sheet.getCell(row, 1).value = category.toUpperCase();
            sheet.getCell(row, 2).value = data.count;
            sheet.getCell(row, 3).value = `${data.percentage}%`;
            sheet.getCell(row, 4).value = data.avgScore.toFixed(1);
            sheet.getCell(row, 5).value = `${data.validityRate}%`;
            
            // Colorir baseado no score
            const scoreCell = sheet.getCell(row, 4);
            scoreCell.font = {
                bold: true,
                color: {
                    argb: data.avgScore >= 70 ? 'FF00A652' :
                          data.avgScore >= 40 ? 'FFF39C12' : 'FFE74C3C'
                }
            };
            
            row++;
        });
        
        // Domínios Suspeitos
        if (analysis.suspicious.length > 0) {
            row += 2;
            sheet.getCell(`A${row}`).value = '🚨 DOMÍNIOS SUSPEITOS DETECTADOS';
            sheet.getCell(`A${row}`).font = { bold: true, size: 14, color: { argb: 'FFE74C3C' } };
            
            row += 2;
            ['Email', 'Motivo', 'Score'].forEach((header, index) => {
                const cell = sheet.getCell(row, index + 1);
                cell.value = header;
                cell.font = { bold: true };
                cell.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFFFCCCC' }
                };
            });
            
            row++;
            analysis.suspicious.slice(0, 20).forEach(item => {
                sheet.getCell(row, 1).value = item.email;
                sheet.getCell(row, 2).value = item.reason;
                sheet.getCell(row, 3).value = item.score;
                sheet.getCell(row, 3).font = { color: { argb: 'FFE74C3C' }, bold: true };
                row++;
            });
        }
        
        // Ajustar larguras
        sheet.columns = [
            { width: 35 }, { width: 10 }, { width: 10 }, { width: 15 }, { width: 15 }
        ];
    }

    // ================================================
    // Aba 5: Recomendações
    // ================================================
    async addRecommendationsSheet(workbook, results) {
        const sheet = workbook.addWorksheet('💡 Recomendações');
        const recommendations = this.generateRecommendations(results);
        
        // Título
        sheet.mergeCells('A1:D1');
        sheet.getCell('A1').value = '🎯 RECOMENDAÇÕES E PLANO DE AÇÃO';
        sheet.getCell('A1').font = { size: 16, bold: true };
        sheet.getCell('A1').alignment = { horizontal: 'center' };
        
        // Score de Qualidade
        sheet.mergeCells('A3:B3');
        sheet.getCell('A3').value = 'ÍNDICE DE QUALIDADE DA LISTA';
        sheet.getCell('A3').font = { bold: true, size: 14 };
        
        // Score visual grande
        sheet.mergeCells('A5:B7');
        const scoreCell = sheet.getCell('A5');
        scoreCell.value = recommendations.qualityScore;
        scoreCell.font = { 
            bold: true, 
            size: 48,
            color: { 
                argb: recommendations.qualityScore >= 70 ? 'FF00A652' : 
                      recommendations.qualityScore >= 40 ? 'FFF39C12' : 'FFE74C3C' 
            }
        };
        scoreCell.alignment = { horizontal: 'center', vertical: 'middle' };
        
        sheet.getCell('C5').value = 'Classificação:';
        sheet.getCell('C6').value = recommendations.classification;
        sheet.getCell('C6').font = { bold: true, size: 16 };
        
        // Ações Recomendadas
        sheet.getCell('A10').value = '📌 AÇÕES RECOMENDADAS';
        sheet.getCell('A10').font = { bold: true, size: 14 };
        
        let row = 12;
        recommendations.actions.forEach((action, index) => {
            // Prioridade com cor
            const priorityCell = sheet.getCell(row, 1);
            priorityCell.value = `[${action.priority.toUpperCase()}]`;
            priorityCell.font = {
                bold: true,
                color: {
                    argb: action.priority === 'Alta' ? 'FFE74C3C' :
                          action.priority === 'Média' ? 'FFF39C12' : 'FF95A5A6'
                }
            };
            
            // Título da ação
            sheet.mergeCells(`B${row}:D${row}`);
            const titleCell = sheet.getCell(`B${row}`);
            titleCell.value = `${index + 1}. ${action.title}`;
            titleCell.font = { bold: true, size: 12 };
            
            row++;
            
            // Descrição
            sheet.mergeCells(`B${row}:D${row}`);
            const descCell = sheet.getCell(`B${row}`);
            descCell.value = action.description;
            descCell.alignment = { wrapText: true };
            descCell.fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFF8F9FA' }
            };
            
            row += 2;
        });
        
        // Lista de emails para remover
        if (recommendations.toRemove.length > 0) {
            row++;
            sheet.getCell(`A${row}`).value = '🗑️ EMAILS PARA REMOVER';
            sheet.getCell(`A${row}`).font = { bold: true, size: 14, color: { argb: 'FFE74C3C' } };
            
            row += 2;
            ['Email', 'Motivo', 'Score'].forEach((header, index) => {
                const cell = sheet.getCell(row, index + 1);
                cell.value = header;
                cell.font = { bold: true };
                cell.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFFFCCCC' }
                };
            });
            
            row++;
            recommendations.toRemove.forEach(email => {
                sheet.getCell(row, 1).value = email.email;
                sheet.getCell(row, 2).value = email.reason;
                sheet.getCell(row, 3).value = email.score;
                row++;
            });
        }
        
        // Ajustar larguras
        sheet.columns = [
            { width: 15 }, { width: 40 }, { width: 30 }, { width: 20 }
        ];
    }

    // ================================================
    // Métodos de Cálculo
    // ================================================
    calculateStatistics(results) {
        const total = results.length || 1;
        const valid = results.filter(r => r.valid).length;
        const invalid = total - valid;
        const avgScore = results.reduce((sum, r) => sum + (r.score || 0), 0) / total;
        const highConfidence = results.filter(r => r.score >= 70).length;
        const lowConfidence = results.filter(r => r.score < 40).length;
        
        return {
            total,
            valid,
            invalid,
            validPercentage: ((valid / total) * 100).toFixed(1),
            invalidPercentage: ((invalid / total) * 100).toFixed(1),
            avgScore,
            highConfidence,
            lowConfidence,
            highConfidencePercent: ((highConfidence / total) * 100).toFixed(1),
            lowConfidencePercent: ((lowConfidence / total) * 100).toFixed(1),
            reliabilityRate: ((highConfidence / total) * 100).toFixed(1)
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
        
        const total = results.length || 1;
        Object.keys(scoreRanges).forEach(range => {
            scoreRanges[range].percentage = ((scoreRanges[range].count / total) * 100).toFixed(1);
        });
        
        const topDomains = Array.from(domainMap.entries())
            .map(([domain, data]) => ({
                domain,
                count: data.count,
                avgScore: data.totalScore / data.count
            }))
            .sort((a, b) => b.count - a.count);
        
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

    analyzeDomains(results) {
        const analysis = {
            byCategory: {},
            suspicious: []
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
            
            if (result.score < 30 || result.validations?.disposable?.isDisposable) {
                analysis.suspicious.push({
                    email: result.email,
                    score: result.score,
                    reason: result.validations?.disposable?.isDisposable ? 
                        'Email descartável/temporário' : 'Score muito baixo'
                });
            }
        });
        
        const total = results.length || 1;
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
            (parseFloat(stats.validPercentage) * 0.4) + 
            (stats.avgScore * 0.6)
        );
        
        let classification = 'Excelente';
        if (qualityScore < 70) classification = 'Boa';
        if (qualityScore < 50) classification = 'Regular';
        if (qualityScore < 30) classification = 'Necessita Atenção Urgente';
        
        const actions = [];
        
        if (parseFloat(stats.invalidPercentage) > 30) {
            actions.push({
                title: 'Limpeza Urgente da Base',
                description: `${stats.invalidPercentage}% dos emails são inválidos. Remova imediatamente os emails inválidos para melhorar a taxa de entrega e evitar ser marcado como spam.`,
                priority: 'Alta'
            });
        }
        
        if (stats.avgScore < 50) {
            actions.push({
                title: 'Revisar Processo de Captura',
                description: 'O score médio está baixo. Implemente validação em tempo real nos formulários e considere double opt-in para garantir qualidade.',
                priority: 'Alta'
            });
        }
        
        const disposableCount = results.filter(r => r.validations?.disposable?.isDisposable).length;
        if (disposableCount > results.length * 0.1) {
            actions.push({
                title: 'Bloquear Emails Temporários',
                description: `${((disposableCount/results.length)*100).toFixed(1)}% são emails temporários. Configure bloqueio desses domínios no formulário de cadastro.`,
                priority: 'Média'
            });
        }
        
        actions.push({
            title: 'Segmentar Lista por Score',
            description: 'Crie segmentos baseados no score de validação. Envie campanhas mais importantes apenas para emails com score > 70.',
            priority: 'Baixa'
        });
        
        const toRemove = results
            .filter(r => !r.valid || r.score < 20)
            .map(r => ({
                email: r.email,
                score: r.score,
                reason: !r.valid ? 'Email inválido' : 'Score muito baixo'
            }))
            .slice(0, 50);
        
        return {
            qualityScore,
            classification,
            actions,
            toRemove
        };
    }
}

module.exports = ReportService;
EOF

echo -e "${GREEN}✅ ReportService otimizado criado${NC}"

# ================================================
# PASSO 3: Copiar arquivo corrigido
# ================================================
echo -e "\n${YELLOW}3. Atualizando ReportService no container...${NC}"

docker cp reportService_fixed.js sparknexus-client:/app/services/reportService.js

# ================================================
# PASSO 4: Verificar e corrigir imports
# ================================================
echo -e "\n${YELLOW}4. Verificando imports no server.js...${NC}"

cat > check_imports.js << 'EOF'
const fs = require('fs');

try {
    let content = fs.readFileSync('/app/server.js', 'utf8');
    
    // Verificar se fs está importado
    if (!content.includes("const fs = require('fs')")) {
        // Adicionar import do fs após outros requires
        content = content.replace(
            "const path = require('path');",
            "const path = require('path');\nconst fs = require('fs');"
        );
    }
    
    fs.writeFileSync('/app/server.js', content);
    console.log('✅ Imports verificados');
} catch (error) {
    console.error('Erro:', error);
}
EOF

docker cp check_imports.js sparknexus-client:/tmp/
docker exec sparknexus-client node /tmp/check_imports.js

# ================================================
# PASSO 5: Reiniciar container
# ================================================
echo -e "\n${YELLOW}5. Reiniciando container...${NC}"

docker-compose restart client-dashboard

echo -e "${YELLOW}⏳ Aguardando 15 segundos...${NC}"
sleep 15

# ================================================
# PASSO 6: Verificar status
# ================================================
echo -e "\n${YELLOW}6. Verificando status do sistema...${NC}"

if docker ps | grep -q sparknexus-client; then
    echo -e "${GREEN}✅ Container rodando${NC}"
    
    # Verificar se ExcelJS está instalado
    echo -e "\n${BLUE}Verificando ExcelJS:${NC}"
    docker exec sparknexus-client sh -c "npm list exceljs 2>/dev/null | grep exceljs" || echo "ExcelJS não encontrado"
    
    # Verificar logs
    echo -e "\n${BLUE}Últimos logs:${NC}"
    docker-compose logs --tail=10 client-dashboard 2>&1 | grep -v "GET /favicon.ico" | tail -5
else
    echo -e "${RED}❌ Container não está rodando${NC}"
    docker-compose logs --tail=30 client-dashboard
fi

# ================================================
# FINALIZAÇÃO
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SISTEMA DE RELATÓRIOS CORRIGIDO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BLUE}📊 VERSÃO OTIMIZADA IMPLEMENTADA:${NC}"
echo -e "  ✅ Excel profissional com 5 abas"
echo -e "  ✅ Formatação rica com cores e estilos"
echo -e "  ✅ Gráficos visuais em ASCII/Unicode"
echo -e "  ✅ Sem dependências problemáticas (canvas)"
echo -e "  ✅ Compatível com Alpine Linux"

echo -e "\n${BLUE}🎨 RECURSOS DO EXCEL:${NC}"
echo -e "  • Headers com gradientes"
echo -e "  • Formatação condicional"
echo -e "  • Ícones e emojis"
echo -e "  • Barras de progresso visuais"
echo -e "  • Zebra striping"
echo -e "  • Auto-filtros"
echo -e "  • Células mescladas"

echo -e "\n${GREEN}🎉 Sistema pronto para uso!${NC}"
echo -e "Faça upload de um CSV para receber o relatório profissional por email!"

# Limpar arquivos temporários
rm -f reportService_fixed.js check_imports.js

exit 0