#!/bin/bash

# ================================================
# ENHANCE VALIDATION SYSTEM - SPARK NEXUS
# Adiciona validações mais rigorosas ao sistema
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
║         SPARK NEXUS - VALIDATION ENHANCEMENT v3.0            ║
║          Sistema de Validação Ultra Rigoroso                 ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="validation_enhancement_${TIMESTAMP}.log"

# Funções de log
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# ================================================
# VERIFICAR ESTRUTURA
# ================================================
log "🔍 Verificando estrutura do projeto..."

if [ ! -d "core/client-dashboard" ]; then
    error "Execute este script na raiz do spark-nexus!"
fi

# Localizar diretório dos validadores
VALIDATORS_DIR="core/client-dashboard/services/validators/advanced"

if [ ! -d "$VALIDATORS_DIR" ]; then
    log "Criando diretório de validadores..."
    mkdir -p "$VALIDATORS_DIR"
fi

success "Estrutura verificada"

# ================================================
# BACKUP
# ================================================
log "💾 Criando backup..."

BACKUP_DIR="backups/validation_enhancement_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

if [ -f "${VALIDATORS_DIR}/EcommerceScoring.js" ]; then
    cp "${VALIDATORS_DIR}/EcommerceScoring.js" "$BACKUP_DIR/"
fi

if [ -f "${VALIDATORS_DIR}/BlockedDomains.js" ]; then
    cp "${VALIDATORS_DIR}/BlockedDomains.js" "$BACKUP_DIR/"
fi

success "Backup criado em: $BACKUP_DIR"

# ================================================
# CRIAR MÓDULO DE DOMÍNIOS BLOQUEADOS
# ================================================
log "🚫 Criando módulo de domínios bloqueados..."

cat > "${VALIDATORS_DIR}/BlockedDomains.js" << 'EOF'
// ================================================
// Blocked Domains Module - v3.0
// Lista abrangente de domínios bloqueados e suspeitos
// ================================================

