// Configuração do Email Service para HostGator
const nodemailer = require('nodemailer');

class EmailService {
    constructor() {
        // Configuração específica para HostGator
        this.transporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST || 'mail.sparknexus.com.br',
            port: parseInt(process.env.SMTP_PORT || 587),
            secure: process.env.SMTP_PORT === '465', // true para 465, false para 587
            auth: {
                user: process.env.SMTP_USER || 'contato@sparknexus.com.br',
                pass: process.env.SMTP_PASS
            },
            tls: {
                rejectUnauthorized: false, // Necessário para HostGator
                ciphers: 'SSLv3'
            },
            debug: true,
            logger: true
        });

        // Verificar conexão ao inicializar
        this.verifyConnection();
    }

    async verifyConnection() {
        try {
            await this.transporter.verify();
            console.log('✅ Conexão com HostGator SMTP estabelecida');
            console.log(`   Server: ${process.env.SMTP_HOST}:${process.env.SMTP_PORT}`);
            console.log(`   User: ${process.env.SMTP_USER}`);
        } catch (error) {
            console.error('❌ Erro ao conectar com SMTP HostGator:', error.message);
            console.log('Verifique:');
            console.log('1. Email e senha estão corretos');
            console.log('2. Porta 587 (TLS) ou 465 (SSL)');
            console.log('3. Autenticação SMTP habilitada no cPanel');
        }
    }

    async sendEmail(to, subject, html, text) {
        try {
            const mailOptions = {
                from: `"${process.env.EMAIL_FROM_NAME || 'Spark Nexus'}" <${process.env.SMTP_FROM || process.env.SMTP_USER}>`,
                to: to,
                subject: subject,
                html: html,
                text: text || html.replace(/<[^>]*>/g, '')
            };

            const info = await this.transporter.sendMail(mailOptions);
            console.log('✅ Email enviado via HostGator:', info.messageId);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            console.error('❌ Erro ao enviar email emailConfig2 56:', error);
            return { success: false, error: error.message };
        }
    }

    async sendTestEmail(to) {
        const subject = '✅ Teste de Configuração - Spark Nexus';
        const html = `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0;">
                    <h1 style="color: white; margin: 0;">🎉 Configuração Bem Sucedida!</h1>
                </div>
                
                <div style="padding: 30px; background: #f8f9fa;">
                    <h2 style="color: #333;">Email HostGator Configurado ✅</h2>
                    <p style="color: #666; line-height: 1.6;">
                        Este é um email de teste enviado através do servidor SMTP do HostGator.
                        Se você está recebendo este email, significa que a configuração está funcionando perfeitamente!
                    </p>
                    
                    <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
                        <h3 style="color: #667eea;">Detalhes da Configuração:</h3>
                        <ul style="color: #666;">
                            <li>Servidor: ${process.env.SMTP_HOST}</li>
                            <li>Porta: ${process.env.SMTP_PORT}</li>
                            <li>Usuário: ${process.env.SMTP_USER}</li>
                            <li>Segurança: ${process.env.SMTP_PORT === '465' ? 'SSL' : 'TLS'}</li>
                        </ul>
                    </div>
                    
                    <p style="color: #666;">
                        Agora você pode usar o sistema Spark Nexus para validar e enviar emails!
                    </p>
                </div>
                
                <div style="background: #333; padding: 20px; text-align: center; border-radius: 0 0 10px 10px;">
                    <p style="color: #999; margin: 0; font-size: 12px;">
                        Spark Nexus - Sistema de Validação de Emails<br>
                        © 2024 - Todos os direitos reservados
                    </p>
                </div>
            </div>
        `;
        
        return await this.sendEmail(to, subject, html);
    }
}

module.exports = EmailService;
