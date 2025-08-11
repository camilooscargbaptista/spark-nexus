#!/usr/bin/env node

const https = require('https');
const fs = require('fs');
const path = require('path');

// URLs das listas oficiais
const IANA_TLD_URL = 'https://data.iana.org/TLD/tlds-alpha-by-domain.txt';
const PUBLIC_SUFFIX_URL = 'https://publicsuffix.org/list/public_suffix_list.dat';

async function downloadFile(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (response) => {
            let data = '';
            response.on('data', (chunk) => data += chunk);
            response.on('end', () => resolve(data));
            response.on('error', reject);
        }).on('error', reject);
    });
}

async function updateTLDList() {
    try {
        console.log('📥 Baixando lista IANA...');
        const ianaData = await downloadFile(IANA_TLD_URL);
        
        // Processar TLDs válidos
        const validTLDs = ianaData
            .split('\n')
            .filter(line => !line.startsWith('#') && line.trim())
            .map(tld => tld.toLowerCase().trim());
        
        // TLDs especiais para bloquear
        const blockedTLDs = [
            'test', 'example', 'invalid', 'localhost',
            'local', 'onion', 'exit', 'i2p', 'internal',
            'private', 'corp', 'home', 'lan', 'fake'
        ];
        
        // TLDs suspeitos (alta incidência de spam/fraude)
        const suspiciousTLDs = [
            'tk', 'ml', 'ga', 'cf', 'click', 'download',
            'review', 'top', 'win', 'bid', 'loan', 'work',
            'men', 'date', 'stream', 'gq'
        ];
        
        // TLDs premium (alta confiança)
        const premiumTLDs = [
            'com', 'org', 'net', 'edu', 'gov', 'mil',
            'com.br', 'org.br', 'gov.br', 'edu.br',
            'co.uk', 'ac.uk', 'gov.uk', 'org.uk'
        ];
        
        const tldData = {
            valid: validTLDs,
            blocked: blockedTLDs,
            suspicious: suspiciousTLDs,
            premium: premiumTLDs,
            lastUpdated: new Date().toISOString(),
            totalValid: validTLDs.length,
            version: '3.0.0'
        };
        
        // Salvar arquivo
        const outputPath = path.join(__dirname, '../data/lists/tlds.json');
        fs.mkdirSync(path.dirname(outputPath), { recursive: true });
        fs.writeFileSync(outputPath, JSON.stringify(tldData, null, 2));
        
        console.log(`✅ Lista TLD atualizada: ${validTLDs.length} TLDs válidos`);
        console.log(`🚫 ${blockedTLDs.length} TLDs bloqueados`);
        console.log(`⚠️  ${suspiciousTLDs.length} TLDs suspeitos`);
        console.log(`⭐ ${premiumTLDs.length} TLDs premium`);
        
    } catch (error) {
        console.error('❌ Erro ao atualizar TLDs:', error);
        process.exit(1);
    }
}

updateTLDList();