class BlockedDomains {
    constructor() {
        // Domínios de teste/exemplo - SEMPRE bloquear
        this.testDomains = [
            'example.com', 'example.org', 'example.net',
            'test.com', 'test.org', 'test.net',
            'teste.com', 'teste.com.br',
            'testing.com', 'testmail.com',
            'sample.com', 'demo.com',
            'foo.com', 'bar.com', 'foobar.com',
            'domain.com', 'email.com', 'mail.com',
            'company.com', 'empresa.com',
            'localhost', 'local', 'invalid'
        ];
        
        // Domínios temporários/descartáveis conhecidos
        this.disposableDomains = [
            // 10 minute mail variants
            '10minutemail.com', '10minutemail.net', '10minemail.com',
            '10minutemail.de', '10minutemail.be', '10minutemail.info',
            
            // Temp mail variants
            'tempmail.com', 'temp-mail.org', 'temp-mail.com',
            'tempmail.net', 'tempmail.de', 'temporarymail.com',
            'tmpmail.com', 'tmpmail.net', 'tmp-mail.com',
            
            // Disposable variants
            'disposable.com', 'disposablemail.com', 'dispose.it',
            'disposable-email.com', 'throwaway.com', 'throwawaymail.com',
            
            // Guerrilla mail
            'guerrillamail.com', 'guerrillamail.net', 'guerrillamail.org',
            'guerrillamail.biz', 'guerrillamail.de',
            
            // Mailinator variants
            'mailinator.com', 'mailinator.net', 'mailinator.org',
            'mailinator2.com', 'mailinater.com',
            
            // Yopmail
            'yopmail.com', 'yopmail.net', 'yopmail.fr',
            
            // Fake inbox
            'fakeinbox.com', 'fakeinbox.net', 'fakebox.org',
            'fakemailbox.com', 'fakemail.com',
            
            // Trash mail
            'trashmail.com', 'trash-mail.com', 'trashmail.net',
            'trashmail.de', 'trashmail.org',
            
            // Get air mail
            'getairmail.com', 'getairmail.net',
            
            // Email on deck
            'emailondeck.com',
            
            // Mint email
            'mintemail.com', 'mintmail.com',
            
            // Spam variants
            'spambox.us', 'spam.la', 'spamgourmet.com',
            'spamhole.com', 'spamify.com',
            
            // Other common disposables
            'sharklasers.com', 'grr.la', 'mailnesia.com',
            'emailsensei.com', 'imgof.com', 'letthemeatspam.com',
            'mt2009.com', 'thankyou2010.com', 'trash2009.com',
            'mt2014.com', 'mt2015.com', 'binkmail.com',
            'bobmail.info', 'chammy.info', 'choicemail1.com',
            'donemail.ru', 'dontreg.com', 'e4ward.com',
            'emailias.com', 'emailwarden.com', 'fastacura.com',
            'fastchevy.com', 'fastchrysler.com', 'fastkawasaki.com',
            'fastmazda.com', 'fastmitsubishi.com', 'fastnissan.com',
            'fastsubaru.com', 'fastsuzuki.com', 'fasttoyota.com',
            'fastyamaha.com', 'gishpuppy.com', 'goemailgo.com',
            'gotmail.com', 'gotmail.net', 'gotmail.org',
            'haltospam.com', 'hotpop.com', 'incognitomail.com',
            'ipoo.org', 'irish2me.com', 'jetable.com',
            'jetable.net', 'jetable.org', 'kasmail.com',
            'kaspop.com', 'keepmymail.com', 'killmail.com',
            'killmail.net', 'kir.ch.tc', 'klassmaster.com',
            'klzlk.com', 'koszmail.pl', 'kulturbetrieb.info',
            'kurzepost.de', 'lifebyfood.com', 'link2mail.net',
            'litedrop.com', 'lol.ovpn.to', 'lookugly.com',
            'lopl.co.cc', 'lovemyemail.com', 'lr78.com',
            'maboard.com', 'mail.by', 'mail.mezimages.net',
            'mail2rss.org', 'mailbidon.com', 'mailblocks.com',
            'mailcatch.com', 'maildrop.cc', 'maildx.com',
            'maileater.com', 'mailexpire.com', 'mailfa.tk',
            'mailforspam.com', 'mailfreeonline.com', 'mailimate.com',
            'mailin8r.com', 'mailinblack.com', 'mailincubator.com'
        ];
        
        // Palavras-chave suspeitas em domínios
        this.suspiciousKeywords = [
            'temp', 'tmp', 'disposable', 'throwaway',
            'trash', 'fake', 'spam', 'junk',
            'minute', 'hour', 'temporary', 'burner',
            'anonymous', 'hide', 'masked', 'guerrilla'
        ];
        
        // Padrões de email genérico/suspeito (local part)
        this.genericLocalParts = [
            'test', 'teste', 'testing', 'tester',
            'admin', 'administrator', 'root', 'webmaster',
            'info', 'contact', 'support', 'sales',
            'noreply', 'no-reply', 'donotreply',
            'user', 'usuario', 'client', 'cliente',
            'demo', 'sample', 'example', 'default',
            'mail', 'email', 'contact', 'enquiry',
            'fake', 'temp', 'temporary', 'disposable',
            'asdf', 'asdfasdf', 'qwerty', 'qwertyuiop',
            'abc', 'abc123', '123', 'test123',
            'aaa', 'aaaa', 'xxx', 'zzz'
        ];
        
        // Cache para performance
        this.cache = new Map();
    }
    
    isBlocked(email) {
        if (!email) return { blocked: true, reason: 'Email vazio' };
        
        email = email.toLowerCase().trim();
        
        // Verificar cache
        if (this.cache.has(email)) {
            return this.cache.get(email);
        }
        
        const [localPart, domain] = email.split('@');
        
        if (!domain) {
            const result = { blocked: true, reason: 'Formato inválido' };
            this.cache.set(email, result);
            return result;
        }
        
        // 1. Verificar domínios de teste
        if (this.testDomains.includes(domain)) {
            const result = { 
                blocked: true, 
                reason: 'Domínio de teste/exemplo',
                category: 'test_domain',
                severity: 'critical'
            };
            this.cache.set(email, result);
            return result;
        }
        
        // 2. Verificar domínios descartáveis
        if (this.disposableDomains.includes(domain)) {
            const result = { 
                blocked: true, 
                reason: 'Email temporário/descartável',
                category: 'disposable',
                severity: 'high'
            };
            this.cache.set(email, result);
            return result;
        }
        
        // 3. Verificar subdomínios de descartáveis
        for (const disposable of this.disposableDomains) {
            if (domain.endsWith('.' + disposable)) {
                const result = { 
                    blocked: true, 
                    reason: 'Subdomínio de email temporário',
                    category: 'disposable_subdomain',
                    severity: 'high'
                };
                this.cache.set(email, result);
                return result;
            }
        }
        
        // 4. Verificar palavras-chave suspeitas no domínio
        for (const keyword of this.suspiciousKeywords) {
            if (domain.includes(keyword)) {
                const result = { 
                    blocked: true, 
                    reason: `Domínio suspeito (contém "${keyword}")`,
                    category: 'suspicious_domain',
                    severity: 'medium'
                };
                this.cache.set(email, result);
                return result;
            }
        }
        
        // 5. Verificar local part genérico/suspeito
        if (this.genericLocalParts.includes(localPart)) {
            // Não bloquear completamente, mas marcar como suspeito
            const result = { 
                blocked: false, 
                suspicious: true,
                reason: `Email genérico (${localPart}@)`,
                category: 'generic_email',
                severity: 'low',
                penaltyScore: 30 // Penalidade no score
            };
            this.cache.set(email, result);
            return result;
        }
        
        // 6. Verificar padrões suspeitos
        if (this.isSuspiciousPattern(localPart, domain)) {
            const result = { 
                blocked: false,
                suspicious: true,
                reason: 'Padrão suspeito detectado',
                category: 'suspicious_pattern',
                severity: 'low',
                penaltyScore: 20
            };
            this.cache.set(email, result);
            return result;
        }
        
        // Email passou em todas as verificações
        const result = { 
            blocked: false, 
            suspicious: false,
            reason: null,
            category: 'clean'
        };
        this.cache.set(email, result);
        return result;
    }
    
