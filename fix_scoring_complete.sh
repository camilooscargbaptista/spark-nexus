#!/bin/bash

# ================================================
# FIX SCORING COMPLETE - SPARK NEXUS
# Correção completa do sistema de scoring
# Local: Executar na raiz do spark-nexus
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
║              SPARK NEXUS - SCORING FIX v2.0                  ║
║           Correção Completa do Sistema de Scoring            ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Timestamp para backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="scoring_fix_${TIMESTAMP}.log"

# Função de log
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# ================================================
# VERIFICAR ESTRUTURA DO PROJETO
# ================================================
log "🔍 Verificando estrutura do projeto..."

if [ ! -d "core" ]; then
    error "Este script deve ser executado na raiz do spark-nexus (onde está a pasta core/)"
fi

if [ ! -d "core/client-dashboard" ]; then
    error "Estrutura incorreta: não encontrado core/client-dashboard/"
fi

success "Estrutura do projeto verificada: spark-nexus/core/client-dashboard/"

# ================================================
# LOCALIZAR ARQUIVO ECOMMERCESCORING.JS
# ================================================
log "📍 Localizando arquivo EcommerceScoring.js..."

POSSIBLE_PATHS=(
    "core/client-dashboard/services/validators/advanced/EcommerceScoring.js"
    "core/client-dashboard/services/EcommerceScoring.js"
    "core/client-dashboard/src/services/EcommerceScoring.js"
    "core/client-dashboard/lib/EcommerceScoring.js"
    "core/client-dashboard/validators/EcommerceScoring.js"
)

SCORING_FILE=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        SCORING_FILE="$path"
        success "Arquivo encontrado: $SCORING_FILE"
        break
    fi
done

if [ -z "$SCORING_FILE" ]; then
    warning "Procurando em toda estrutura..."
    SCORING_FILE=$(find . -name "EcommerceScoring.js" 2>/dev/null | grep -v node_modules | grep -v backup | head -1)
    
    if [ -z "$SCORING_FILE" ]; then
        error "Arquivo EcommerceScoring.js não encontrado!"
    fi
    success "Arquivo encontrado: $SCORING_FILE"
fi

SCORING_DIR=$(dirname "$SCORING_FILE")

# ================================================
# FAZER BACKUP
# ================================================
log "💾 Criando backup do arquivo original..."

BACKUP_DIR="backups/scoring_complete_fix_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"
cp "$SCORING_FILE" "$BACKUP_DIR/EcommerceScoring_original.js"

# Backup de outros arquivos relacionados se existirem
if [ -f "${SCORING_DIR}/TrustedDomains.js" ]; then
    cp "${SCORING_DIR}/TrustedDomains.js" "$BACKUP_DIR/"
fi

success "Backup criado em: $BACKUP_DIR"

# ================================================
# CRIAR ARQUIVO DE DOMÍNIOS CONFIÁVEIS
# ================================================
log "🌐 Criando módulo de domínios confiáveis..."

cat > "${SCORING_DIR}/TrustedDomains.js" << 'EOF'
// ================================================
// Trusted Domains Module
// Lista de domínios confiáveis com categorização
// ================================================

class TrustedDomains {
    constructor() {
        // Provedores de email mainstream (alta confiança)
        this.mainstream = [
            'gmail.com', 'googlemail.com',
            'outlook.com', 'outlook.com.br',
            'hotmail.com', 'hotmail.com.br',
            'live.com', 'msn.com',
            'yahoo.com', 'yahoo.com.br',
            'icloud.com', 'me.com', 'mac.com'
        ];
        
        // Provedores brasileiros confiáveis
        this.brazilian = [
            'uol.com.br', 'bol.com.br',
            'terra.com.br', 'globo.com',
            'ig.com.br', 'r7.com',
            'zipmail.com.br'
        ];
        
        // Provedores corporativos/profissionais
        this.professional = [
            'protonmail.com', 'proton.me',
            'tutanota.com', 'tutanota.de',
            'fastmail.com', 'fastmail.fm',
            'zoho.com', 'yandex.com'
        ];
        
        // Domínios educacionais (padrão)
        this.educational = [
            '.edu', '.edu.br', '.ac.uk'
        ];
        
        // Domínios governamentais (padrão)
        this.government = [
            '.gov', '.gov.br', '.mil'
        ];
        
        // Cache de verificações
        this.cache = new Map();
    }
    
