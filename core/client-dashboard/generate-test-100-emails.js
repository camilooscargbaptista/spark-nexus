// generate-test-emails-100.js
const fs = require('fs');
const path = require('path');

class TestEmailGenerator100 {
    constructor() {
        // Domínios de alta qualidade (score > 75)
        this.highQualityDomains = [
            'gmail.com', 'outlook.com', 'hotmail.com', 'yahoo.com',
            'icloud.com', 'me.com', 'msn.com', 'live.com',
            'aol.com', 'protonmail.com', 'zoho.com'
        ];

        // Domínios corporativos brasileiros (score > 75)
        this.brazilianCorpDomains = [
            'globo.com', 'uol.com.br', 'terra.com.br', 'bol.com.br',
            'ig.com.br', 'r7.com', 'folha.com.br', 'estadao.com.br'
        ];

        // Domínios de qualidade média (score 50-60)
        this.mediumQualityDomains = [
            'mail.com', 'email.com', 'inbox.com', 'webmail.com',
            'fastmail.com', 'hushmail.com'
        ];

        // Domínios suspeitos/temporários (score < 50)
        this.lowQualityDomains = [
            'tempmail.com', 'guerrillamail.com', '10minutemail.com',
            'throwaway.email', 'mailinator.com', 'maildrop.cc'
        ];

        // Nomes comuns brasileiros (versão reduzida)
        this.firstNames = [
            'João', 'Maria', 'José', 'Ana', 'Paulo', 'Carlos', 'Lucas', 'Juliana',
            'Pedro', 'Mariana', 'Fernando', 'Amanda', 'Rafael', 'Beatriz', 'Gabriel',
            'Larissa', 'Bruno', 'Camila', 'Rodrigo', 'Patricia', 'Marcelo', 'Fernanda',
            'Thiago', 'Aline', 'Leonardo', 'Vanessa', 'Diego', 'Natalia', 'Matheus',
            'Carolina'
        ];

        this.lastNames = [
            'Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves',
            'Pereira', 'Lima', 'Gomes', 'Costa', 'Ribeiro', 'Martins', 'Carvalho',
            'Almeida', 'Lopes', 'Soares', 'Fernandes', 'Vieira', 'Barbosa'
        ];
    }

    generateHighQualityEmail() {
        const firstName = this.getRandomItem(this.firstNames).toLowerCase();
        const lastName = this.getRandomItem(this.lastNames).toLowerCase();
        const domain = this.getRandomItem([...this.highQualityDomains, ...this.brazilianCorpDomains]);

        const patterns = [
            `${firstName}.${lastName}@${domain}`,
            `${firstName}${lastName}@${domain}`,
            `${firstName}_${lastName}@${domain}`,
            `${firstName}@${domain}`
        ];

        return this.getRandomItem(patterns);
    }

    generateMediumQualityEmail() {
        const firstName = this.getRandomItem(this.firstNames).toLowerCase();
        const lastName = this.getRandomItem(this.lastNames).toLowerCase();
        const domain = this.getRandomItem(this.mediumQualityDomains);
        const number = Math.floor(Math.random() * 999);

        const patterns = [
            `${firstName}${number}@${domain}`,
            `${firstName}.${lastName}${number}@${domain}`,
            `user${number}@${domain}`,
            `contact${number}@${domain}`
        ];

        // 30% com typos para testar correção
        if (Math.random() < 0.3) {
            const email = this.getRandomItem(patterns);
            return this.introduceTypo(email);
        }

        return this.getRandomItem(patterns);
    }

    generateLowQualityEmail() {
        const randomString = Math.random().toString(36).substring(7);
        const domain = this.getRandomItem(this.lowQualityDomains);

        const patterns = [
            `test${randomString}@${domain}`,
            `temp${randomString}@${domain}`,
            `user${Math.floor(Math.random() * 9999)}@${domain}`,
            `noreply@${domain}`
        ];

        // 20% completamente inválidos
        if (Math.random() < 0.2) {
            return this.generateInvalidEmail();
        }

        return this.getRandomItem(patterns);
    }

