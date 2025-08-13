// ================================================
// Blocked Domains Module - v4.0
// Lista abrangente de domínios bloqueados com correção automática
// ================================================

const DomainCorrector = require('./DomainCorrector');

class BlockedDomains {
    constructor() {
        // Inicializar DomainCorrector
        this.domainCorrector = new DomainCorrector();

        // Domínios de teste/exemplo - SEMPRE bloquear
        this.testDomains = [
            'example.com', 'example.org', 'example.net',
            'test.com', 'test.org', 'test.net',
            'teste.com', 'teste.com.br', 'teste.org',
            'testing.com', 'testmail.com', 'test-mail.com',
            'sample.com', 'samples.com', 'demo.com', 'demos.com',
            'foo.com', 'bar.com', 'foobar.com', 'baz.com',
            'domain.com', 'email.com', 'mail.com', 'mailtest.com',
            'company.com', 'empresa.com', 'companyname.com',
            'localhost', 'local', 'invalid', 'none.com',
            'null.com', 'void.com', 'nil.com', 'nulo.com',

            // Domínios genéricos que não deveriam existir
            'user.com', 'usuario.com', 'cliente.com', 'client.com',
            'customer.com', 'person.com', 'pessoa.com', 'people.com',
            'website.com', 'site.com', 'web.com', 'internet.com',
            'business.com', 'negocio.com', 'loja.com', 'store.com',
            'shop.com', 'compras.com', 'vendas.com', 'sales.com',
            'gente.com', 'fulano.com', 'ciclano.com', 'beltrano.com',

            // Domínios óbvios de placeholder
            'placeholder.com', 'dummy.com', 'fake.com', 'falso.com',
            'temporario.com', 'temporary.com', 'provisorio.com',
            'changeme.com', 'mudar.com', 'alterar.com', 'trocar.com',
            'default.com', 'padrao.com', 'standard.com',

            // Domínios de desenvolvimento
            'dev.com', 'development.com', 'staging.com', 'sandbox.com',
            'homolog.com', 'homologacao.com', 'qa.com', 'quality.com'
        ];

        // Domínios temporários/descartáveis conhecidos
        this.disposableDomains = [
            // 10 minute mail variants
            '10minutemail.com', '10minutemail.net', '10minemail.com',
            '10minutemail.de', '10minutemail.be', '10minutemail.info',
            '10minutemail.org', '10minutemail.co.uk', '10minutemail.us',
            '10minmail.com', '10min.com', '10minutes.net',

            // Temp mail variants
            'tempmail.com', 'temp-mail.org', 'temp-mail.com',
            'tempmail.net', 'tempmail.de', 'temporarymail.com',
            'tmpmail.com', 'tmpmail.net', 'tmp-mail.com',
            'tempmails.com', 'tempinbox.com', 'tempinbox.net',
            'temp-box.com', 'tempbox.net', 'tempemail.com',

            // Disposable variants
            'disposable.com', 'disposablemail.com', 'dispose.it',
            'disposable-email.com', 'throwaway.com', 'throwawaymail.com',
            'throwawaymails.com', 'throwaway-email.com', 'throw.away',

            // Guerrilla mail
            'guerrillamail.com', 'guerrillamail.net', 'guerrillamail.org',
            'guerrillamail.biz', 'guerrillamail.de', 'guerrillamailblock.com',
            'guerrillamail.info', 'guerrillamail.com',

            // Mailinator variants
            'mailinator.com', 'mailinator.net', 'mailinator.org',
            'mailinator2.com', 'mailinater.com', 'mailinator.us',
            'mailinator.co.uk', 'mailinator.eu',

            // Yopmail
            'yopmail.com', 'yopmail.net', 'yopmail.fr',
            'yopmail.org', 'yopmail.co.uk',

            // Fake inbox
            'fakeinbox.com', 'fakeinbox.net', 'fakebox.org',
            'fakemailbox.com', 'fakemail.com', 'fakemail.net',
            'fake-mail.com', 'fake-box.com',

            // Trash mail
            'trashmail.com', 'trash-mail.com', 'trashmail.net',
            'trashmail.de', 'trashmail.org', 'trash-mail.at',
            'trashmail.ws', 'trash2009.com', 'trash2010.com',

            // Spam variants
            'spambox.us', 'spam.la', 'spamgourmet.com',
            'spamhole.com', 'spamify.com', 'spamcannon.com',
            'spamcannon.net', 'spamhereplease.com', 'spamthis.co.uk',

            // Get air mail
            'getairmail.com', 'getairmail.net', 'getairmail.org',

            // Email on deck
            'emailondeck.com', 'emailondeck.net', 'emailondeck.org',

            // Mint email
            'mintemail.com', 'mintmail.com', 'mintemail.net',

            // Quick/Fast mail services
            'quickmail.nl', 'fastmail.nl', 'fastacura.com',
            'fastchevy.com', 'fastchrysler.com', 'fastkawasaki.com',
            'fastmazda.com', 'fastmitsubishi.com', 'fastnissan.com',
            'fastsubaru.com', 'fastsuzuki.com', 'fasttoyota.com',
            'fastyamaha.com',

            // Other common disposables
            'sharklasers.com', 'grr.la', 'mailnesia.com',
            'emailsensei.com', 'imgof.com', 'letthemeatspam.com',
            'mt2009.com', 'thankyou2010.com', 'binkmail.com',
            'bobmail.info', 'chammy.info', 'choicemail1.com',
            'donemail.ru', 'dontreg.com', 'e4ward.com',
            'emailias.com', 'emailwarden.com', 'gishpuppy.com',
            'goemailgo.com', 'gotmail.com', 'gotmail.net',
            'haltospam.com', 'hotpop.com', 'incognitomail.com',
            'ipoo.org', 'irish2me.com', 'jetable.com',
            'kasmail.com', 'kaspop.com', 'killmail.com',
            'kir.ch.tc', 'klassmaster.com', 'klzlk.com',
            'kulturbetrieb.info', 'kurzepost.de', 'lifebyfood.com',
            'link2mail.net', 'litedrop.com', 'lol.ovpn.to',
            'lookugly.com', 'lopl.co.cc', 'lovemyemail.com',
            'lr78.com', 'maboard.com', 'mail.by', 'mail.mezimages.net',
            'mail2rss.org', 'mailbidon.com', 'mailblocks.com',
            'mailcatch.com', 'maildrop.cc', 'maildx.com',
            'maileater.com', 'mailexpire.com', 'mailfa.tk',
            'mailforspam.com', 'mailfreeonline.com', 'mailimate.com',
            'mailin8r.com', 'mailinblack.com', 'mailincubator.com',
            'mailismagic.com', 'mailnull.com', 'mailshell.com',
            'mailsiphon.com', 'mailslite.com', 'mailtemp.info',
            'mailtemporaire.fr', 'mailtemporaire.com', 'mailthis.net',
            'mailtrash.net', 'mailueberfall.de', 'mailzilla.com',
            'mailzilla.org', 'mbx.cc', 'mega.zik.dj',
            'meinspamschutz.de', 'meltmail.com', 'messagebeamer.de',
            'mierdamail.com', 'migumail.com', 'mintemail.com',
            'mjukglass.nu', 'mobi.web.id', 'moburl.com',
            'moncourrier.fr.nf', 'monemail.fr.nf', 'monmail.fr.nf',
            'monumentmail.com', 'msa.minsmail.com', 'mt2009.com',
            'mypartyclip.de', 'myphantomemail.com', 'myspaceinc.com',
            'myspaceinc.net', 'myspaceinc.org', 'myspacepimpedup.com',
            'myspamless.com', 'mytempemail.com', 'mytempmail.com',
            'mytrashmail.com', 'nabuma.com', 'neomailbox.com',
            'nepwk.com', 'nervmich.net', 'nervtmich.net',
            'netmails.com', 'netmails.net', 'netzidiot.de',
            'neverbox.com', 'nice-4u.com', 'nobulk.com',
            'noclickemail.com', 'nogmailspam.info', 'nomail.xl.cx',
            'nomail2me.com', 'nomorespamemails.com', 'nospam.ze.tc',
            'nospam4.us', 'nospamfor.us', 'nospammail.net',
            'nospamthanks.info', 'notmailinator.com', 'nowmymail.com',
            'nurfuerspam.de', 'nus.edu.sg', 'nwldx.com',
            'objectmail.com', 'obobbo.com', 'oneoffemail.com',
            'onewaymail.com', 'online.ms', 'oopi.org',
            'opayq.com', 'ordinaryamerican.net', 'otherinbox.com',
            'ourklips.com', 'outlawspam.com', 'ovpn.to',
            'owlpic.com', 'pancakemail.com', 'pimpedupmyspace.com',
            'pjjkp.com', 'politikerclub.de', 'poofy.org',
            'pookmail.com', 'privacy.net', 'privatdemail.net',
            'proxymail.eu', 'prtnx.com', 'punkass.com',
            'putthisinyourspamdatabase.com', 'pwrby.com', 'qoika.com',
            'quickinbox.com', 'quickmail.nl', 'quotentag.com'
        ];

        // Palavras-chave suspeitas em domínios
        this.suspiciousKeywords = [
            'temp', 'tmp', 'disposable', 'throwaway',
            'trash', 'fake', 'spam', 'junk',
            'minute', 'hour', 'temporary', 'burner',
            'anonymous', 'hide', 'masked', 'guerrilla',
            'quick', 'fast', 'instant', 'easy',
            'free', 'gratis', 'bypass', 'proxy'
        ];

        // Padrões de email genérico/suspeito (local part)
        this.genericLocalParts = [
            'test', 'teste', 'testing', 'tester', 'tests',
            'admin', 'administrator', 'root', 'webmaster', 'postmaster',
            'info', 'contact', 'support', 'sales', 'marketing',
            'noreply', 'no-reply', 'donotreply', 'do-not-reply',
            'user', 'usuario', 'client', 'cliente', 'customer',
            'demo', 'sample', 'example', 'default', 'standard',
            'mail', 'email', 'enquiry', 'inquiry', 'newsletter',
            'fake', 'temp', 'temporary', 'disposable', 'trash',
            'asdf', 'asdfasdf', 'qwerty', 'qwertyuiop', 'zxcv',
            'abc', 'abc123', '123', 'test123', 'teste123',
            'aaa', 'aaaa', 'xxx', 'zzz', 'www',
            'fulano', 'ciclano', 'beltrano', 'joao', 'maria',
            'jose', 'antonio', 'francisco', 'ana', 'john', 'jane'
        ];

        // Cache para performance
        this.cache = new Map();

        // Estatísticas
        this.stats = {
            totalChecked: 0,
            blocked: 0,
            suspicious: 0,
            corrected: 0,
            correctedAndBlocked: 0
        };
    }

