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

    // Enviar relatório de validação
    async sendValidationReport(to, reportData, attachmentPath, userInfo = {}) {
        const stats = reportData.stats || {};
        const filename = reportData.filename || 'validation_report.xlsx';
        
        const mailOptions = {
            from: `"Spark Nexus" <${process.env.SMTP_USER || 'contato@sparknexus.com.br'}>`,
            to,
            subject: '📊 Seu Relatório de Validação de Emails está Pronto!',
            attachments: [
                {
                    filename: filename,
                    path: attachmentPath
                }
            ],
            html: `
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; background: #f5f5f5; }
                        .container { max-width: 700px; margin: 0 auto; background: white; }
                        .header { 
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                            color: white; 
                            padding: 40px 30px; 
                            text-align: center; 
                        }
                        .header h1 { margin: 0; font-size: 28px; }
                        .header p { margin: 10px 0 0 0; opacity: 0.9; }
                        .content { padding: 40px 30px; }
                        .stats-grid { 
                            display: grid; 
                            grid-template-columns: repeat(2, 1fr); 
                            gap: 20px; 
                            margin: 30px 0;
                        }
                        .stat-card {
                            background: #f8f9fa;
                            padding: 20px;
                            border-radius: 8px;
                            border-left: 4px solid #667eea;
                        }
                        .stat-value { 
                            font-size: 32px; 
                            font-weight: bold; 
                            color: #667eea;
                            margin: 5px 0;
                        }
                        .stat-label { 
                            color: #666; 
                            font-size: 14px;
                            text-transform: uppercase;
                            letter-spacing: 1px;
                        }
                        .highlight-box {
                            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
                            padding: 25px;
                            border-radius: 10px;
                            margin: 30px 0;
                            text-align: center;
                        }
                        .score-badge {
                            display: inline-block;
                            font-size: 48px;
                            font-weight: bold;
                            color: white;
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                            width: 100px;
                            height: 100px;
                            line-height: 100px;
                            border-radius: 50%;
                            margin: 20px auto;
                        }
                        .button {
                            display: inline-block;
                            padding: 15px 40px;
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                            color: white;
                            text-decoration: none;
                            border-radius: 30px;
                            font-weight: bold;
                            margin: 20px 0;
                        }
                        .features {
                            background: #f8f9fa;
                            padding: 20px;
                            border-radius: 8px;
                            margin: 20px 0;
                        }
                        .feature-item {
                            padding: 10px 0;
                            border-bottom: 1px solid #e9ecef;
                        }
                        .feature-item:last-child { border-bottom: none; }
                        .footer {
                            background: #2c3e50;
                            color: white;
                            padding: 30px;
                            text-align: center;
                        }
                        .footer p { margin: 5px 0; opacity: 0.8; }
                        .valid { color: #00a652; font-weight: bold; }
                        .invalid { color: #e74c3c; font-weight: bold; }
                        @media (max-width: 600px) {
                            .stats-grid { grid-template-columns: 1fr; }
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h1>📊 Relatório de Validação Concluído!</h1>
                            <p>Sua análise detalhada está pronta</p>
                        </div>
                        
                        <div class="content">
                            <p>Olá <strong>${userInfo.name || 'Cliente Spark Nexus'}</strong>,</p>
                            
                            <p>Seu relatório de validação de emails foi gerado com sucesso! 
                            Analisamos <strong>${stats.total || 0}</strong> emails e preparamos 
                            uma análise completa com gráficos e recomendações personalizadas.</p>
                            
                            <div class="highlight-box">
                                <div class="stat-label">Score de Qualidade da Lista</div>
                                <div class="score-badge">${Math.round(stats.avgScore || 0)}</div>
                                <p style="margin: 10px 0; color: #666;">
                                    Classificação: <strong>${stats.avgScore >= 70 ? 'Excelente' : stats.avgScore >= 50 ? 'Boa' : 'Necessita Atenção'}</strong>
                                </p>
                            </div>
                            
                            <div class="stats-grid">
                                <div class="stat-card">
                                    <div class="stat-label">Emails Válidos</div>
                                    <div class="stat-value valid">${stats.valid || 0}</div>
                                    <div style="color: #666;">${stats.validPercentage || 0}% do total</div>
                                </div>
                                
                                <div class="stat-card">
                                    <div class="stat-label">Emails Inválidos</div>
                                    <div class="stat-value invalid">${stats.invalid || 0}</div>
                                    <div style="color: #666;">${stats.invalidPercentage || 0}% do total</div>
                                </div>
                                
                                <div class="stat-card">
                                    <div class="stat-label">Taxa de Confiabilidade</div>
                                    <div class="stat-value">${stats.reliabilityRate || 0}%</div>
                                    <div style="color: #666;">Emails com score > 70</div>
                                </div>
                                
                                <div class="stat-card">
                                    <div class="stat-label">Total Analisado</div>
                                    <div class="stat-value">${stats.total || 0}</div>
                                    <div style="color: #666;">Emails processados</div>
                                </div>
                            </div>
                            
                            <div class="features">
                                <h3 style="color: #667eea; margin-top: 0;">📎 Arquivo em Anexo Contém:</h3>
                                <div class="feature-item">
                                    ✅ <strong>Resumo Executivo</strong> - Visão geral dos resultados
                                </div>
                                <div class="feature-item">
                                    📊 <strong>Dados Detalhados</strong> - Análise individual de cada email
                                </div>
                                <div class="feature-item">
                                    📈 <strong>Estatísticas Avançadas</strong> - Métricas e distribuições
                                </div>
                                <div class="feature-item">
                                    🌐 <strong>Análise de Domínios</strong> - Insights sobre os domínios
                                </div>
                                <div class="feature-item">
                                    💡 <strong>Recomendações</strong> - Ações sugeridas para melhorar sua base
                                </div>
                            </div>
                            
                            <div style="text-align: center; margin: 40px 0;">
                                <p style="color: #666; margin-bottom: 20px;">
                                    Abra o arquivo Excel anexo para visualizar todos os detalhes, 
                                    gráficos e análises completas.
                                </p>
                                <a href="http://localhost:4201" class="button">
                                    Acessar Dashboard
                                </a>
                            </div>
                            
                            <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
                                <strong>💡 Dica:</strong> Use os filtros do Excel para segmentar os dados 
                                e as abas para navegar entre diferentes análises. Todas as planilhas 
                                estão formatadas e prontas para apresentação.
                            </div>
                        </div>
                        
                        <div class="footer">
                            <h3 style="margin-top: 0;">🚀 Spark Nexus</h3>
                            <p>Validação Inteligente de Emails</p>
                            <p style="font-size: 12px; margin-top: 20px;">
                                © 2024 Spark Nexus. Todos os direitos reservados.<br>
                                Este relatório é confidencial e destinado apenas ao destinatário.
                            </p>
                        </div>
                    </div>
                </body>
                </html>
            `
        };

        try {
            const info = await this.transporter.sendMail(mailOptions);
            console.log('Relatório enviado:', info.messageId);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            console.error('Erro ao enviar relatório:', error);
            return { success: false, error: error.message };
        }
    }
}

module.exports = EmailService;