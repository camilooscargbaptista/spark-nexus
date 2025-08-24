// ================================================
// Serviço de Validação Assíncrona
// Responsável por processar validações em background
// ================================================

const EventEmitter = require('events');
const { v4: uuidv4 } = require('uuid');

class AsyncValidationService extends EventEmitter {
    constructor(options = {}) {
        super();
        
        this.db = options.db;
        this.emailService = options.emailService;
        this.ultimateValidator = options.ultimateValidator;
        this.reportEmailService = options.reportEmailService;
        
        // Job queue (em memória - para produção usar Redis/Bull)
        this.jobQueue = new Map();
        this.activeJobs = new Map();
        
        // Configurações
        this.maxConcurrentJobs = options.maxConcurrentJobs || 3;
        this.jobTimeout = options.jobTimeout || 30 * 60 * 1000; // 30 minutos
        
        console.log('[ASYNC] Serviço de validação assíncrona inicializado');
        
        // Processar jobs na inicialização
        this.processJobs();
    }
    
    /**
     * Criar um novo job de validação
     */
    async createValidationJob(jobData) {
        const jobId = uuidv4();
        const job = {
            id: jobId,
            type: 'email_validation',
            data: jobData,
            status: 'pending',
            createdAt: new Date(),
            attempts: 0,
            maxAttempts: 3
        };
        
        // Salvar job na queue
        this.jobQueue.set(jobId, job);
        
        console.log(`[ASYNC] Job criado: ${jobId} para ${jobData.emailsList.length} emails`);
        
        // Emitir evento para notificar que novo job foi criado
        this.emit('job-created', job);
        
        // Tentar processar imediatamente se houver capacidade
        setImmediate(() => this.processJobs());
        
        return jobId;
    }
    
    /**
     * Processar jobs da fila
     */
    async processJobs() {
        // Verificar se há capacidade para processar mais jobs
        if (this.activeJobs.size >= this.maxConcurrentJobs) {
            return;
        }
        
        // Buscar próximo job pendente
        const pendingJob = Array.from(this.jobQueue.values())
            .find(job => job.status === 'pending');
        
        if (!pendingJob) {
            return;
        }
        
        // Mover job para processamento ativo
        this.jobQueue.delete(pendingJob.id);
        this.activeJobs.set(pendingJob.id, pendingJob);
        
        // Processar job
        this.processValidationJob(pendingJob);
        
        // Tentar processar próximo job se houver
        setImmediate(() => this.processJobs());
    }
    
