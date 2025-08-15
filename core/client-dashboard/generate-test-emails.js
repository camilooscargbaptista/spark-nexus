// generate-test-emails.js
const fs = require('fs');
const path = require('path');

class TestEmailGenerator {
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
            'ig.com.br', 'r7.com', 'folha.com.br', 'estadao.com.br',
            'abril.com.br', 'record.com.br', 'sbt.com.br', 'band.com.br'
        ];

        // Domínios de qualidade média (score 50-60)
        this.mediumQualityDomains = [
            'mail.com', 'email.com', 'inbox.com', 'webmail.com',
            'fastmail.com', 'hushmail.com', 'runbox.com', 'mailfence.com'
        ];

        // Domínios suspeitos/temporários (score < 50)
        this.lowQualityDomains = [
            'tempmail.com', 'guerrillamail.com', '10minutemail.com',
            'throwaway.email', 'mailinator.com', 'maildrop.cc',
            'trash-mail.com', 'fake-email.com', 'temporary-email.com'
        ];

        // Nomes comuns brasileiros
        this.firstNames = [
            'João', 'Maria', 'José', 'Ana', 'Paulo', 'Carlos', 'Lucas', 'Juliana',
            'Pedro', 'Mariana', 'Fernando', 'Amanda', 'Rafael', 'Beatriz', 'Gabriel',
            'Larissa', 'Bruno', 'Camila', 'Rodrigo', 'Patricia', 'Marcelo', 'Fernanda',
            'Thiago', 'Aline', 'Leonardo', 'Vanessa', 'Diego', 'Natalia', 'Matheus',
            'Carolina', 'André', 'Bruna', 'Felipe', 'Leticia', 'Gustavo', 'Jessica',
            'Ricardo', 'Daniela', 'Eduardo', 'Rafaela', 'Vinicius', 'Isabela',
            'Antonio', 'Sandra', 'Francisco', 'Lucia', 'Roberto', 'Claudia',
            'Marcos', 'Adriana', 'Alexandre', 'Cristina', 'Daniel', 'Renata',
            'Guilherme', 'Tatiana', 'Henrique', 'Monica', 'Igor', 'Priscila',
            'Julio', 'Raquel', 'Leandro', 'Simone', 'Luis', 'Viviane',
            'Mauricio', 'Andrea', 'Nelson', 'Elaine', 'Oscar', 'Fabiana',
            'Pablo', 'Gabriela', 'Renan', 'Helena', 'Samuel', 'Ingrid',
            'Tiago', 'Julia', 'Victor', 'Kelly', 'William', 'Livia',
            'Alex', 'Michele', 'Caio', 'Nathalia', 'Danilo', 'Olivia',
            'Fabio', 'Paula', 'George', 'Regina', 'Hugo', 'Silvia'
        ];

        this.lastNames = [
            'Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves',
            'Pereira', 'Lima', 'Gomes', 'Costa', 'Ribeiro', 'Martins', 'Carvalho',
            'Almeida', 'Lopes', 'Soares', 'Fernandes', 'Vieira', 'Barbosa', 'Rocha',
            'Dias', 'Nascimento', 'Moreira', 'Nunes', 'Mendes', 'Machado', 'Freitas',
            'Cardoso', 'Ramos', 'Gonçalves', 'Santana', 'Teixeira', 'Pinto', 'Araújo',
            'Correia', 'Cavalcanti', 'Monteiro', 'Moura', 'Castro', 'Campos', 'Miranda',
            'Garcia', 'Medeiros', 'Azevedo', 'Melo', 'Reis', 'Borges', 'Viana', 'Andrade'
        ];

        // Padrões de email corporativo
        this.emailPatterns = [
            '{firstName}.{lastName}',
            '{firstName}{lastName}',
            '{firstName}_{lastName}',
            '{firstName}-{lastName}',
            '{firstName}.{lastInitial}',
            '{firstInitial}{lastName}',
            '{firstName}{year}',
            '{lastName}{number}',
            '{firstName}{lastName}{number}'
        ];
    }

    generateHighQualityEmail() {
        const firstName = this.getRandomItem(this.firstNames).toLowerCase();
        const lastName = this.getRandomItem(this.lastNames).toLowerCase();
        const domain = this.getRandomItem([...this.highQualityDomains, ...this.brazilianCorpDomains]);

        // 80% emails profissionais, 20% com números
        const useNumber = Math.random() < 0.2;
        const number = useNumber ? Math.floor(Math.random() * 999) : '';

        const patterns = [
            `${firstName}.${lastName}${number}@${domain}`,
            `${firstName}${lastName}${number}@${domain}`,
            `${firstName}_${lastName}@${domain}`,
            `${firstName}@${domain}`,
            `${firstName}${lastName.charAt(0)}@${domain}`
        ];

        return this.getRandomItem(patterns);
    }

    generateMediumQualityEmail() {
        const firstName = this.getRandomItem(this.firstNames).toLowerCase();
        const lastName = this.getRandomItem(this.lastNames).toLowerCase();
        const domain = this.getRandomItem(this.mediumQualityDomains);

        // Adicionar números aleatórios (emails menos profissionais)
        const number = Math.floor(Math.random() * 9999);

        const patterns = [
            `${firstName}${number}@${domain}`,
            `${firstName}.${lastName}${number}@${domain}`,
            `${firstName}_${number}@${domain}`,
            `user${number}@${domain}`,
            `contact${number}@${domain}`,
            `info${number}@${domain}`
        ];

        // Adicionar alguns com typos intencionais que serão corrigidos
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
            `fake${randomString}@${domain}`,
            `${randomString}@${domain}`,
            `user${Math.floor(Math.random() * 99999)}@${domain}`,
            `noreply@${domain}`,
            `donotreply@${domain}`,
            `admin@${domain}`,
            `test@${domain}`
        ];

        // Alguns emails completamente inválidos
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
            'spaces in@email.com',
            'special!char@email.com',
            '.startswithdot@email.com',
            'endswithdot.@email.com',
            'double..dots@email.com',
            'no-tld@domain',
            `${this.getRandomItem(this.firstNames)}@`,
            `@${this.getRandomItem(this.highQualityDomains)}`,
            'user@.com',
            'user@domain..com'
        ];

        return this.getRandomItem(invalid);
    }

    introduceTypo(email) {
        const typos = [
            { from: 'gmail.com', to: 'gmai.com' },
            { from: 'gmail.com', to: 'gmial.com' },
            { from: 'gmail.com', to: 'gmail.co' },
            { from: 'hotmail.com', to: 'hotmai.com' },
            { from: 'hotmail.com', to: 'hotmial.com' },
            { from: 'yahoo.com', to: 'yaho.com' },
            { from: 'yahoo.com', to: 'yahoo.co' },
            { from: 'outlook.com', to: 'outlok.com' },
            { from: 'outlook.com', to: 'outloook.com' }
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

        console.log('🚀 Gerando lista de teste com 1500 emails...\n');

        // 70% - Alta qualidade (1050 emails)
        console.log('📧 Gerando 1050 emails de alta qualidade (score > 75)...');
        for (let i = 0; i < 1050; i++) {
            let email;
            do {
                email = this.generateHighQualityEmail();
            } while (usedEmails.has(email));

            usedEmails.add(email);
            emails.push(email);

            if ((i + 1) % 100 === 0) {
                console.log(`   ✓ ${i + 1}/1050 emails de alta qualidade gerados`);
            }
        }

        // 20% - Qualidade média (300 emails)
        console.log('\n📧 Gerando 300 emails de qualidade média (score 50-60)...');
        for (let i = 0; i < 300; i++) {
            let email;
            do {
                email = this.generateMediumQualityEmail();
            } while (usedEmails.has(email));

            usedEmails.add(email);
            emails.push(email);

            if ((i + 1) % 50 === 0) {
                console.log(`   ✓ ${i + 1}/300 emails de qualidade média gerados`);
            }
        }

        // 10% - Baixa qualidade (150 emails)
        console.log('\n📧 Gerando 150 emails de baixa qualidade (score < 50)...');
        for (let i = 0; i < 150; i++) {
            let email;
            do {
                email = this.generateLowQualityEmail();
            } while (usedEmails.has(email));

            usedEmails.add(email);
            emails.push(email);

            if ((i + 1) % 30 === 0) {
                console.log(`   ✓ ${i + 1}/150 emails de baixa qualidade gerados`);
            }
        }

        // Embaralhar a lista
        console.log('\n🔀 Embaralhando lista...');
        for (let i = emails.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [emails[i], emails[j]] = [emails[j], emails[i]];
        }

        return emails;
    }

    saveToCSV(emails, filename = 'test_emails_1500.csv') {
        const csvContent = 'email\n' + emails.join('\n');
        const filepath = path.join(__dirname, filename);

        fs.writeFileSync(filepath, csvContent, 'utf8');
        console.log(`\n✅ Arquivo salvo: ${filepath}`);

        return filepath;
    }

    generateStatistics(emails) {
        const stats = {
            total: emails.length,
            domains: {},
            patterns: {
                professional: 0,
                withNumbers: 0,
                withTypos: 0,
                invalid: 0
            }
        };

        emails.forEach(email => {
            // Contar domínios
            if (email.includes('@')) {
                const domain = email.split('@')[1];
                stats.domains[domain] = (stats.domains[domain] || 0) + 1;
            }

            // Padrões
            if (email.match(/^[a-z]+\.[a-z]+@/)) {
                stats.patterns.professional++;
            }
            if (email.match(/[0-9]/)) {
                stats.patterns.withNumbers++;
            }
            if (!email.includes('@') || email.includes('@@')) {
                stats.patterns.invalid++;
            }
        });

        return stats;
    }

    async run() {
        console.log('=====================================');
        console.log('   GERADOR DE EMAILS PARA TESTE     ');
        console.log('=====================================\n');

        const emails = this.generateTestList();
        const filepath = this.saveToCSV(emails);
        const stats = this.generateStatistics(emails);

        console.log('\n📊 ESTATÍSTICAS DA LISTA:');
        console.log('=====================================');
        console.log(`Total de emails: ${stats.total}`);
        console.log(`Emails profissionais: ${stats.patterns.professional}`);
        console.log(`Emails com números: ${stats.patterns.withNumbers}`);
        console.log(`Emails inválidos: ${stats.patterns.invalid}`);
        console.log(`\nTop 10 domínios mais usados:`);

        const sortedDomains = Object.entries(stats.domains)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10);

        sortedDomains.forEach(([domain, count]) => {
            console.log(`  - ${domain}: ${count} emails`);
        });

        console.log('\n=====================================');
        console.log('✅ LISTA GERADA COM SUCESSO!');
        console.log('=====================================');
        console.log(`\n📁 Arquivo: ${filepath}`);
        console.log('\n🎯 Distribuição esperada:');
        console.log('  - 70% (1050) com score > 75');
        console.log('  - 20% (300) com score 50-60');
        console.log('  - 10% (150) com score < 50');
        console.log('\n💡 Use este arquivo para testar o sistema de validação!\n');
    }
}

// Executar gerador
if (require.main === module) {
    const generator = new TestEmailGenerator();
    generator.run().catch(console.error);
}

module.exports = TestEmailGenerator;