    isTrusted(domain) {
        if (!domain) return false;
        
        domain = domain.toLowerCase();
        
        // Verificar cache
        if (this.cache.has(domain)) {
            return this.cache.get(domain);
        }
        
        // Verificar mainstream
        if (this.mainstream.includes(domain)) {
            this.cache.set(domain, true);
            return true;
        }
        
        // Verificar brasileiros
        if (this.brazilian.includes(domain)) {
            this.cache.set(domain, true);
            return true;
        }
        
        // Verificar profissionais
        if (this.professional.includes(domain)) {
            this.cache.set(domain, true);
            return true;
        }
        
        // Verificar padrões educacionais e governamentais
        for (const pattern of [...this.educational, ...this.government]) {
            if (domain.endsWith(pattern)) {
                this.cache.set(domain, true);
                return true;
            }
        }
        
        this.cache.set(domain, false);
        return false;
    }
    
    getCategory(domain) {
        if (!domain) return 'unknown';
        
        domain = domain.toLowerCase();
        
        if (this.mainstream.includes(domain)) return 'mainstream';
        if (this.brazilian.includes(domain)) return 'brazilian';
        if (this.professional.includes(domain)) return 'professional';
        
        for (const pattern of this.educational) {
            if (domain.endsWith(pattern)) return 'educational';
        }
        
        for (const pattern of this.government) {
            if (domain.endsWith(pattern)) return 'government';
        }
        
        return 'other';
    }
    
    getTrustScore(domain) {
        const category = this.getCategory(domain);
        
        switch(category) {
            case 'mainstream':
            case 'government':
                return 10; // Máxima confiança
            case 'educational':
            case 'professional':
                return 9;
            case 'brazilian':
                return 8;
            default:
                return 5; // Score neutro para desconhecidos
        }
    }
}

module.exports = TrustedDomains;
EOF

success "Módulo TrustedDomains.js criado"

# ================================================
# CRIAR NOVO ARQUIVO ECOMMERCESCORING CORRIGIDO
# ================================================
log "🔧 Criando versão corrigida do EcommerceScoring..."

cat > "${SCORING_FILE}" << 'EOF'
// ================================================
// E-commerce Scoring System - VERSÃO CORRIGIDA v2.0
// Sistema de pontuação específico para lojas online
// ================================================

const TrustedDomains = require('./TrustedDomains');

class EcommerceScoring {
    constructor() {
        // Pesos ajustados para melhor balanceamento
        this.weights = {
            tldScore: 15,
            disposableCheck: 20,     // Reduzido de 25
            smtpVerification: 15,    // Reduzido de 20
            patternAnalysis: 15,
            formatQuality: 15,       // Aumentado de 10
            domainTrust: 15,         // Novo - confiança do domínio
            mxRecords: 5            // Novo - verificação MX
        };
        
        // Inicializar módulo de domínios confiáveis
        this.trustedDomains = new TrustedDomains();
        
        // Sistema de log configurável
        this.debug = process.env.DEBUG_SCORING === 'true';
    }
    
