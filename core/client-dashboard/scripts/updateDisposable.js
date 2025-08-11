#!/usr/bin/env node

const https = require('https');
const fs = require('fs');
const path = require('path');

// Múltiplas fontes de domínios descartáveis
const DISPOSABLE_SOURCES = [
    'https://raw.githubusercontent.com/disposable/disposable-email-domains/master/domains.json',
    'https://raw.githubusercontent.com/FGRibreau/mailchecker/master/list/disposable_email_blocklist.conf',
    'https://raw.githubusercontent.com/wesbos/burner-email-providers/master/emails.txt',
    'https://raw.githubusercontent.com/7c/fakefilter/main/txt/data.txt'
];

async function downloadFile(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (response) => {
            if (response.statusCode === 302 || response.statusCode === 301) {
                https.get(response.headers.location, (res) => {
                    let data = '';
                    res.on('data', (chunk) => data += chunk);
                    res.on('end', () => resolve(data));
                }).on('error', reject);
            } else {
                let data = '';
                response.on('data', (chunk) => data += chunk);
                response.on('end', () => resolve(data));
            }
        }).on('error', reject);
    });
}

async function updateDisposableList() {
    const allDomains = new Set();
    
    // Adicionar domínios conhecidos manualmente
    const manualDomains = [
        'tempmail.com', 'throwaway.email', '10minutemail.com',
        'guerrillamail.com', 'mailinator.com', 'temp-mail.org',
        'yopmail.com', 'getairmail.com', 'emailondeck.com',
        'maildrop.cc', 'mintemail.com', 'throwemail.com',
        'tmpmail.net', 'fakeinbox.com', 'sneakemail.com',
        'emailsensei.com', 'spamgourmet.com', 'trashmail.net',
        'disposable.com', 'fake.com', 'trash.com', 'temporary.com'
    ];
    
    manualDomains.forEach(d => allDomains.add(d.toLowerCase()));
    
    // Baixar de múltiplas fontes
    for (const source of DISPOSABLE_SOURCES) {
        try {
            console.log(`📥 Baixando de ${source.split('/')[5]}...`);
            const data = await downloadFile(source);
            
            // Processar diferentes formatos
            let domains = [];
            try {
                // Tentar JSON
                domains = JSON.parse(data);
            } catch {
                // Se não for JSON, assumir lista de texto
                domains = data.split('\n').filter(line => line && !line.startsWith('#'));
            }
            
            domains.forEach(domain => {
                if (domain && typeof domain === 'string') {
                    allDomains.add(domain.toLowerCase().trim());
                }
            });
        } catch (error) {
            console.warn(`⚠️ Falha ao baixar de ${source.split('/')[5]}`);
        }
    }
    
    // Adicionar padrões de domínios temporários
    const patterns = [
        /^temp/i, /trash/i, /fake/i, /disposable/i,
        /mailinator/i, /guerrilla/i, /10minute/i,
        /throwaway/i, /yopmail/i, /tempmail/i
    ];
    
    const disposableData = {
        domains: Array.from(allDomains).sort(),
        patterns: patterns.map(p => p.source),
        total: allDomains.size,
        lastUpdated: new Date().toISOString(),
        version: '3.0.0'
    };
    
    // Salvar arquivo
    const outputPath = path.join(__dirname, '../data/lists/disposable.json');
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    fs.writeFileSync(outputPath, JSON.stringify(disposableData, null, 2));
    
    console.log(`✅ Lista de descartáveis atualizada: ${allDomains.size} domínios`);
}

updateDisposableList().catch(console.error);