    /**
     * Verifica se um email está bloqueado
     * @param {string} email - Email para verificar
     * @returns {Object} Resultado da verificação
     */
    isBlocked(email) {
        this.stats.totalChecked++;

        if (!email) return { blocked: true, reason: 'Email vazio' };

        const emailLower = email.toLowerCase().trim();

        // Verificar cache
        if (this.cache.has(emailLower)) {
            return this.cache.get(emailLower);
        }

        // ================================================
        // PASSO 1: VERIFICAR EMAIL ORIGINAL
        // ================================================
        let result = this.checkEmail(emailLower);

        // Se está bloqueado, retornar imediatamente
        if (result.blocked) {
            this.stats.blocked++;
            this.cache.set(emailLower, result);
            return result;
        }

        // ================================================
        // PASSO 2: TENTAR CORRIGIR E VERIFICAR NOVAMENTE
        // ================================================
        const correctionResult = this.domainCorrector.correctEmail(emailLower);

        if (correctionResult.wasCorrected) {
            this.stats.corrected++;

            // Verificar se a versão CORRIGIDA está bloqueada
            const correctedCheck = this.checkEmail(correctionResult.corrected);

            if (correctedCheck.blocked) {
                this.stats.correctedAndBlocked++;

                // Email corrigido está bloqueado - bloquear o original também
                result = {
                    blocked: true,
                    reason: `Email corrigido (${correctionResult.corrected}) está bloqueado: ${correctedCheck.reason}`,
                    category: 'blocked_after_correction',
                    severity: 'critical',
                    originalEmail: emailLower,
                    correctedEmail: correctionResult.corrected,
                    correctionDetails: correctionResult.correction,
                    originalCheck: result,
                    correctedCheck: correctedCheck
                };

                this.stats.blocked++;
                this.cache.set(emailLower, result);
                return result;
            }

            // Email corrigido não está bloqueado, mas marcar como suspeito por ter typo
            if (!result.suspicious) {
                result.suspicious = true;
                result.suspicionReason = 'Email continha erro de digitação';
                result.penaltyScore = 10;
            }

            // Adicionar informações de correção ao resultado
            result.wasCorrected = true;
            result.correctionDetails = correctionResult.correction;
            result.correctedEmail = correctionResult.corrected;
        }

        // ================================================
        // PASSO 3: VERIFICAÇÕES ADICIONAIS DE SUSPEITA
        // ================================================
        if (!result.blocked && !result.suspicious) {
            const [localPart, domain] = emailLower.split('@');

            // Verificar padrões suspeitos adicionais
            if (this.isSuspiciousPattern(localPart, domain)) {
                result.suspicious = true;
                result.suspicionReason = 'Padrão suspeito detectado';
                result.category = 'suspicious_pattern';
                result.severity = 'low';
                result.penaltyScore = 20;
            }
        }

        // Atualizar estatísticas
        if (result.suspicious) {
            this.stats.suspicious++;
        }

        // Cachear resultado
        this.cache.set(emailLower, result);
        return result;
    }