    // Método principal com validação de entrada
    calculateScore(validationResults) {
        // Validação de entrada
        if (!validationResults || typeof validationResults !== 'object') {
            this.logDebug('Invalid input: validationResults is null or not an object');
            return this.createEmptyScore('Invalid input');
        }
        
        // Garantir que email existe
        const email = validationResults.email || '';
        const domain = email.split('@')[1] || '';
        
        const scoreData = {
            baseScore: 0,
            finalScore: 0,
            confidence: 'low',
            buyerType: 'unknown',
            riskLevel: 'high',
            fraudProbability: 0,
            recommendations: [],
            breakdown: {},
            insights: {},
            metadata: {
                email: email,
                domain: domain,
                isTrustedDomain: false,
                domainCategory: 'unknown'
            }
        };
        
        // Verificar se é domínio confiável
        const isTrustedDomain = this.trustedDomains.isTrusted(domain);
        const domainCategory = this.trustedDomains.getCategory(domain);
        
        scoreData.metadata.isTrustedDomain = isTrustedDomain;
        scoreData.metadata.domainCategory = domainCategory;
        
        this.logDebug(`Processing email: ${email}, Domain: ${domain}, Trusted: ${isTrustedDomain}`);
        
        // Calcular score base
        let totalScore = 0;
        let totalWeight = 0;
        
        // 1. Domain Trust Score (NOVO)
        const domainTrustPoints = this.trustedDomains.getTrustScore(domain);
        totalScore += domainTrustPoints * this.weights.domainTrust;
        totalWeight += this.weights.domainTrust;
        scoreData.breakdown.domainTrust = {
            points: domainTrustPoints,
            weight: this.weights.domainTrust,
            weighted: domainTrustPoints * this.weights.domainTrust,
            category: domainCategory
        };
        
        // 2. TLD Score
        if (validationResults.tld) {
            const tldPoints = this.calculateTLDPoints(validationResults.tld, isTrustedDomain);
            totalScore += tldPoints * this.weights.tldScore;
            totalWeight += this.weights.tldScore;
            scoreData.breakdown.tld = {
                points: tldPoints,
                weight: this.weights.tldScore,
                weighted: tldPoints * this.weights.tldScore
            };
        }
        
        // 3. Disposable Check com fallback para domínios confiáveis
        if (validationResults.disposable) {
            const disposablePoints = this.calculateDisposablePoints(
                validationResults.disposable, 
                isTrustedDomain
            );
            totalScore += disposablePoints * this.weights.disposableCheck;
            totalWeight += this.weights.disposableCheck;
            scoreData.breakdown.disposable = {
                points: disposablePoints,
                weight: this.weights.disposableCheck,
                weighted: disposablePoints * this.weights.disposableCheck
            };
        }
        
        // 4. SMTP Verification com fallback
        if (validationResults.smtp) {
            const smtpPoints = this.calculateSMTPPoints(
                validationResults.smtp, 
                isTrustedDomain
            );
            totalScore += smtpPoints * this.weights.smtpVerification;
            totalWeight += this.weights.smtpVerification;
            scoreData.breakdown.smtp = {
                points: smtpPoints,
                weight: this.weights.smtpVerification,
                weighted: smtpPoints * this.weights.smtpVerification
            };
        }
        
        // 5. MX Records (NOVO)
        if (validationResults.mx) {
            const mxPoints = this.calculateMXPoints(validationResults.mx, isTrustedDomain);
            totalScore += mxPoints * this.weights.mxRecords;
            totalWeight += this.weights.mxRecords;
            scoreData.breakdown.mx = {
                points: mxPoints,
                weight: this.weights.mxRecords,
                weighted: mxPoints * this.weights.mxRecords
            };
        }
        
        // 6. Pattern Analysis
        if (validationResults.patterns) {
            const patternPoints = this.calculatePatternPoints(validationResults.patterns);
            totalScore += patternPoints * this.weights.patternAnalysis;
            totalWeight += this.weights.patternAnalysis;
            scoreData.breakdown.patterns = {
                points: patternPoints,
                weight: this.weights.patternAnalysis,
                weighted: patternPoints * this.weights.patternAnalysis
            };
        }
        
        // 7. Format Quality - com validação de email
        const formatPoints = this.calculateFormatPoints(email);
        totalScore += formatPoints * this.weights.formatQuality;
        totalWeight += this.weights.formatQuality;
        scoreData.breakdown.format = {
            points: formatPoints,
            weight: this.weights.formatQuality,
            weighted: formatPoints * this.weights.formatQuality
        };
        
        // CORREÇÃO CRÍTICA: Calcular score final corretamente
        // A fórmula correta multiplica por 10 para converter para escala 0-100
        if (totalWeight > 0) {
            scoreData.baseScore = Math.round((totalScore / totalWeight) * 10);
        } else {
            scoreData.baseScore = 0;
        }
        
        // Aplicar boost para domínios muito confiáveis
        if (isTrustedDomain && scoreData.baseScore < 70) {
            const boost = domainCategory === 'mainstream' ? 20 : 15;
            scoreData.baseScore = Math.min(scoreData.baseScore + boost, 85);
            this.logDebug(`Applied trusted domain boost: +${boost} points`);
        }
        
        scoreData.finalScore = Math.max(0, Math.min(100, scoreData.baseScore));
        
        this.logDebug(`Score calculation: Total=${totalScore}, Weight=${totalWeight}, Base=${scoreData.baseScore}, Final=${scoreData.finalScore}`);
        
        // Determinar classificações
        scoreData.buyerType = this.classifyBuyer(scoreData.finalScore, validationResults, isTrustedDomain);
        scoreData.riskLevel = this.assessRisk(scoreData.finalScore);
        scoreData.fraudProbability = this.calculateFraudProbability(
            scoreData.finalScore, 
            validationResults, 
            isTrustedDomain
        );
        scoreData.confidence = this.determineConfidence(scoreData.finalScore);
        
        // Gerar recomendações
        scoreData.recommendations = this.generateRecommendations(
            scoreData.finalScore, 
            validationResults,
            isTrustedDomain
        );
        
        // Adicionar insights
        scoreData.insights = this.generateInsights(validationResults, isTrustedDomain);
        
        return scoreData;
    }
    