    isSuspiciousPattern(localPart, domain) {
        // Muitos números consecutivos
        if (/\d{5,}/.test(localPart)) return true;
        
        // Caracteres repetidos excessivamente
        if (/(.)\1{3,}/.test(localPart)) return true;
        
        // Começa ou termina com números
        if (/^\d+/.test(localPart) || /\d+$/.test(localPart)) return true;
        
        // Domínio muito curto (menos de 4 caracteres antes do TLD)
        const domainName = domain.split('.')[0];
        if (domainName && domainName.length < 4) return true;
        
        // Muitos hífens ou underscores
        if ((localPart.match(/[-_]/g) || []).length > 2) return true;
        
        return false;
    }
    
    // Método para adicionar domínios customizados
    addBlockedDomain(domain, category = 'custom') {
        domain = domain.toLowerCase().trim();
        
        if (category === 'test') {
            this.testDomains.push(domain);
        } else if (category === 'disposable') {
            this.disposableDomains.push(domain);
        }
        
        // Limpar cache
        this.cache.clear();
    }
    
    getStatistics() {
        return {
            testDomains: this.testDomains.length,
            disposableDomains: this.disposableDomains.length,
            totalBlocked: this.testDomains.length + this.disposableDomains.length,
            cacheSize: this.cache.size
        };
    }
}

module.exports = BlockedDomains;
EOF

success "Módulo BlockedDomains.js criado"

# ================================================
# ATUALIZAR ECOMMERCESCORING PARA USAR BLOCKED DOMAINS
# ================================================
log "🔧 Atualizando EcommerceScoring.js..."

cat > "${VALIDATORS_DIR}/EcommerceScoring_Enhanced.js" << 'EOF'
// ================================================
// E-commerce Scoring System - ENHANCED v3.0
// Sistema com validações ultra rigorosas
// ================================================

const TrustedDomains = require('./TrustedDomains');
const BlockedDomains = require('./BlockedDomains');

class EcommerceScoring {
    constructor() {
        // Pesos ajustados para validação mais rigorosa
        this.weights = {
            domainBlocked: 30,      // NOVO - peso alto para domínios bloqueados
            tldScore: 10,
            disposableCheck: 20,
            smtpVerification: 15,
            patternAnalysis: 10,
            formatQuality: 10,
            domainTrust: 5
        };
        
        // Threshold mais rigoroso
        this.scoreThreshold = {
            invalid: 50,        // < 50 = Inválido
            suspicious: 70,     // 50-69 = Suspeito
            valid: 70          // >= 70 = Válido
        };
        
        // Inicializar módulos
        this.trustedDomains = new TrustedDomains();
        this.blockedDomains = new BlockedDomains();
        
        this.debug = process.env.DEBUG_SCORING === 'true';
    }
    
