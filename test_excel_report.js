// ================================================
// TESTE DO SISTEMA DE RELATÓRIOS EXCEL
// ================================================

const ReportEmailService = require('./core/client-dashboard/services/reports/ReportEmailService');

async function testReportGeneration() {
    console.log('\n========================================');
    console.log('🧪 TESTANDO GERAÇÃO DE RELATÓRIO EXCEL');
    console.log('========================================\n');
    
    // Dados de teste simulando validação completa
    const testResults = [
        {
            email: 'carolinacasaquia@gmail.com',
            valid: true,
            score: 96,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: true, isPremium: true },
                disposable: { isDisposable: false },
                patterns: { suspicious: false },
                mx: { valid: true },
                smtp: { exists: true }
            },
            ecommerce: {
                score: 96,
                buyerType: 'PREMIUM_BUYER',
                riskLevel: 'VERY_LOW',
                fraudProbability: 4,
                confidence: 'very_high',
                insights: {
                    trustedProvider: true,
                    corporateEmail: false,
                    personalEmail: true
                }
            },
            recommendations: [
                {
                    action: 'APPROVE',
                    message: 'Aprovar compra normalmente',
                    priority: 'low'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 1234,
                validatorVersion: '3.0.0'
            }
        },
        {
            email: 'test@example.com',
            valid: false,
            score: 0,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: false, isBlocked: true },
                disposable: { isDisposable: false },
                patterns: { suspicious: true, suspicionLevel: 8 },
                mx: { valid: false },
                smtp: { exists: false }
            },
            ecommerce: {
                score: 0,
                buyerType: 'BLOCKED',
                riskLevel: 'BLOCKED',
                fraudProbability: 100,
                confidence: 'certain',
                insights: {
                    blocked: true,
                    blockReason: 'Domínio de teste'
                }
            },
            recommendations: [
                {
                    action: 'BLOCK',
                    message: 'Domínio de teste/exemplo',
                    priority: 'critical'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 456,
                validatorVersion: '3.0.0'
            }
        },
        {
            email: 'joao.silva@outlook.com',
            valid: true,
            score: 85,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: true, isPremium: true },
                disposable: { isDisposable: false },
                patterns: { suspicious: false },
                mx: { valid: true },
                smtp: { exists: true }
            },
            ecommerce: {
                score: 85,
                buyerType: 'TRUSTED_BUYER',
                riskLevel: 'VERY_LOW',
                fraudProbability: 15,
                confidence: 'very_high',
                insights: {
                    trustedProvider: true,
                    corporateEmail: false,
                    personalEmail: true
                }
            },
            recommendations: [
                {
                    action: 'APPROVE',
                    message: 'Aprovar compra normalmente',
                    priority: 'low'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 890,
                validatorVersion: '3.0.0'
            }
        },
        {
            email: 'admin@tempmail.com',
            valid: false,
            score: 0,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: true },
                disposable: { isDisposable: true },
                patterns: { suspicious: true, suspicionLevel: 9 },
                mx: { valid: false },
                smtp: { exists: false }
            },
            ecommerce: {
                score: 0,
                buyerType: 'HIGH_RISK_BUYER',
                riskLevel: 'VERY_HIGH',
                fraudProbability: 100,
                confidence: 'certain',
                insights: {
                    blocked: true,
                    blockReason: 'Email temporário'
                }
            },
            recommendations: [
                {
                    action: 'BLOCK',
                    message: 'Email temporário detectado',
                    priority: 'critical'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 234,
                validatorVersion: '3.0.0'
            }
        },
        {
            email: 'contato@empresa.com.br',
            valid: true,
            score: 72,
            validations: {
                format: { valid: true },
                syntax: { valid: true },
                tld: { valid: true },
                disposable: { isDisposable: false },
                patterns: { suspicious: false },
                mx: { valid: true },
                smtp: { exists: true, catchAll: true }
            },
            ecommerce: {
                score: 72,
                buyerType: 'REGULAR_BUYER',
                riskLevel: 'LOW',
                fraudProbability: 28,
                confidence: 'high',
                insights: {
                    trustedProvider: false,
                    corporateEmail: true,
                    personalEmail: false
                }
            },
            recommendations: [
                {
                    action: 'APPROVE_WITH_MONITORING',
                    message: 'Aprovar mas monitorar comportamento',
                    priority: 'medium'
                }
            ],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 1567,
                validatorVersion: '3.0.0'
            }
        }
    ];
    
    const reportService = new ReportEmailService();
    
    // Testar geração local primeiro
    console.log('📊 Gerando relatório Excel localmente...');
    const ExcelReportGenerator = require('./core/client-dashboard/services/reports/ExcelReportGenerator');
    const generator = new ExcelReportGenerator();
    
    const localResult = await generator.generateReport(testResults, {
        outputDir: './reports'
    });
    
    if (localResult.success) {
        console.log(`✅ Relatório gerado: ${localResult.filename}`);
        console.log('\n📈 Estatísticas:');
        console.log(`  Total: ${localResult.stats.total}`);
        console.log(`  Válidos: ${localResult.stats.valid} (${localResult.stats.validPercentage}%)`);
        console.log(`  Inválidos: ${localResult.stats.invalid} (${localResult.stats.invalidPercentage}%)`);
        console.log(`  Score Médio: ${localResult.stats.avgScore}`);
    }
    
    // Perguntar se quer enviar por email
    console.log('\n📧 Para testar o envio por email, configure:');
    console.log('  const SEND_EMAIL = true;');
    console.log('  const RECIPIENT = "seu-email@exemplo.com";');
    
    // Configurar para teste de email
    const SEND_EMAIL = false; // Mude para true para testar
    const RECIPIENT = 'contato@sparknexus.com.br'; // Coloque o email de teste
    
    if (SEND_EMAIL) {
        console.log(`\n📧 Enviando relatório para ${RECIPIENT}...`);
        
        const emailResult = await reportService.generateAndSendReport(
            testResults,
            RECIPIENT,
            { name: 'Teste Spark Nexus' }
        );
        
        if (emailResult.success) {
            console.log('✅ Email enviado com sucesso!');
        } else {
            console.log('❌ Erro ao enviar email:', emailResult.error);
        }
    }
    
    console.log('\n========================================\n');
}

// Executar teste
testReportGeneration().catch(console.error);
