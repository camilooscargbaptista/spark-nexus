// ================================================
// Validadores para CPF, CNPJ, Email e Telefone
// ================================================

const { cpf, cnpj } = require('cpf-cnpj-validator');

class Validators {
    // Validar CPF ou CNPJ
    static validateCpfCnpj(value) {
        // Remove caracteres não numéricos
        const cleaned = value.replace(/[^\d]/g, '');
        
        if (cleaned.length === 11) {
            // É CPF
            return {
                valid: cpf.isValid(cleaned),
                type: 'CPF',
                formatted: cpf.format(cleaned)
            };
        } else if (cleaned.length === 14) {
            // É CNPJ
            return {
                valid: cnpj.isValid(cleaned),
                type: 'CNPJ',
                formatted: cnpj.format(cleaned)
            };
        } else {
            return {
                valid: false,
                type: null,
                formatted: null,
                error: 'Documento deve ter 11 dígitos (CPF) ou 14 dígitos (CNPJ)'
            };
        }
    }

    // Validar email
    static validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        const valid = emailRegex.test(email);
        
        // Verificar domínios descartáveis comuns
        const disposableDomains = [
            'tempmail.com', 'throwaway.email', '10minutemail.com',
            'guerrillamail.com', 'mailinator.com', 'temp-mail.org'
        ];
        
        const domain = email.split('@')[1]?.toLowerCase();
        const isDisposable = disposableDomains.includes(domain);
        
        return {
            valid: valid && !isDisposable,
            isDisposable,
            domain
        };
    }

    // Validar telefone brasileiro
    static validatePhone(phone) {
        // Remove caracteres não numéricos
        const cleaned = phone.replace(/[^\d]/g, '');
        
        // Telefone brasileiro deve ter 10 ou 11 dígitos
        if (cleaned.length === 10 || cleaned.length === 11) {
            // Verifica se começa com DDD válido (11-99)
            const ddd = parseInt(cleaned.substring(0, 2));
            if (ddd >= 11 && ddd <= 99) {
                // Formatar telefone
                let formatted;
                if (cleaned.length === 11) {
                    // Celular: (XX) 9XXXX-XXXX
                    formatted = `(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}`;
                } else {
                    // Fixo: (XX) XXXX-XXXX
                    formatted = `(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}`;
                }
                
                return {
                    valid: true,
                    type: cleaned.length === 11 ? 'mobile' : 'landline',
                    formatted,
                    ddd
                };
            }
        }
        
        return {
            valid: false,
            error: 'Telefone deve ter 10 ou 11 dígitos com DDD válido'
        };
    }

    // Validar senha forte
    static validatePassword(password) {
        const minLength = 8;
        const hasUpperCase = /[A-Z]/.test(password);
        const hasLowerCase = /[a-z]/.test(password);
        const hasNumbers = /\d/.test(password);
        const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);
        
        const strength = {
            length: password.length >= minLength,
            uppercase: hasUpperCase,
            lowercase: hasLowerCase,
            numbers: hasNumbers,
            special: hasSpecialChar
        };
        
        const score = Object.values(strength).filter(Boolean).length;
        
        return {
            valid: score >= 4,
            strength,
            score,
            level: score <= 2 ? 'weak' : score <= 3 ? 'medium' : 'strong'
        };
    }

    // Gerar token aleatório
    static generateToken(length = 6, type = 'numeric') {
        const numeric = '0123456789';
        const alphanumeric = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
        
        const chars = type === 'numeric' ? numeric : alphanumeric;
        let token = '';
        
        for (let i = 0; i < length; i++) {
            token += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        
        return token;
    }
}

module.exports = Validators;