    /**
     * Processar um job de validação específico
     */
    async processValidationJob(job) {
        const startTime = Date.now();
        let validationHistoryId = null;
        
        try {
            job.status = 'processing';
            job.startedAt = new Date();
            
            console.log(`[ASYNC] Iniciando processamento do job ${job.id}`);
            
            const { 
                organizationId, 
                userId, 
                emailsList, 
                emailsWithInfo, 
                parseResult, 
                userData,
                fileName,
                fileSize 
            } = job.data;
            
            // 1. Verificar se já existe registro para este batch_id
            const existingRecord = await this.db.pool.query(
                `SELECT id, status FROM validation.validation_history WHERE batch_id = $1`,
                [job.id]
            );
            
            if (existingRecord.rows.length > 0) {
                const existing = existingRecord.rows[0];
                if (existing.status === 'processing' || existing.status === 'completed') {
                    throw new Error(`Job ${job.id} já está sendo processado ou foi completado`);
                } else if (existing.status === 'failed') {
                    // Se falhou antes, vamos tentar novamente mas usar o ID existente
                    validationHistoryId = existing.id;
                    console.log(`[ASYNC] Reprocessando job falhado: ${job.id} (ID: ${validationHistoryId})`);
                }
            } else {
                // Criar novo registro no histórico
                validationHistoryId = await this.db.pool.query(
                    `SELECT validation.start_validation($1, $2, $3, $4, $5, $6, $7) as validation_id`,
                    [
                        organizationId,
                        userId,
                        job.id,
                        'file_upload',
                        emailsList.length,
                        fileName,
                        fileSize
                    ]
                ).then(result => result.rows[0].validation_id);
                
                console.log(`[ASYNC] Novo registro de histórico criado: ${validationHistoryId}`);
            }
            
            // 2. Processar validação dos emails
            console.log(`[ASYNC] Validando ${emailsList.length} emails...`);
            
            const validationPromises = emailsList.map((email, index) => {
                const emailInfo = emailsWithInfo[index];
                return this.ultimateValidator.validateEmail(email).then(result => ({
                    ...result,
                    wasPreCorrected: emailInfo.wasCorrected,
                    originalEmailBeforeCorrection: emailInfo.originalEmail,
                    correctionAppliedDuringParse: emailInfo.correctionDetails,
                    isDuplicate: emailInfo.isDuplicate,
                    duplicateIndex: emailInfo.duplicateIndex,
                    duplicateCount: emailInfo.duplicateCount,
                    originalLine: emailInfo.originalLine
                }));
            });
            
            // Processar em lotes para evitar sobrecarga
            const batchSize = 100;
            const validationResults = [];
            
            for (let i = 0; i < validationPromises.length; i += batchSize) {
                const batch = validationPromises.slice(i, i + batchSize);
                const batchResults = await Promise.all(batch);
                validationResults.push(...batchResults);
                
                // Atualizar progresso
                const processed = Math.min(i + batchSize, validationPromises.length);
                const progress = Math.round((processed / validationPromises.length) * 100);
                
                console.log(`[ASYNC] Progresso: ${processed}/${validationPromises.length} (${progress}%)`);
                
                // Emitir evento de progresso
                this.emit('job-progress', {
                    jobId: job.id,
                    processed,
                    total: validationPromises.length,
                    progress
                });
                
                // Pequena pausa entre lotes para não sobrecarregar
                if (i + batchSize < validationPromises.length) {
                    await new Promise(resolve => setTimeout(resolve, 100));
                }
            }
            
            // 3. Calcular estatísticas
            const validCount = validationResults.filter(r => r.valid).length;
            const avgScore = validationResults.reduce((acc, r) => acc + r.score, 0) / validationResults.length;
            const qualityScore = this.calculateQualityScore(validationResults);
            const successRate = (validCount / emailsList.length) * 100;
            
            const processingTime = Math.round((Date.now() - startTime) / 1000);
            
            // 4. Consumir créditos
            const useCreditsResult = await this.db.pool.query(
                `SELECT tenant.use_credits($1, $2, $3) as new_balance`,
                [
                    organizationId,
                    emailsList.length,
                    `Validação assíncrona de ${emailsList.length} emails - Job: ${job.id}`
                ]
            );
            
            const newBalance = useCreditsResult.rows[0].new_balance;
            console.log(`[ASYNC] Consumidos ${emailsList.length} créditos. Saldo: ${newBalance}`);
            
            // 5. Salvar detalhes de correções
            const correctionsApplied = {
                totalCorrections: parseResult.stats.correctedCount,
                correctionRate: parseResult.stats.correctionRate,
                correctionTypes: this.summarizeCorrections(parseResult.correctedEmails)
            };
            
            // 6. Finalizar registro no histórico
            await this.db.pool.query(
                `SELECT validation.complete_validation($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
                [
                    validationHistoryId,
                    emailsList.length, // emails_processed
                    validCount, // emails_valid
                    emailsList.length - validCount, // emails_invalid
                    parseResult.stats.correctedCount, // emails_corrected
                    parseResult.stats.duplicatesCount, // emails_duplicated
                    Math.min(successRate, 999.99), // success_rate (limitado a 999.99)
                    Math.min(qualityScore, 999.99), // quality_score (limitado a 999.99)
                    Math.min(avgScore * 100, 999.99), // average_score (limitado a 999.99)
                    emailsList.length, // credits_consumed
                    processingTime, // processing_time_seconds
                    JSON.stringify(correctionsApplied) // corrections_applied
                ]
            );
            
            // 7. Gerar e enviar relatório
            console.log(`[ASYNC] Gerando relatório para ${userData.email}`);
            
            const userInfo = {
                name: userData.fullName,
                email: userData.email,
                company: userData.company,
                phone: userData.phone
            };
            
            const reportResult = await this.reportEmailService.generateAndSendReport(
                validationResults,
                userData.email,
                userInfo
            );
            
            // 8. Finalizar job
            job.status = 'completed';
            job.completedAt = new Date();
            job.result = {
                validationHistoryId,
                totalEmails: emailsList.length,
                validEmails: validCount,
                invalidEmails: emailsList.length - validCount,
                successRate: Math.min(successRate, 999.99),
                qualityScore: Math.min(qualityScore, 999.99),
                averageScore: Math.min(avgScore * 100, 999.99),
                creditsConsumed: emailsList.length,
                newBalance,
                processingTime,
                reportSent: true,
                reportDetails: reportResult
            };
            
            console.log(`[ASYNC] Job ${job.id} concluído com sucesso`);
            
            // Emitir evento de conclusão
            this.emit('job-completed', {
                jobId: job.id,
                result: job.result
            });
            
        } catch (error) {
            console.error(`[ASYNC] Erro no job ${job.id}:`, error);
            
            // Finalizar registro com erro se foi criado
            if (validationHistoryId) {
                try {
                    await this.db.pool.query(
                        `UPDATE validation.validation_history 
                         SET status = 'failed', 
                             error_message = $2,
                             completed_at = CURRENT_TIMESTAMP
                         WHERE id = $1`,
                        [validationHistoryId, error.message]
                    );
                } catch (updateError) {
                    console.error(`[ASYNC] Erro ao atualizar histórico:`, updateError);
                }
            }
            
            // Verificar se deve tentar novamente
            job.attempts++;
            if (job.attempts < job.maxAttempts) {
                console.log(`[ASYNC] Recolocando job ${job.id} na fila (tentativa ${job.attempts})`);
                job.status = 'pending';
                job.error = error.message;
                this.jobQueue.set(job.id, job);
                
                // Reagendar processamento
                setTimeout(() => this.processJobs(), 5000);
            } else {
                console.log(`[ASYNC] Job ${job.id} falhou após ${job.attempts} tentativas`);
                job.status = 'failed';
                job.completedAt = new Date();
                job.error = error.message;
                
                // Emitir evento de falha
                this.emit('job-failed', {
                    jobId: job.id,
                    error: error.message,
                    attempts: job.attempts
                });
            }
        } finally {
            // NÃO remover job dos ativos imediatamente se completou com sucesso
            // Manter na memória para que a interface possa recuperar o status final
            if (job.status === 'completed' || job.status === 'failed') {
                // Agendar remoção após 30 segundos para dar tempo da interface recuperar
                setTimeout(() => {
                    this.activeJobs.delete(job.id);
                    console.log(`[ASYNC] Job ${job.id} removido da memória após conclusão`);
                }, 30000);
            } else {
                // Se não completou, remover imediatamente
                this.activeJobs.delete(job.id);
            }
            
            // Tentar processar próximo job
            setImmediate(() => this.processJobs());
        }
    }
    
    /**
     * Calcular score de qualidade baseado nos resultados
     */
    calculateQualityScore(results) {
        if (results.length === 0) return 0;
        
        let totalScore = 0;
        let weightedCount = 0;
        
        results.forEach(result => {
            if (result.valid) {
                totalScore += result.score * 100;
                weightedCount++;
            }
        });
        
        return weightedCount > 0 ? Math.round(totalScore / weightedCount) : 0;
    }
    
    /**
     * Resumir correções aplicadas
     */
    summarizeCorrections(correctedEmails) {
        const summary = {};
        
        correctedEmails.forEach(correction => {
            const type = correction.correction.type;
            if (!summary[type]) {
                summary[type] = 0;
            }
            summary[type]++;
        });
        
        return summary;
    }
    
    /**
     * Obter status de um job
     */
    getJobStatus(jobId) {
        // Procurar em jobs ativos primeiro
        if (this.activeJobs.has(jobId)) {
            return this.activeJobs.get(jobId);
        }
        
        // Depois em jobs na fila
        if (this.jobQueue.has(jobId)) {
            return this.jobQueue.get(jobId);
        }
        
        return null;
    }
    
    /**
     * Listar todos os jobs
     */
    getAllJobs() {
        const jobs = [];
        
        // Jobs ativos
        this.activeJobs.forEach(job => jobs.push(job));
        
        // Jobs na fila
        this.jobQueue.forEach(job => jobs.push(job));
        
        return jobs.sort((a, b) => b.createdAt - a.createdAt);
    }
    
    /**
     * Cancelar um job
     */
    cancelJob(jobId) {
        if (this.jobQueue.has(jobId)) {
            const job = this.jobQueue.get(jobId);
            job.status = 'cancelled';
            job.completedAt = new Date();
            this.jobQueue.delete(jobId);
            
            this.emit('job-cancelled', { jobId });
            return true;
        }
        
        return false;
    }
    
    /**
     * Limpar jobs antigos
     */
    cleanup() {
        const now = Date.now();
        const maxAge = 24 * 60 * 60 * 1000; // 24 horas
        
        // Limpar jobs completados antigos da memória
        for (const [jobId, job] of this.activeJobs.entries()) {
            if (job.status === 'completed' || job.status === 'failed') {
                if (now - job.completedAt.getTime() > maxAge) {
                    this.activeJobs.delete(jobId);
                }
            }
        }
        
        console.log(`[ASYNC] Limpeza concluída. Jobs ativos: ${this.activeJobs.size}, Jobs na fila: ${this.jobQueue.size}`);
    }
}

module.exports = AsyncValidationService;