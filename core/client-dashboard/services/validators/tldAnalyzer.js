// ================================================
// TLD Analyzer - Análise avançada de domínios
// ================================================

const fs = require('fs');
const path = require('path');

class TLDAnalyzer {
    constructor() {
        this.tldScores = this.loadTLDScores();
        this.defaultScore = { score: 5, trust: "unknown", category: "generic", weight: 0.5 };
        
        // Cache de análises recentes
        this.analysisCache = new Map();
        this.cacheMaxSize = 1000;
        
        // Estatísticas
        this.stats = {
            totalAnalyzed: 0,
            cacheHits: 0,
            unknownTLDs: new Set()
        };
    }

    loadTLDScores() {
        try {
            const filePath = path.join(__dirname, '../../data/tldScores.json');
            const data = fs.readFileSync(filePath, 'utf8');
            const scores = JSON.parse(data);
            
            // Flatten the structure para busca mais rápida
            const flattened = {};
            for (const category in scores) {
                for (const tld in scores[category]) {
                    flattened[tld.toLowerCase()] = {
                        ...scores[category][tld],
                        mainCategory: category
                    };
                }
            }
            
            console.log(`📊 TLD Analyzer: ${Object.keys(flattened).length} TLDs carregados`);
            return flattened;
        } catch (error) {
            console.error('❌ Erro ao carregar TLD scores:', error);
            return {};
        }
    }

    analyzeDomain(domain) {
        if (!domain) return null;
        
        this.stats.totalAnalyzed++;
        
        // Verificar cache
        if (this.analysisCache.has(domain)) {
            this.stats.cacheHits++;
            return this.analysisCache.get(domain);
        }
        
        // Extrair TLD
        const parts = domain.toLowerCase().split('.');
        let tld = null;
        let tldInfo = null;
        
        // Tentar TLD composto primeiro (ex: com.br, co.uk)
        if (parts.length >= 2) {
            const compound = parts.slice(-2).join('.');
            if (this.tldScores[compound]) {
                tld = compound;
                tldInfo = this.tldScores[compound];
            }
        }
        
        // Se não encontrou composto, tentar simples
        if (!tldInfo && parts.length >= 1) {
            const simple = parts[parts.length - 1];
            if (this.tldScores[simple]) {
                tld = simple;
                tldInfo = this.tldScores[simple];
            } else {
                // TLD desconhecido
                this.stats.unknownTLDs.add(simple);
                tld = simple;
                tldInfo = { ...this.defaultScore, tld: simple };
            }
        }
        
        // Análise adicional
        const analysis = this.performDetailedAnalysis(domain, tld, tldInfo);
        
        // Adicionar ao cache (com limite)
        if (this.analysisCache.size >= this.cacheMaxSize) {
            const firstKey = this.analysisCache.keys().next().value;
            this.analysisCache.delete(firstKey);
        }
        this.analysisCache.set(domain, analysis);
        
        return analysis;
    }

    performDetailedAnalysis(domain, tld, tldInfo) {
        const analysis = {
            domain,
            tld,
            ...tldInfo,
            factors: {
                tldScore: tldInfo.score || 5,
                tldTrust: tldInfo.trust || "unknown",
                tldCategory: tldInfo.category || "generic",
                weight: tldInfo.weight || 0.5
            },
            penalties: [],
            bonuses: [],
            finalScore: 0,
            recommendation: ""
        };
        
        // Calcular penalidades e bônus
        const domainName = domain.replace(`.${tld}`, '');
        
        // Penalidade para domínios muito curtos (possível spam)
        if (domainName.length <= 3 && tldInfo.trust !== "very_high") {
            analysis.penalties.push({
                reason: "Domínio muito curto",
                impact: -1
            });
        }
        
        // Penalidade para muitos hífens
        const hyphenCount = (domainName.match(/-/g) || []).length;
        if (hyphenCount > 2) {
            analysis.penalties.push({
                reason: `Muitos hífens (${hyphenCount})`,
                impact: -2
            });
        }
        
        // Penalidade para números excessivos
        const numberCount = (domainName.match(/\d/g) || []).length;
        if (numberCount > domainName.length * 0.5) {
            analysis.penalties.push({
                reason: "Muitos números no domínio",
                impact: -1
            });
        }
        
        // Bônus para domínios .gov e .edu
        if (tldInfo.category === "government" || tldInfo.category === "educational") {
            analysis.bonuses.push({
                reason: "Domínio institucional confiável",
                impact: 3
            });
        }
        
        // Bônus para domínios brasileiros em contexto BR
        if (tld.endsWith('.br')) {
            analysis.bonuses.push({
                reason: "Domínio brasileiro registrado",
                impact: 2
            });
        }
        
        // Calcular score final
        let finalScore = analysis.factors.tldScore;
        
        // Aplicar penalidades
        analysis.penalties.forEach(p => {
            finalScore += p.impact;
        });
        
        // Aplicar bônus
        analysis.bonuses.forEach(b => {
            finalScore += b.impact;
        });
        
        // Garantir que o score fique entre 0 e 10
        finalScore = Math.max(0, Math.min(10, finalScore));
        analysis.finalScore = finalScore;
        
        // Gerar recomendação
        if (finalScore >= 8) {
            analysis.recommendation = "Altamente confiável";
        } else if (finalScore >= 6) {
            analysis.recommendation = "Confiável";
        } else if (finalScore >= 4) {
            analysis.recommendation = "Verificação adicional recomendada";
        } else if (finalScore >= 2) {
            analysis.recommendation = "Suspeito - cuidado recomendado";
        } else {
            analysis.recommendation = "Não confiável - alto risco";
        }
        
        return analysis;
    }

    getStatistics() {
        return {
            ...this.stats,
            cacheSize: this.analysisCache.size,
            cacheHitRate: this.stats.totalAnalyzed > 0 
                ? ((this.stats.cacheHits / this.stats.totalAnalyzed) * 100).toFixed(2) + '%'
                : '0%',
            unknownTLDs: Array.from(this.stats.unknownTLDs)
        };
    }

    clearCache() {
        this.analysisCache.clear();
        console.log('🧹 Cache de análise TLD limpo');
    }

    reloadTLDScores() {
        this.tldScores = this.loadTLDScores();
        this.analysisCache.clear();
        console.log('✅ TLD scores recarregados');
        return Object.keys(this.tldScores).length;
    }
}

module.exports = TLDAnalyzer;
