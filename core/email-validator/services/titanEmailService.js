// Serviço de Email - Titan Email (HostGator)
const nodemailer = require('nodemailer');

class TitanEmailService {
    constructor() {
        // Configuração específica para Titan Email
        this.transporter = nodemailer.createTransport({
            host: 'smtp.titan.email',
            port: parseInt(process.env.SMTP_PORT || 587),
            secure: false, // false para TLS/STARTTLS
            auth: {
                user: process.env.SMTP_USER,
                pass: process.env.SMTP_PASS
            },
            tls: {
                ciphers: 'SSLv3',
                rejectUnauthorized: false
            },
            requireTLS: true,
            connectionTimeout: 10000,
            greetingTimeout: 10000,
            debug: true,
            logger: true
        });

        this.verifyConnection();
    }

    async verifyConnection() {
        try {
            console.log('🔌 Conectando ao Titan Email...');
            await this.transporter.verify();
            console.log('✅ Conexão com Titan Email estabelecida!');
            console.log(`   Server: smtp.titan.email:${process.env.SMTP_PORT}`);
            console.log(`   User: ${process.env.SMTP_USER}`);
            return true;
        } catch (error) {
            console.error('❌ Erro ao conectar com Titan Email:', error.message);
            console.log('\nVerifique:');
            console.log('1. Email: contato@sparknexus.com.br');
            console.log('2. Senha: A senha do Titan Email (não do cPanel)');
            console.log('3. Acesse: https://mail.titan.email para confirmar credenciais');
            return false;
        }
    }

    async sendEmail(to, subject, html, text) {
        try {
            const mailOptions = {
                from: `"${process.env.EMAIL_FROM_NAME || 'Spark Nexus'}" <${process.env.SMTP_FROM}>`,
                to: to,
                subject: subject,
                html: html,
                text: text || html.replace(/<[^>]*>/g, ''),
                headers: {
                    'X-Mailer': 'Spark Nexus Email System',
                    'X-Priority': '3'
                }
            };

            console.log(`📧 Enviando email para: ${to}`);
            const info = await this.transporter.sendMail(mailOptions);
            console.log('✅ Email enviado via Titan:', info.messageId);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            console.error('❌ Erro ao enviar email titanEmailService:', error);
            return { success: false, error: error.message };
        }
    }

    async sendTestEmail() {
        const to = process.env.SMTP_USER;
        const subject = '✅ Titan Email Configurado - Spark Nexus';
        const html = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
                    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; }
                    .header h1 { color: white; margin: 0; font-size: 28px; }
                    .content { padding: 30px; }
                    .success-box { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin: 20px 0; }
                    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                    .info-table td { padding: 10px; border-bottom: 1px solid #eee; }
                    .info-table td:first-child { font-weight: bold; color: #667eea; width: 40%; }
                    .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 12px; }
                    .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🚀 Spark Nexus</h1>
                        <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0;">Sistema de Validação de Emails</p>
                    </div>
                    
                    <div class="content">
                        <div class="success-box">
                            <h2 style="margin: 0 0 10px 0;">✅ Titan Email Configurado com Sucesso!</h2>
                            <p style="margin: 0;">Seu sistema está pronto para enviar emails através do Titan Email.</p>
                        </div>
                        
                        <h3 style="color: #333;">Detalhes da Configuração:</h3>
                        <table class="info-table">
                            <tr>
                                <td>Servidor SMTP:</td>
                                <td>smtp.titan.email</td>
                            </tr>
                            <tr>
                                <td>Porta:</td>
                                <td>${process.env.SMTP_PORT}</td>
                            </tr>
                            <tr>
                                <td>Segurança:</td>
                                <td>TLS/STARTTLS</td>
                            </tr>
                            <tr>
                                <td>Email:</td>
                                <td>${process.env.SMTP_USER}</td>
                            </tr>
                            <tr>
                                <td>Data/Hora:</td>
                                <td>${new Date().toLocaleString('pt-BR')}</td>
                            </tr>
                        </table>
                        
                        <div style="text-align: center;">
                            <a href="http://localhost:4201/upload" class="button">Acessar Sistema</a>
                        </div>
                        
                        <h3 style="color: #333;">Próximos Passos:</h3>
                        <ol style="color: #666; line-height: 1.8;">
                            <li>Acesse o sistema em <a href="http://localhost:4201/upload">http://localhost:4201/upload</a></li>
                            <li>Faça upload de uma lista de emails para validar</li>
                            <li>Você receberá o relatório neste email</li>
                        </ol>
                    </div>
                    
                    <div class="footer">
                        <p>Este é um email automático enviado pelo sistema Spark Nexus.</p>
                        <p>Powered by Titan Email - HostGator</p>
                    </div>
                </div>
            </body>
            </html>
        `;
        
        return await this.sendEmail(to, subject, html);
    }
}

module.exports = TitanEmailService;