    calculateScore(validationResults) {
        // Validação de entrada
        if (!validationResults || typeof validationResults !== 'object') {
            return this.createEmptyScore('Invalid input');
        }
        
        const email = validationResults.email || '';
        const domain = email.split('@')[1] || '';
        
        // PRIMEIRO: Verificar se está bloqueado
        const blockCheck = this.blockedDomains.isBlocked(email);
        
        if (blockCheck.blocked) {
            this.logDebug(`Email bloqueado: ${email} - Razão: ${blockCheck.reason}`);
            return {
                baseScore: 0,
                finalScore: 0,
                valid: false,
                confidence: 'certain',
                buyerType: 'BLOCKED',
                riskLevel: 'BLOCKED',
                fraudProbability: 100,
                recommendations: [{
                    action: 'BLOCK',
                    message: blockCheck.reason,
                    priority: 'critical'
                }],
                breakdown: {
                    blocked: {
                        reason: blockCheck.reason,
                        category: blockCheck.category,
                        severity: blockCheck.severity
                    }
                },
                insights: {
                    blocked: true,
                    blockReason: blockCheck.reason
                },
                metadata: {
                    email: email,
                    domain: domain,
                    isBlocked: true,
                    blockCategory: blockCheck.category
                }
            };
        }
        
        const scoreData = {
            baseScore: 0,
            finalScore: 0,
            valid: false,
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
                domainCategory: 'unknown',
                suspicious: blockCheck.suspicious || false
            }
        };
        
        // Verificar se é domínio confiável
        const isTrustedDomain = this.trustedDomains.isTrusted(domain);
        const domainCategory = this.trustedDomains.getCategory(domain);
        
        scoreData.metadata.isTrustedDomain = isTrustedDomain;
        scoreData.metadata.domainCategory = domainCategory;
        
        // Calcular score
        let totalScore = 0;
        let totalWeight = 0;
        
        // Penalidade se for suspeito
        if (blockCheck.suspicious) {
            const penalty = blockCheck.penaltyScore || 20;
            totalScore -= penalty * 3; // Penalidade tripla
            scoreData.breakdown.suspicious = {
                penalty: penalty,
                reason: blockCheck.reason
            };
        }
        
        // 1. Domain Trust Score
        const domainTrustPoints = isTrustedDomain ? 10 : 
                                  blockCheck.suspicious ? 2 : 5;
        totalScore += domainTrustPoints * this.weights.domainTrust;
        totalWeight += this.weights.domainTrust;
        scoreData.breakdown.domainTrust = {
            points: domainTrustPoints,
            weight: this.weights.domainTrust,
            weighted: domainTrustPoints * this.weights.domainTrust
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
        
        // 3. Disposable Check - MAIS RIGOROSO
        if (validationResults.disposable) {
            const disposablePoints = this.calculateDisposablePoints(
                validationResults.disposable, 
                isTrustedDomain,
                domain
            );
            totalScore += disposablePoints * this.weights.disposableCheck;
            totalWeight += this.weights.disposableCheck;
            scoreData.breakdown.disposable = {
                points: disposablePoints,
                weight: this.weights.disposableCheck,
                weighted: disposablePoints * this.weights.disposableCheck
            };
        }
        
        // 4. SMTP Verification
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
        
        // 5. Pattern Analysis - MAIS RIGOROSO
        if (validationResults.patterns) {
            const patternPoints = this.calculatePatternPoints(
                validationResults.patterns,
                blockCheck.suspicious
            );
            totalScore += patternPoints * this.weights.patternAnalysis;
            totalWeight += this.weights.patternAnalysis;
            scoreData.breakdown.patterns = {
                points: patternPoints,
                weight: this.weights.patternAnalysis,
                weighted: patternPoints * this.weights.patternAnalysis
            };
        }
        
        // 6. Format Quality
        const formatPoints = this.calculateFormatPoints(email, blockCheck.suspicious);
        totalScore += formatPoints * this.weights.formatQuality;
        totalWeight += this.weights.formatQuality;
        scoreData.breakdown.format = {
            points: formatPoints,
            weight: this.weights.formatQuality,
            weighted: formatPoints * this.weights.formatQuality
        };
        
        // Calcular score final
        if (totalWeight > 0) {
            scoreData.baseScore = Math.round((totalScore / totalWeight) * 10);
        } else {
            scoreData.baseScore = 0;
        }
        
        // Boost apenas para domínios MUITO confiáveis
        if (isTrustedDomain && domainCategory === 'mainstream' && scoreData.baseScore < 70) {
            scoreData.baseScore = Math.min(scoreData.baseScore + 15, 75);
        }
        
        // Garantir que emails suspeitos nunca tenham score alto
        if (blockCheck.suspicious && scoreData.baseScore > 60) {
            scoreData.baseScore = 60;
        }
        
        scoreData.finalScore = Math.max(0, Math.min(100, scoreData.baseScore));
        
        // Determinar validade baseado no threshold
        scoreData.valid = scoreData.finalScore >= this.scoreThreshold.valid;
        
        // Classificações
        scoreData.buyerType = this.classifyBuyer(scoreData.finalScore, blockCheck.suspicious);
        scoreData.riskLevel = this.assessRisk(scoreData.finalScore);
        scoreData.fraudProbability = this.calculateFraudProbability(
            scoreData.finalScore, 
            validationResults, 
            isTrustedDomain,
            blockCheck.suspicious
        );
        scoreData.confidence = this.determineConfidence(scoreData.finalScore);
        
        // Recomendações
        scoreData.recommendations = this.generateRecommendations(
            scoreData.finalScore, 
            validationResults,
            isTrustedDomain,
            blockCheck
        );
        
        // Insights
        scoreData.insights = this.generateInsights(
            validationResults, 
            isTrustedDomain,
            blockCheck
        );
        
        this.logDebug(`Score final para ${email}: ${scoreData.finalScore} - Válido: ${scoreData.valid}`);
        
        return scoreData;
    }
    