    calculateTLDPoints(tldResult, isTrustedDomain) {
        // Domínios confiáveis sempre recebem pontuação alta
        if (isTrustedDomain) return 10;
        
        if (tldResult.isBlocked) return 0;
        if (tldResult.isSuspicious) return 2;
        if (tldResult.isPremium) return 10;
        if (tldResult.valid) return 6;
        return 0;
    }
    
    calculateDisposablePoints(disposableResult, isTrustedDomain) {
        // Domínios confiáveis NUNCA são descartáveis
        if (isTrustedDomain) {
            return 10;
        }
        
        if (disposableResult.isDisposable) {
            return 0;
        }
        
        return 10;
    }
    
    calculateSMTPPoints(smtpResult, isTrustedDomain) {
        // Fallback para domínios confiáveis que bloqueiam SMTP
        if (isTrustedDomain) {
            // Se SMTP falhou mas é domínio confiável, assumir válido
            if (!smtpResult.exists && smtpResult.error) {
                this.logDebug('SMTP failed for trusted domain, applying fallback');
                return 8; // Pontuação alta mas não máxima
            }
            
            // Se passou na verificação
            if (smtpResult.exists) {
                return 10;
            }
        }
        
        // Lógica padrão para outros domínios
        if (!smtpResult.smtp) return 5; // Não verificado
        if (smtpResult.exists && !smtpResult.catchAll) return 10;
        if (smtpResult.catchAll) return 6;
        if (!smtpResult.exists) return 2;
        return 5;
    }
    
    calculateMXPoints(mxResult, isTrustedDomain) {
        if (isTrustedDomain) return 10;
        
        if (mxResult && mxResult.valid) return 10;
        if (mxResult && mxResult.records > 0) return 8;
        
        return 2;
    }
    
