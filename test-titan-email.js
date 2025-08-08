// Teste do Titan Email
require('dotenv').config();
const nodemailer = require('nodemailer');

console.log('\n⚡ TESTE TITAN EMAIL - HOSTGATOR');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('Servidor: smtp.titan.email');
console.log('Porta:', process.env.SMTP_PORT);
console.log('Usuário:', process.env.SMTP_USER);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

async function testTitanEmail() {
    const transporter = nodemailer.createTransport({
        host: 'smtp.titan.email',
        port: parseInt(process.env.SMTP_PORT || 587),
        secure: false,
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS
        },
        tls: {
            rejectUnauthorized: false,
            ciphers: 'SSLv3'
        },
        requireTLS: true,
        debug: true
    });

    try {
        console.log('🔌 Conectando ao Titan Email...');
        await transporter.verify();
        console.log('✅ CONEXÃO ESTABELECIDA!\n');
        
        console.log('📧 Enviando email de teste...');
        const info = await transporter.sendMail({
            from: `"Spark Nexus Test" <${process.env.SMTP_USER}>`,
            to: process.env.SMTP_USER,
            subject: '✅ Titan Email Funcionando - ' + new Date().toLocaleString('pt-BR'),
            html: `
                <div style="font-family: Arial; padding: 20px; background: #f5f5f5;">
                    <div style="background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                        <h2 style="color: #28a745;">✅ Titan Email Configurado!</h2>
                        <p>Este email confirma que o Titan Email está funcionando corretamente com o Spark Nexus.</p>
                        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                        <p><strong>Detalhes:</strong></p>
                        <ul>
                            <li>Servidor: smtp.titan.email</li>
                            <li>Porta: ${process.env.SMTP_PORT}</li>
                            <li>Email: ${process.env.SMTP_USER}</li>
                            <li>Data/Hora: ${new Date().toLocaleString('pt-BR')}</li>
                        </ul>
                        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                        <p style="color: #666; font-size: 12px;">
                            Spark Nexus - Sistema de Validação de Emails<br>
                            Powered by Titan Email
                        </p>
                    </div>
                </div>
            `
        });
        
        console.log('\n✅ EMAIL ENVIADO COM SUCESSO!');
        console.log('Message ID:', info.messageId);
        console.log('\n🎉 TITAN EMAIL CONFIGURADO E FUNCIONANDO!\n');
        console.log('📌 Verifique sua caixa de entrada em:');
        console.log('   https://mail.titan.email');
        console.log('   ou no seu cliente de email\n');
        
    } catch (error) {
        console.error('\n❌ ERRO:', error.message);
        
        if (error.code === 'EAUTH') {
            console.log('\n🔐 Erro de Autenticação:');
            console.log('1. Verifique se o email está correto: contato@sparknexus.com.br');
            console.log('2. A senha deve ser a do Titan Email (não do cPanel)');
            console.log('3. Acesse https://mail.titan.email para testar suas credenciais');
            console.log('4. Se esqueceu a senha, redefina no painel do Titan');
        } else if (error.code === 'ECONNECTION' || error.code === 'ETIMEDOUT') {
            console.log('\n🌐 Erro de Conexão:');
            console.log('1. Verifique sua conexão com a internet');
            console.log('2. Tente a porta 465 ao invés de 587');
            console.log('3. Verifique se não há firewall bloqueando');
        } else {
            console.log('\n📝 Dicas:');
            console.log('1. Certifique-se de que o Titan Email está ativo');
            console.log('2. Verifique no painel do HostGator se o serviço está OK');
            console.log('3. Tente fazer login em https://mail.titan.email');
        }
        
        console.log('\n💡 Para redefinir a senha do Titan Email:');
        console.log('1. Acesse o cPanel do HostGator');
        console.log('2. Vá em "Gerenciar E-mail Titan"');
        console.log('3. Clique em "Gerenciar" ao lado do email');
        console.log('4. Use a opção de redefinir senha');
    }
}

testTitanEmail();