    calculateTLDPoints(tldResult, isTrustedDomain) {
        if (isTrustedDomain) return 10;
        if (tldResult.isBlocked) return 0;
        if (tldResult.isSuspicious) return 2;
        if (tldResult.isPremium) return 10;
        if (tldResult.valid) return 6;
        return 0;
    }
    
    calculateDisposablePoints(disposableResult, isTrustedDomain, domain) {
        if (isTrustedDomain) return 10;
        
        // Verificação adicional para domínios suspeitos
        if (domain) {
            const suspiciousKeywords = ['temp', 'trash', 'disposable', 'fake', 'minute'];
            for (const keyword of suspiciousKeywords) {
                if (domain.includes(keyword)) {
                    return 0;
                }
            }
        }
        
        if (disposableResult.isDisposable) return 0;
        return 10;
    }
    
    calculateSMTPPoints(smtpResult, isTrustedDomain) {
        if (isTrustedDomain && !smtpResult.exists && smtpResult.error) {
            return 7; // Fallback para domínios confiáveis
        }
        
        if (!smtpResult.smtp) return 3;
        if (smtpResult.exists && !smtpResult.catchAll) return 10;
        if (smtpResult.catchAll) return 5;
        if (!smtpResult.exists) return 0;
        return 3;
    }
    
    calculatePatternPoints(patternResult, isSuspicious) {
        let points = 10;
        
        if (patternResult.suspicious) {
            points = Math.max(0, 10 - patternResult.suspicionLevel);
        }
        
        // Penalidade adicional se já foi marcado como suspeito
        if (isSuspicious) {
            points = Math.max(0, points - 3);
        }
        
        return points;
    }
    
    calculateFormatPoints(email, isSuspicious) {
        if (!email || typeof email !== 'string') return 0;
        
        const parts = email.split('@');
        if (parts.length !== 2) return 0;
        
        const localPart = parts[0].toLowerCase();
        
        // Penalizar emails genéricos
        const genericPrefixes = ['test', 'admin', 'user', 'info', 'contact', 'support'];
        for (const prefix of genericPrefixes) {
            if (localPart === prefix || localPart.startsWith(prefix)) {
                return isSuspicious ? 0 : 2;
            }
        }
        
        // Formato profissional
        if (/^[a-z]+\.[a-z]+$/.test(localPart)) return 10;
        
        // Formato corporativo
        if (/^[a-z]+[._-][a-z]+$/.test(localPart)) return 8;
        
        // Nome completo
        if (/^[a-z]{4,20}$/.test(localPart)) return 6;
        
        // Com números moderados
        if (/^[a-z]+[0-9]{1,3}$/.test(localPart)) return 4;
        
        // Muitos números ou caracteres especiais
        if (/[0-9]{4,}/.test(localPart)) return 1;
        
        return 3;
    }
    
    classifyBuyer(score, isSuspicious) {
        if (isSuspicious) {
            return score >= 70 ? 'SUSPICIOUS_BUYER' : 'HIGH_RISK_BUYER';
        }
        
        if (score >= 80) return 'TRUSTED_BUYER';
        if (score >= 70) return 'REGULAR_BUYER';
        if (score >= 60) return 'NEW_BUYER';
        if (score >= 50) return 'SUSPICIOUS_BUYER';
        return 'HIGH_RISK_BUYER';
    }
    
    assessRisk(score) {
        if (score >= 80) return 'VERY_LOW';
        if (score >= 70) return 'LOW';
        if (score >= 60) return 'MEDIUM';
        if (score >= 50) return 'HIGH';
        return 'VERY_HIGH';
    }
    