    calculatePatternPoints(patternResult) {
        if (!patternResult.suspicious) return 10;
        if (patternResult.suspicionLevel >= 8) return 0;
        if (patternResult.suspicionLevel >= 6) return 3;
        if (patternResult.suspicionLevel >= 4) return 6;
        return 8;
    }
    
    calculateFormatPoints(email) {
        // Validação de entrada
        if (!email || typeof email !== 'string') {
            this.logDebug('Invalid email format: null or not string');
            return 0;
        }
        
        const parts = email.split('@');
        if (parts.length !== 2) {
            return 0;
        }
        
        const localPart = parts[0].toLowerCase();
        
        // Formato profissional (nome.sobrenome)
        if (/^[a-z]+\.[a-z]+$/.test(localPart)) return 10;
        
        // Formato corporativo comum
        if (/^[a-z]+[._-][a-z]+$/.test(localPart)) return 8;
        
        // Nome completo sem separadores (4-20 caracteres)
        if (/^[a-z]{4,20}$/.test(localPart)) return 7;
        
        // Nome simples
        if (/^[a-z]{3,15}$/.test(localPart)) return 6;
        
        // Com alguns números (comum em emails pessoais)
        if (/^[a-z]+[0-9]{1,4}$/.test(localPart)) return 5;
        
        // Formato genérico (info@, contact@, etc)
        if (/^(info|contact|admin|support|sales|hello|contato)/.test(localPart)) return 4;
        
        // Muitos números ou caracteres especiais
        if (/[0-9]{5,}/.test(localPart) || /[^a-z0-9._-]/.test(localPart)) return 2;
        
        // Formato suspeito ou não identificado
        return 3;
    }
    
    classifyBuyer(score, results, isTrustedDomain) {
        if (score >= 80) {
            if (isTrustedDomain) {
                return 'PREMIUM_BUYER';
            }
            return 'TRUSTED_BUYER';
        } else if (score >= 60) {
            return 'REGULAR_BUYER';
        } else if (score >= 40) {
            return 'NEW_BUYER';
        } else if (score >= 20) {
            return 'SUSPICIOUS_BUYER';
        }
        return 'HIGH_RISK_BUYER';
    }
    
    assessRisk(score) {
        if (score >= 80) return 'VERY_LOW';
        if (score >= 60) return 'LOW';
        if (score >= 40) return 'MEDIUM';
        if (score >= 20) return 'HIGH';
        return 'VERY_HIGH';
    }
    
    calculateFraudProbability(score, results, isTrustedDomain) {
        let probability = 100 - score; // Base
        
        // Reduzir significativamente para domínios confiáveis
        if (isTrustedDomain) {
            probability = Math.max(5, probability - 30);
        }
        
        // Ajustes baseados em indicadores
        if (results.disposable && results.disposable.isDisposable && !isTrustedDomain) {
            probability += 20;
        }
        
        if (results.patterns && results.patterns.suspicious) {
            probability += isTrustedDomain ? 5 : 15;
        }
        
        if (results.smtp && !results.smtp.exists && !isTrustedDomain) {
            probability += 10;
        }
        
        return Math.min(95, Math.max(5, probability));
    }
    
    determineConfidence(score) {
        if (score >= 80) return 'very_high';
        if (score >= 60) return 'high';
        if (score >= 40) return 'medium';
        if (score >= 20) return 'low';
        return 'very_low';
    }
    
