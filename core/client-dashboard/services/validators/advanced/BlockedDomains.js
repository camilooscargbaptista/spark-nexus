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
