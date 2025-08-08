// ================================================
// Serviço de Email com Nodemailer
// ================================================

const nodemailer = require('nodemailer');

class EmailService {
    constructor() {
      console.log('process.env -------->: ', process.env)
        this.transporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST || 'smtp.titan.email',
            port: parseInt(process.env.SMTP_PORT || '587'),
            secure: process.env.SMTP_SECURE === 'true',
            auth: {
                user: process.env.SMTP_USER || 'contato@sparknexus.com.br',
                pass: process.env.SMTP_PASS || 'Joao@26082310'
            }
        });
    }

    // Enviar email de verificação
    async sendVerificationEmail(to, token, name) {
        const verificationUrl = `${process.env.APP_URL || 'http://localhost:4201'}/verify-email?token=${token}`;

        const mailOptions = {
            from: `"Spark Nexus" <${process.env.SMTP_USER || 'contato@sparknexus.com.br'}>`,
            to,
            subject: '🔐 Verificação de Email - Spark Nexus',
            html: `
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                        .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
                        .token-box { background: white; border: 2px dashed #667eea; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px; }
                        .token { font-size: 32px; font-weight: bold; color: #667eea; letter-spacing: 5px; }
                        .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                        .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h1>🚀 Spark Nexus</h1>
                            <p>Verificação de Email</p>
                        </div>
                        <div class="content">
                            <h2>Olá ${name}!</h2>
                            <p>Obrigado por se cadastrar no Spark Nexus. Para completar seu cadastro, precisamos verificar seu email.</p>

                            <div class="token-box">
                                <p>Seu código de verificação é:</p>
                                <div class="token">${token}</div>
                            </div>

                            <p>Ou clique no botão abaixo:</p>
                            <div style="text-align: center;">
                                <a href="${verificationUrl}" class="button">Verificar Email</a>
                            </div>

                            <p><strong>⏰ Este código expira em 30 minutos.</strong></p>

                            <div class="footer">
                                <p>Se você não solicitou este email, pode ignorá-lo com segurança.</p>
                                <p>© 2024 Spark Nexus. Todos os direitos reservados.</p>
                            </div>
                        </div>
                    </div>
                </body>
                </html>
            `
        };

        try {
          console.log(mailOptions);
            const info = await this.transporter.sendMail(mailOptions);
            console.log('Email enviado:', info.messageId);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            console.error('Erro ao enviar email EmailService:', error);
            return { success: false, error: error.message };
        }
    }

    // Enviar email de boas-vindas
    async sendWelcomeEmail(to, name) {
        const mailOptions = {
            from: `"Spark Nexus" <${process.env.SMTP_USER || 'contato@sparknexus.com.br'}>`,
            to,
            subject: '🎉 Bem-vindo ao Spark Nexus!',
            html: `
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                        .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
                        .feature { background: white; padding: 15px; margin: 10px 0; border-radius: 8px; border-left: 4px solid #667eea; }
                        .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h1>🚀 Bem-vindo ao Spark Nexus!</h1>
                        </div>
                        <div class="content">
                            <h2>Olá ${name}!</h2>
                            <p>Sua conta foi criada com sucesso! Agora você tem acesso a todas as nossas ferramentas:</p>

                            <div class="feature">
                                <strong>📧 Email Validator</strong>
                                <p>Valide listas de emails em lote com alta precisão</p>
                            </div>

                            <div class="feature">
                                <strong>🔗 CRM Connector</strong>
                                <p>Integre com os principais CRMs do mercado</p>
                            </div>

                            <div class="feature">
                                <strong>🎯 Lead Scorer AI</strong>
                                <p>Score automático de leads com Machine Learning</p>
                            </div>

                            <div style="text-align: center;">
                                <a href="http://localhost:4201" class="button">Acessar Dashboard</a>
                            </div>

                            <p>Qualquer dúvida, estamos à disposição!</p>
                            <p>Equipe Spark Nexus</p>
                        </div>
                    </div>
                </body>
                </html>
            `
        };

        try {
            await this.transporter.sendMail(mailOptions);
            return { success: true };
        } catch (error) {
            console.error('Erro ao enviar email de boas-vindas:', error);
            return { success: false, error: error.message };
        }
    }
}

module.exports = EmailService;