    /**
     * Verifica um email sem correção
     * @private
     */
    checkEmail(email) {
        const [localPart, domain] = email.split('@');

        if (!domain) {
            return {
                blocked: true,
                reason: 'Formato inválido',
                category: 'invalid_format',
                severity: 'critical'
            };
        }

        // 1. Verificar domínios de teste
        if (this.testDomains.includes(domain)) {
            return {
                blocked: true,
                reason: 'Domínio de teste/exemplo',
                category: 'test_domain',
                severity: 'critical',
                domainType: 'test'
            };
        }

        // 2. Verificar domínios descartáveis
        if (this.disposableDomains.includes(domain)) {
            return {
                blocked: true,
                reason: 'Email temporário/descartável',
                category: 'disposable',
                severity: 'high',
                domainType: 'disposable'
            };
        }

        // 3. Verificar subdomínios de descartáveis
        for (const disposable of this.disposableDomains) {
            if (domain.endsWith('.' + disposable)) {
                return {
                    blocked: true,
                    reason: 'Subdomínio de email temporário',
                    category: 'disposable_subdomain',
                    severity: 'high',
                    domainType: 'disposable_subdomain',
                    parentDomain: disposable
                };
            }
        }

        // 4. Verificar palavras-chave suspeitas no domínio
        for (const keyword of this.suspiciousKeywords) {
            if (domain.includes(keyword)) {
                return {
                    blocked: true,
                    reason: `Domínio suspeito (contém "${keyword}")`,
                    category: 'suspicious_domain',
                    severity: 'medium',
                    suspiciousKeyword: keyword
                };
            }
        }

        // 5. Verificar local part genérico/suspeito
        if (this.genericLocalParts.includes(localPart)) {
            // Não bloquear completamente, mas marcar como suspeito
            return {
                blocked: false,
                suspicious: true,
                reason: `Email genérico (${localPart}@)`,
                category: 'generic_email',
                severity: 'low',
                penaltyScore: 30,
                localPartType: 'generic'
            };
        }

        // 6. Verificar se local part é muito genérico (apenas números ou caracteres repetidos)
        if (/^\d+$/.test(localPart)) {
            return {
                blocked: false,
                suspicious: true,
                reason: 'Local part contém apenas números',
                category: 'numeric_only',
                severity: 'medium',
                penaltyScore: 25
            };
        }

        if (/^(.)\1+$/.test(localPart)) {
            return {
                blocked: false,
                suspicious: true,
                reason: 'Local part contém apenas caracteres repetidos',
                category: 'repeated_chars',
                severity: 'medium',
                penaltyScore: 30
            };
        }

        // Email passou em todas as verificações básicas
        return {
            blocked: false,
            suspicious: false,
            reason: null,
            category: 'clean'
        };
    }