    generateInvalidEmail() {
        const invalid = [
            'notanemail',
            '@nodomain.com',
            'missing@',
            'double@@domain.com',
            'no-tld@domain'
        ];

        return this.getRandomItem(invalid);
    }

    introduceTypo(email) {
        const typos = [
            { from: 'gmail.com', to: 'gmai.com' },
            { from: 'gmail.com', to: 'gmial.com' },
            { from: 'hotmail.com', to: 'hotmai.com' },
            { from: 'yahoo.com', to: 'yaho.com' },
            { from: 'outlook.com', to: 'outlok.com' }
        ];

        let modifiedEmail = email;
        typos.forEach(typo => {
            if (email.includes(typo.from)) {
                modifiedEmail = email.replace(typo.from, typo.to);
            }
        });

        return modifiedEmail;
    }

    getRandomItem(array) {
        return array[Math.floor(Math.random() * array.length)];
    }

    generateTestList() {
        const emails = [];
        const usedEmails = new Set();

        console.log('🚀 Gerando lista de teste com 100 emails...\n');

        // 70% - Alta qualidade (70 emails)
        console.log('📧 Gerando 70 emails de alta qualidade (score > 75)...');
        for (let i = 0; i < 70; i++) {
            let email;
            do {
                email = this.generateHighQualityEmail();
            } while (usedEmails.has(email));

            usedEmails.add(email);
            emails.push(email);
        }
        console.log('   ✓ 70 emails de alta qualidade gerados');

        // 20% - Qualidade média (20 emails)
        console.log('\n📧 Gerando 20 emails de qualidade média (score 50-60)...');
        for (let i = 0; i < 20; i++) {
            let email;
            do {
                email = this.generateMediumQualityEmail();
            } while (usedEmails.has(email));

            usedEmails.add(email);
            emails.push(email);
        }
        console.log('   ✓ 20 emails de qualidade média gerados');

        // 10% - Baixa qualidade (10 emails)
        console.log('\n📧 Gerando 10 emails de baixa qualidade (score < 50)...');
        for (let i = 0; i < 10; i++) {
            let email;
            do {
                email = this.generateLowQualityEmail();
            } while (usedEmails.has(email));

            usedEmails.add(email);
            emails.push(email);
        }
        console.log('   ✓ 10 emails de baixa qualidade gerados');

        // Embaralhar a lista
        console.log('\n🔀 Embaralhando lista...');
        for (let i = emails.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [emails[i], emails[j]] = [emails[j], emails[i]];
        }

        return emails;
    }

    saveToCSV(emails, filename = 'test_emails_100.csv') {
        const csvContent = 'email\n' + emails.join('\n');
        const filepath = path.join(__dirname, filename);

        fs.writeFileSync(filepath, csvContent, 'utf8');
        console.log(`\n✅ Arquivo salvo: ${filepath}`);

        return filepath;
    }

    async run() {
        console.log('=====================================');
        console.log('  GERADOR DE 100 EMAILS PARA TESTE  ');
        console.log('=====================================\n');

        const emails = this.generateTestList();
        const filepath = this.saveToCSV(emails);

        console.log('\n📊 ESTATÍSTICAS DA LISTA:');
        console.log('=====================================');
        console.log(`Total de emails: 100`);
        console.log(`Alta qualidade: 70 (70%)`);
        console.log(`Média qualidade: 20 (20%)`);
        console.log(`Baixa qualidade: 10 (10%)`);

        console.log('\n=====================================');
        console.log('✅ LISTA GERADA COM SUCESSO!');
        console.log('=====================================');
        console.log(`\n📁 Arquivo: ${filepath}`);
        console.log('\n🎯 Distribuição:');
        console.log('  - 70% (70) com score > 75');
        console.log('  - 20% (20) com score 50-60');
        console.log('  - 10% (10) com score < 50');
        console.log('\n💡 Use este arquivo para teste rápido!\n');
    }
}

// Executar gerador
if (require.main === module) {
    const generator = new TestEmailGenerator100();
    generator.run().catch(console.error);
}

module.exports = TestEmailGenerator100;
