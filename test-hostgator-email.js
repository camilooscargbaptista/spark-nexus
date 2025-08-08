// Script de Teste - HostGator Email
require('dotenv').config();
const nodemailer = require('nodemailer');

console.log('🧪 Testando configuração HostGator...\n');
console.log('Configuração:');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log(`Host: ${process.env.SMTP_HOST}`);
console.log(`Port: ${process.env.SMTP_PORT}`);
console.log(`User: ${process.env.SMTP_USER}`);
console.log(`From: ${process.env.SMTP_FROM}`);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

async function testEmail() {
    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST || 'mail.sparknexus.com.br',
        port: parseInt(process.env.SMTP_PORT || 587),
        secure: process.env.SMTP_PORT === '465',
        auth: {
            user: process.env.SMTP_USER || 'contato@sparknexus.com.br',
            pass: process.env.SMTP_PASS
        },
        tls: {
            rejectUnauthorized: false,
            ciphers: 'SSLv3'
        }
    });

    try {
        console.log('📡 Verificando conexão...');
        await transporter.verify();
        console.log('✅ Conexão estabelecida!\n');
        
        console.log('📧 Enviando email de teste...');
        const info = await transporter.sendMail({
            from: `"Spark Nexus" <${process.env.SMTP_FROM || process.env.SMTP_USER}>`,
            to: process.env.SMTP_USER,
            subject: '✅ Teste HostGator - Spark Nexus',
            html: '<h2>Email de teste enviado com sucesso!</h2><p>HostGator SMTP funcionando.</p>'
        });
        
        console.log('✅ Email enviado!');
        console.log('Message ID:', info.messageId);
        console.log('\n🎉 Configuração funcionando perfeitamente!');
        
    } catch (error) {
        console.error('\n❌ Erro:', error.message);
        console.log('\n🔧 Soluções:');
        console.log('1. Verifique email e senha');
        console.log('2. No cPanel, verifique se SMTP está habilitado');
        console.log('3. Tente porta 465 ao invés de 587');
        console.log('4. Verifique firewall/antivirus local');
    }
}

testEmail();