    calculateFraudProbability(score, results, isTrustedDomain, isSuspicious) {
        let probability = 100 - score;
        
        if (isTrustedDomain) {
            probability = Math.max(5, probability - 20);
        }
        
        if (isSuspicious) {
            probability = Math.min(95, probability + 30);
        }
        
        if (results.disposable && results.disposable.isDisposable) {
            probability = Math.min(95, probability + 25);
        }
        
        if (results.smtp && !results.smtp.exists) {
            probability = Math.min(95, probability + 15);
        }
        
        return Math.min(95, Math.max(5, probability));
    }
    
    determineConfidence(score) {
        if (score >= 80) return 'very_high';
        if (score >= 70) return 'high';
        if (score >= 60) return 'medium';
        if (score >= 50) return 'low';
        return 'very_low';
    }
    
    generateRecommendations(score, results, isTrustedDomain, blockCheck) {
        const recommendations = [];
        
        if (blockCheck.suspicious) {
            recommendations.push({
                action: 'WARNING',
                message: `Email suspeito: ${blockCheck.reason}`,
                priority: 'high'
            });
        }
        
        if (score >= 70) {
            recommendations.push({
                action: 'APPROVE',
                message: 'Email válido - aprovar com monitoramento padrão',
                priority: 'low'
            });
        } else if (score >= 50) {
            recommendations.push({
                action: 'MANUAL_REVIEW',
                message: 'Email duvidoso - revisar manualmente',
                priority: 'high'
            });
            recommendations.push({
                action: 'REQUEST_VERIFICATION',
                message: 'Solicitar verificação adicional via SMS',
                priority: 'high'
            });
        } else {
            recommendations.push({
                action: 'REJECT',
                message: 'Email inválido ou de alto risco - rejeitar',
                priority: 'critical'
            });
            recommendations.push({
                action: 'SUGGEST_ALTERNATIVE',
                message: 'Solicitar email alternativo válido',
                priority: 'critical'
            });
        }
        
        return recommendations;
    }
    
    generateInsights(results, isTrustedDomain, blockCheck) {
        return {
            trustedProvider: isTrustedDomain,
            suspicious: blockCheck.suspicious || false,
            blockReason: blockCheck.reason || null,
            requiresVerification: results.score < 70,
            riskFactors: []
        };
    }
    