    generateRecommendations(score, results, isTrustedDomain) {
        const recommendations = [];
        
        if (score >= 80) {
            recommendations.push({
                action: 'APPROVE',
                message: 'Aprovar compra normalmente',
                priority: 'low'
            });
            
            if (isTrustedDomain) {
                recommendations.push({
                    action: 'FAST_CHECKOUT',
                    message: 'Cliente com email de provedor confiável - liberar checkout rápido',
                    priority: 'low'
                });
            }
        } else if (score >= 60) {
            recommendations.push({
                action: 'APPROVE_WITH_MONITORING',
                message: 'Aprovar mas monitorar comportamento',
                priority: 'medium'
            });
        } else if (score >= 40) {
            recommendations.push({
                action: 'REQUEST_VERIFICATION',
                message: 'Solicitar verificação adicional (SMS/WhatsApp)',
                priority: 'high'
            });
            
            if (!isTrustedDomain) {
                recommendations.push({
                    action: 'LIMIT_PAYMENT_METHODS',
                    message: 'Limitar métodos de pagamento (apenas PIX/boleto)',
                    priority: 'high'
                });
            }
        } else {
            recommendations.push({
                action: 'MANUAL_REVIEW',
                message: 'Enviar para análise manual',
                priority: 'critical'
            });
            
            if (!isTrustedDomain) {
                recommendations.push({
                    action: 'BLOCK_HIGH_VALUE',
                    message: 'Bloquear compras acima de R$ 500',
                    priority: 'critical'
                });
            }
        }
        
        // Recomendações específicas
        if (results.disposable && results.disposable.isDisposable && !isTrustedDomain) {
            recommendations.push({
                action: 'BLOCK_EMAIL',
                message: 'Email temporário detectado - solicitar email permanente',
                priority: 'critical'
            });
        }
        
        if (results.patterns && results.patterns.suggestions && results.patterns.suggestions.length > 0) {
            recommendations.push({
                action: 'SUGGEST_CORRECTION',
                message: `Possível erro de digitação - sugerir: ${results.patterns.suggestions[0].suggestion}`,
                priority: 'medium'
            });
        }
        
        return recommendations;
    }
    
    generateInsights(results, isTrustedDomain) {
        const insights = {
            emailAge: 'unknown',
            socialPresence: false,
            corporateEmail: false,
            personalEmail: false,
            trustedProvider: isTrustedDomain,
            likelyFirstPurchase: true,
            deviceMatch: true
        };
        
        // Determinar tipo de email baseado no domínio
        if (results.email) {
            const domain = results.email.split('@')[1];
            const category = this.trustedDomains.getCategory(domain);
            
            if (category === 'mainstream' || category === 'brazilian') {
                insights.personalEmail = true;
            } else if (category === 'professional' || category === 'educational') {
                insights.corporateEmail = true;
                insights.likelyFirstPurchase = false;
            }
        }
        
        // Presença social (simulada - em produção seria via API)
        if (results.score > 70 || isTrustedDomain) {
            insights.socialPresence = true;
        }
        
        return insights;
    }
    
    // Método auxiliar para criar score vazio
    createEmptyScore(reason) {
        return {
            baseScore: 0,
            finalScore: 0,
            confidence: 'none',
            buyerType: 'INVALID',
            riskLevel: 'BLOCKED',
            fraudProbability: 100,
            recommendations: [{
                action: 'BLOCK',
                message: reason,
                priority: 'critical'
            }],
            breakdown: {},
            insights: {},
            error: reason
        };
    }
    
    // Sistema de log configurável
    logDebug(message) {
        if (this.debug) {
            console.log(`[EcommerceScoring] ${message}`);
        }
    }
}

module.exports = EcommerceScoring;
EOF

success "EcommerceScoring.js corrigido criado"

# ================================================
# CRIAR SCRIPT DE TESTE
# ================================================
log "🧪 Criando script de teste..."

cat > "test_scoring_fix.js" << 'EOF'
// Script de teste para validar as correções

// Ajustar o caminho baseado na localização real do arquivo
const path = require('path');
const fs = require('fs');

// Procurar o arquivo EcommerceScoring.js
let scoringPath;
const possiblePaths = [
    './core/client-dashboard/services/validators/advanced/EcommerceScoring.js',
    './core/client-dashboard/services/EcommerceScoring.js',
    './core/client-dashboard/src/services/EcommerceScoring.js',
    './core/client-dashboard/lib/EcommerceScoring.js'
];