    /**
     * Verifica padrões suspeitos adicionais
     * @private
     */
    isSuspiciousPattern(localPart, domain) {
        // Muitos números consecutivos
        if (/\d{5,}/.test(localPart)) return true;

        // Caracteres repetidos excessivamente (4 ou mais)
        if (/(.)\1{3,}/.test(localPart)) return true;

        // Começa ou termina com múltiplos números
        if (/^\d{3,}/.test(localPart) || /\d{3,}$/.test(localPart)) return true;

        // Domínio muito curto (menos de 4 caracteres antes do TLD)
        const domainName = domain.split('.')[0];
        if (domainName && domainName.length < 3) return true;

        // Muitos hífens ou underscores
        if ((localPart.match(/[-_]/g) || []).length > 3) return true;

        // Combinação suspeita de letras e números aleatórios
        if (/^[a-z]{1,2}\d{4,}$/.test(localPart)) return true;

        // Padrão de spam comum: palavra + números aleatórios
        if (/^(info|contact|admin|support|sales)\d{3,}$/.test(localPart)) return true;

        return false;
    }

    /**
     * Adiciona um domínio à lista de bloqueados
     * @param {string} domain - Domínio para adicionar
     * @param {string} category - Categoria (test, disposable, custom)
     */
    addBlockedDomain(domain, category = 'custom') {
        domain = domain.toLowerCase().trim();

        if (category === 'test') {
            if (!this.testDomains.includes(domain)) {
                this.testDomains.push(domain);
            }
        } else if (category === 'disposable') {
            if (!this.disposableDomains.includes(domain)) {
                this.disposableDomains.push(domain);
            }
        }

        // Limpar cache quando adicionar novo domínio
        this.clearCache();
    }