    createEmptyScore(reason) {
        return {
            baseScore: 0,
            finalScore: 0,
            valid: false,
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
    
    logDebug(message) {
        if (this.debug) {
            console.log(`[EcommerceScoring] ${message}`);
        }
    }
}

module.exports = EcommerceScoring;
EOF

success "EcommerceScoring_Enhanced.js criado"

# ================================================
# CRIAR SCRIPT DE TESTE RIGOROSO
# ================================================
log "🧪 Criando script de teste rigoroso..."

cat > "test_enhanced_validation.js" << 'EOF'
// ================================================
// TESTE DO SISTEMA ENHANCED DE VALIDAÇÃO
// ================================================

const path = require('path');
const fs = require('fs');

// Localizar o arquivo
const scoringPath = './core/client-dashboard/services/validators/advanced/EcommerceScoring_Enhanced.js';

if (!fs.existsSync(scoringPath)) {
    console.error('❌ Arquivo EcommerceScoring_Enhanced.js não encontrado!');
    process.exit(1);
}

const EcommerceScoring = require(scoringPath);
const scorer = new EcommerceScoring();

console.log('\n========================================');
console.log('🧪 TESTE DO SISTEMA ENHANCED DE VALIDAÇÃO');
console.log('========================================\n');

// Casos de teste que devem ser BLOQUEADOS ou ter score baixo
const testCases = [
    // DEVEM SER BLOQUEADOS (Score 0)
    {
        name: 'Domínio example.com',
        email: 'test@example.com',
        data: {
            email: 'test@example.com',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: false },
            patterns: { suspicious: false }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    {
        name: 'Email temporário (tempmail)',
        email: 'admin@tempmail.com',
        data: {
            email: 'admin@tempmail.com',
            tld: { valid: true },
            disposable: { isDisposable: true },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 8 }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    {
        name: '10minutemail',
        email: 'support@10minutemail.com',
        data: {
            email: 'support@10minutemail.com',
            tld: { valid: true },
            disposable: { isDisposable: true },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 8 }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    {
        name: 'Domínio fake (company.com)',
        email: 'user@company.com',
        data: {
            email: 'user@company.com',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: false },
            patterns: { suspicious: false }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    {
        name: 'Disposable óbvio',
        email: 'info@disposable.com',
        data: {
            email: 'info@disposable.com',
            tld: { valid: true },
            disposable: { isDisposable: true },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 9 }
        },
        expectedValid: false,
        expectedMaxScore: 0
    },
    
    // DEVEM TER SCORE BAIXO (< 50)
    {
        name: 'Email genérico suspeito',
        email: 'test123@randomdomain.net',
        data: {
            email: 'test123@randomdomain.net',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: false },
            patterns: { suspicious: true, suspicionLevel: 6 }
        },
        expectedValid: false,
        expectedMaxScore: 50
    },
    
    // EMAILS VÁLIDOS (Score > 70)
    {
        name: 'Gmail válido (Carolina)',
        email: 'carolinacasaquia@gmail.com',
        data: {
            email: 'carolinacasaquia@gmail.com',
            tld: { valid: true, isPremium: true },
            disposable: { isDisposable: false },
            smtp: { exists: true },
            patterns: { suspicious: false }
        },
        expectedValid: true,
        expectedMinScore: 70
    },
    {
        name: 'Outlook válido',
        email: 'real.person@outlook.com',
        data: {
            email: 'real.person@outlook.com',
            tld: { valid: true, isPremium: true },
            disposable: { isDisposable: false },
            smtp: { exists: true },
            patterns: { suspicious: false }
        },
        expectedValid: true,
        expectedMinScore: 70
    },
    {
        name: 'Email corporativo brasileiro',
        email: 'contato@empresa.com.br',
        data: {
            email: 'contato@empresa.com.br',
            tld: { valid: true },
            disposable: { isDisposable: false },
            smtp: { exists: true, catchAll: true },
            patterns: { suspicious: false }
        },
        expectedValid: true,
        expectedMinScore: 60
    }
];

// Executar testes
let passed = 0;
let failed = 0;

testCases.forEach((test, index) => {
    console.log(`\n${index + 1}. ${test.name}`);
    console.log(`   Email: ${test.email}`);
    
    const result = scorer.calculateScore(test.data);
    
    console.log(`   Score: ${result.finalScore}/100`);
    console.log(`   Válido: ${result.valid ? '✅' : '❌'}`);
    console.log(`   Classificação: ${result.buyerType}`);
    console.log(`   Risco: ${result.riskLevel}`);
    
    // Verificar se passou no teste
    let testPassed = true;
    
    if (test.expectedValid !== undefined) {
        if (result.valid !== test.expectedValid) {
            testPassed = false;
            console.log(`   ❌ FALHOU: Esperado válido=${test.expectedValid}, obteve ${result.valid}`);
        }
    }
    
    if (test.expectedMaxScore !== undefined) {
        if (result.finalScore > test.expectedMaxScore) {
            testPassed = false;
            console.log(`   ❌ FALHOU: Score máximo esperado ${test.expectedMaxScore}, obteve ${result.finalScore}`);
        }
    }
    
    if (test.expectedMinScore !== undefined) {
        if (result.finalScore < test.expectedMinScore) {
            testPassed = false;
            console.log(`   ❌ FALHOU: Score mínimo esperado ${test.expectedMinScore}, obteve ${result.finalScore}`);
        }
    }
    
    if (testPassed) {
        console.log(`   ✅ PASSOU`);
        passed++;
    } else {
        failed++;
    }
    
    // Mostrar razão se foi bloqueado
    if (result.metadata && result.metadata.isBlocked) {
        console.log(`   🚫 Bloqueado: ${result.breakdown.blocked.reason}`);
    }
});

// Resumo
console.log('\n========================================');
console.log('📊 RESUMO DOS TESTES');
console.log('========================================');
console.log(`✅ Passou: ${passed}/${testCases.length}`);
console.log(`❌ Falhou: ${failed}/${testCases.length}`);

if (failed === 0) {
    console.log('\n🎉 TODOS OS TESTES PASSARAM! Sistema funcionando corretamente!');
} else {
    console.log('\n⚠️  Alguns testes falharam. Verifique os resultados acima.');
}

// Teste específico dos problemáticos
console.log('\n========================================');
console.log('🔍 TESTE ESPECÍFICO DOS EMAILS PROBLEMÁTICOS');
console.log('========================================\n');

const problematicEmails = [
    'test@example.com',
    'admin@tempmail.com',
    'user@company.com',
    'support@10minutemail.com',
    'info@disposable.com'
];

problematicEmails.forEach(email => {
    const result = scorer.calculateScore({ 
        email: email,
        tld: { valid: true },
        disposable: { isDisposable: email.includes('mail') },
        smtp: { exists: false },
        patterns: { suspicious: true, suspicionLevel: 5 }
    });
    
    console.log(`${email}:`);
    console.log(`  Score: ${result.finalScore} | Válido: ${result.valid ? '✅' : '❌'} | Status: ${result.buyerType}`);
    
    if (result.valid) {
        console.log(`  ⚠️  PROBLEMA: Este email deveria ser inválido!`);
    }
});

console.log('\n========================================\n');
EOF

success "Script de teste criado"

# ================================================
# SUBSTITUIR ARQUIVO ORIGINAL
# ================================================
log "🔄 Aplicando a versão enhanced..."

if [ -f "${VALIDATORS_DIR}/EcommerceScoring.js" ]; then
    # Fazer backup do atual
    cp "${VALIDATORS_DIR}/EcommerceScoring.js" "${BACKUP_DIR}/EcommerceScoring_before_enhancement.js"
    
    # Aplicar a versão enhanced
    cp "${VALIDATORS_DIR}/EcommerceScoring_Enhanced.js" "${VALIDATORS_DIR}/EcommerceScoring.js"
    
    success "Versão enhanced aplicada ao EcommerceScoring.js"
fi

# ================================================
# EXECUTAR TESTES
# ================================================
log "🧪 Executando testes do sistema enhanced..."

echo ""
node test_enhanced_validation.js

# ================================================
# RESUMO FINAL
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SISTEMA DE VALIDAÇÃO ENHANCED INSTALADO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${MAGENTA}🛡️ MELHORIAS IMPLEMENTADAS:${NC}"
echo -e "  ✅ Lista de domínios bloqueados (example.com, test.com, etc.)"
echo -e "  ✅ Detecção aprimorada de emails temporários (100+ domínios)"
echo -e "  ✅ Detecção de emails genéricos (user@, admin@, test@, etc.)"
echo -e "  ✅ Padrões suspeitos (muitos números, caracteres repetidos)"
echo -e "  ✅ Threshold mais rigoroso (mínimo 70 para válido)"
echo -e "  ✅ Penalidades para emails suspeitos"
echo -e "  ✅ Classificação mais precisa de compradores"

echo -e "\n${MAGENTA}🚫 DOMÍNIOS AGORA BLOQUEADOS:${NC}"
echo -e "  • example.com, test.com, demo.com"
echo -e "  • tempmail.com, 10minutemail.com, disposable.com"
echo -e "  • guerrillamail.com, mailinator.com, yopmail.com"
echo -e "  • company.com, domain.com, fake.com"
echo -e "  • E mais 100+ domínios temporários"

echo -e "\n${MAGENTA}📊 NOVO SISTEMA DE SCORING:${NC}"
echo -e "  • Score < 50:  ❌ INVÁLIDO (Bloquear)"
echo -e "  • Score 50-69: ⚠️  SUSPEITO (Revisar manualmente)"
echo -e "  • Score ≥ 70:  ✅ VÁLIDO (Aprovar)"

echo -e "\n${MAGENTA}🎯 RESULTADOS ESPERADOS:${NC}"
echo -e "  test@example.com         → Score: 0  ❌ BLOQUEADO"
echo -e "  admin@tempmail.com       → Score: 0  ❌ BLOQUEADO"
echo -e "  user@company.com         → Score: 0  ❌ BLOQUEADO"
echo -e "  info@disposable.com      → Score: 0  ❌ BLOQUEADO"
echo -e "  carolinacasaquia@gmail.com → Score: 90+ ✅ VÁLIDO"

echo -e "\n${CYAN}💡 PRÓXIMOS PASSOS:${NC}"
echo -e "  1. Reiniciar o serviço/container"
echo -e "  2. Testar com a interface ou API"
echo -e "  3. Monitorar os resultados"

echo -e "\n${YELLOW}📝 Arquivos criados/modificados:${NC}"
echo -e "  • ${VALIDATORS_DIR}/BlockedDomains.js (novo)"
echo -e "  • ${VALIDATORS_DIR}/EcommerceScoring.js (atualizado)"
echo -e "  • test_enhanced_validation.js"
echo -e "  • Backup em: ${BACKUP_DIR}"

echo -e "\n${GREEN}✨ Sistema de validação agora é ULTRA RIGOROSO!${NC}\n"