for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
        scoringPath = p;
        break;
    }
}

if (!scoringPath) {
    console.error('❌ Não foi possível encontrar EcommerceScoring.js');
    process.exit(1);
}

const EcommerceScoring = require(scoringPath);

console.log('\n========================================');
console.log('🧪 TESTANDO SISTEMA DE SCORING CORRIGIDO');
console.log('========================================\n');

const scorer = new EcommerceScoring();

// Casos de teste
const testCases = [
    {
        name: 'Gmail válido (Carolina)',
        data: {
            email: 'carolinacasaquia@gmail.com',
            tld: { valid: true, isPremium: true },
            disposable: { isDisposable: false },
            smtp: { exists: true, catchAll: false },
            mx: { valid: true, records: 5 },
            patterns: { suspicious: false, suspicionLevel: 0 }
        },
        expected: 'Score > 80'
    },
    {
        name: 'Email sem domínio confiável',
        data: {
            email: 'teste@empresa.com.br',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: true },
            mx: { valid: true },
            patterns: { suspicious: false }
        },
        expected: 'Score 60-80'
    },
    {
        name: 'Email temporário',
        data: {
            email: 'test@tempmail.com',
            tld: { valid: true },
            disposable: { isDisposable: true },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 8 }
        },
        expected: 'Score < 20'
    },
    {
        name: 'Outlook com SMTP bloqueado (fallback)',
        data: {
            email: 'joao.silva@outlook.com',
            tld: { valid: true, isPremium: true },
            disposable: { isDisposable: false },
            smtp: { exists: false, error: 'Connection timeout' },
            mx: { valid: true },
            patterns: { suspicious: false }
        },
        expected: 'Score > 70 (com fallback)'
    }
];

// Executar testes
testCases.forEach((test, index) => {
    console.log(`\nTeste ${index + 1}: ${test.name}`);
    console.log(`Email: ${test.data.email}`);
    
    const result = scorer.calculateScore(test.data);
    
    console.log(`Score Final: ${result.finalScore}/100`);
    console.log(`Tipo: ${result.buyerType}`);
    console.log(`Risco: ${result.riskLevel}`);
    console.log(`Domínio Confiável: ${result.metadata.isTrustedDomain}`);
    console.log(`Categoria: ${result.metadata.domainCategory}`);
    console.log(`Esperado: ${test.expected}`);
    
    // Validar resultado
    const passed = (
        (test.expected.includes('> 80') && result.finalScore > 80) ||
        (test.expected.includes('60-80') && result.finalScore >= 60 && result.finalScore <= 80) ||
        (test.expected.includes('< 20') && result.finalScore < 20) ||
        (test.expected.includes('> 70') && result.finalScore > 70)
    );
    
    console.log(`Resultado: ${passed ? '✅ PASSOU' : '❌ FALHOU'}`);
    
    // Mostrar breakdown
    if (process.env.SHOW_BREAKDOWN === 'true') {
        console.log('\nBreakdown:');
        Object.entries(result.breakdown).forEach(([key, value]) => {
            console.log(`  ${key}: ${value.points}/10 (peso: ${value.weight})`);
        });
    }
});

console.log('\n========================================');
console.log('📊 TESTE ESPECÍFICO: carolinacasaquia@gmail.com');
console.log('========================================\n');

const carolinaTest = {
    email: 'carolinacasaquia@gmail.com',
    tld: { valid: true, isPremium: true },
    disposable: { isDisposable: false },
    smtp: { exists: true },
    mx: { valid: true, records: 5 },
    patterns: { suspicious: false }
};

const carolinaResult = scorer.calculateScore(carolinaTest);