    /**
     * Remove um domínio da lista de bloqueados
     * @param {string} domain - Domínio para remover
     */
    removeBlockedDomain(domain) {
        domain = domain.toLowerCase().trim();

        let removed = false;

        // Tentar remover de test domains
        const testIndex = this.testDomains.indexOf(domain);
        if (testIndex > -1) {
            this.testDomains.splice(testIndex, 1);
            removed = true;
        }

        // Tentar remover de disposable domains
        const disposableIndex = this.disposableDomains.indexOf(domain);
        if (disposableIndex > -1) {
            this.disposableDomains.splice(disposableIndex, 1);
            removed = true;
        }

        if (removed) {
            this.clearCache();
        }

        return removed;
    }

    /**
     * Verifica múltiplos emails em lote
     * @param {Array} emails - Array de emails para verificar
     * @returns {Array} Array de resultados
     */
    checkBatch(emails) {
        return emails.map(email => ({
            email: email,
            ...this.isBlocked(email)
        }));
    }

    /**
     * Limpa o cache
     */
    clearCache() {
        this.cache.clear();
        console.log('✅ BlockedDomains cache cleared');
    }

    /**
     * Retorna estatísticas
     */
    getStatistics() {
        return {
            ...this.stats,
            testDomainsCount: this.testDomains.length,
            disposableDomainsCount: this.disposableDomains.length,
            totalBlockedDomains: this.testDomains.length + this.disposableDomains.length,
            cacheSize: this.cache.size,
            blockRate: this.stats.totalChecked > 0
                ? ((this.stats.blocked / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            suspiciousRate: this.stats.totalChecked > 0
                ? ((this.stats.suspicious / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            correctionRate: this.stats.totalChecked > 0
                ? ((this.stats.corrected / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            correctedAndBlockedRate: this.stats.corrected > 0
                ? ((this.stats.correctedAndBlocked / this.stats.corrected) * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    /**
     * Reseta estatísticas
     */
    resetStatistics() {
        this.stats = {
            totalChecked: 0,
            blocked: 0,
            suspicious: 0,
            corrected: 0,
            correctedAndBlocked: 0
        };
        console.log('✅ BlockedDomains statistics reset');
    }

    /**
     * Exporta configuração atual
     */
    exportConfiguration() {
        return {
            testDomains: [...this.testDomains],
            disposableDomains: [...this.disposableDomains],
            suspiciousKeywords: [...this.suspiciousKeywords],
            genericLocalParts: [...this.genericLocalParts]
        };
    }

    /**
     * Importa configuração
     */
    importConfiguration(config) {
        if (config.testDomains) {
            this.testDomains = [...config.testDomains];
        }
        if (config.disposableDomains) {
            this.disposableDomains = [...config.disposableDomains];
        }
        if (config.suspiciousKeywords) {
            this.suspiciousKeywords = [...config.suspiciousKeywords];
        }
        if (config.genericLocalParts) {
            this.genericLocalParts = [...config.genericLocalParts];
        }

        this.clearCache();
        console.log('✅ BlockedDomains configuration imported');
    }
}

module.exports = BlockedDomains;