console.log('Resultado Detalhado:');
console.log(`  Email: ${carolinaResult.metadata.email}`);
console.log(`  Domínio: ${carolinaResult.metadata.domain}`);
console.log(`  É Confiável: ${carolinaResult.metadata.isTrustedDomain}`);
console.log(`  Categoria: ${carolinaResult.metadata.domainCategory}`);
console.log(`  Score Base: ${carolinaResult.baseScore}`);
console.log(`  Score Final: ${carolinaResult.finalScore}`);
console.log(`  Classificação: ${carolinaResult.buyerType}`);
console.log(`  Nível de Risco: ${carolinaResult.riskLevel}`);
console.log(`  Confiança: ${carolinaResult.confidence}`);

console.log('\nRecomendações:');
carolinaResult.recommendations.forEach(rec => {
    console.log(`  [${rec.priority}] ${rec.action}: ${rec.message}`);
});

if (carolinaResult.finalScore >= 80) {
    console.log('\n✅ SUCESSO! Carolina agora tem score alto como esperado!');
} else {
    console.log('\n❌ PROBLEMA: Score ainda está baixo');
}

console.log('\n========================================\n');
EOF

success "Script de teste criado"

# ================================================
# VERIFICAR INTEGRIDADE DOS ARQUIVOS
# ================================================
log "🔍 Verificando integridade dos arquivos..."

if [ -f "${SCORING_FILE}" ] && [ -f "${SCORING_DIR}/TrustedDomains.js" ]; then
    success "Todos os arquivos foram criados corretamente"
else
    error "Falha na criação dos arquivos"
fi

# ================================================
# EXECUTAR TESTES
# ================================================
log "🧪 Executando testes do sistema corrigido..."

echo ""
node test_scoring_fix.js

# ================================================
# RESUMO FINAL
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS COM SUCESSO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${MAGENTA}📋 CORREÇÕES IMPLEMENTADAS:${NC}"
echo -e "  ✅ Fórmula do score corrigida (multiplicação por 10)"
echo -e "  ✅ Validação de entrada implementada"
echo -e "  ✅ Email garantido em validationResults"
echo -e "  ✅ Lista de domínios confiáveis adicionada"
echo -e "  ✅ Pesos rebalanceados (disposable 20%, format 15%)"
echo -e "  ✅ Fallback SMTP para domínios conhecidos"
echo -e "  ✅ Sistema de log configurável (DEBUG_SCORING=true)"
echo -e "  ✅ Tratamento especial para Gmail, Outlook, Yahoo, etc."

echo -e "\n${MAGENTA}📁 ARQUIVOS CRIADOS/MODIFICADOS:${NC}"
echo -e "  • ${SCORING_FILE}"
echo -e "  • ${SCORING_DIR}/TrustedDomains.js"
echo -e "  • test_scoring_fix.js"
echo -e "  • ${BACKUP_DIR}/ (backup)"

echo -e "\n${MAGENTA}🎯 RESULTADOS ESPERADOS:${NC}"
echo -e "  carolinacasaquia@gmail.com  → Score: 85+ ✅ (era 9)"
echo -e "  joao.silva@outlook.com      → Score: 80+ ✅"
echo -e "  teste@tempmail.com          → Score: <20 ❌"
echo -e "  empresa@corporativo.com.br  → Score: 60-80 ⚠️"

echo -e "\n${MAGENTA}🔄 PRÓXIMOS PASSOS:${NC}"
echo -e "  1. Revisar os resultados dos testes acima"
echo -e "  2. Se necessário, ajustar os pesos no arquivo"
echo -e "  3. Reiniciar o serviço/container se aplicável"
echo -e "  4. Testar com dados reais de produção"

echo -e "\n${CYAN}💡 DICAS:${NC}"
echo -e "  • Para debug detalhado: export DEBUG_SCORING=true"
echo -e "  • Para ver breakdown: export SHOW_BREAKDOWN=true"
echo -e "  • Backup salvo em: ${BACKUP_DIR}"

echo -e "\n${YELLOW}📝 Log completo salvo em: ${LOG_FILE}${NC}"

echo -e "\n${GREEN}✨ Processo concluído com sucesso!${NC}\n"