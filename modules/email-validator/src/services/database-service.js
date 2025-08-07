const { Pool } = require('pg');

class DatabaseService {
  constructor() {
    this.pool = new Pool({
      connectionString: process.env.DATABASE_URL || 
        'postgresql://sparknexus:SparkNexus2024!@postgres:5432/sparknexus_modules'
    });
  }

  async createValidationJob(data) {
    const query = `
      INSERT INTO validation_jobs 
      (job_id, organization_id, user_email, file_name, upload_path, email_count, status)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `;
    
    const values = [
      data.jobId,
      data.organizationId,
      data.userEmail,
      data.fileName,
      data.uploadPath,
      data.emailCount,
      data.status || 'pending'
    ];
    
    const result = await this.pool.query(query, values);
    
    // Criar stats se não existir
    await this.pool.query(`
      INSERT INTO organization_stats (organization_id)
      VALUES ($1)
      ON CONFLICT (organization_id) DO NOTHING
    `, [data.organizationId]);
    
    return result.rows[0];
  }

  async updateJobStatus(jobId, status, progress = null) {
    const query = `
      UPDATE validation_jobs 
      SET status = $1, 
          progress = COALESCE($2, progress),
          started_at = CASE WHEN $1 = 'processing' THEN NOW() ELSE started_at END,
          completed_at = CASE WHEN $1 IN ('completed', 'failed') THEN NOW() ELSE completed_at END
      WHERE job_id = $3
      RETURNING *
    `;
    
    const result = await this.pool.query(query, [status, progress, jobId]);
    return result.rows[0];
  }

  async saveValidationResult(jobId, result) {
    const query = `
      INSERT INTO validation_results 
      (job_id, email, valid, score, format_valid, mx_records, smtp_valid, 
       disposable, role_based, free_provider, reason, checks)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING *
    `;
    
    const values = [
      jobId,
      result.email,
      result.valid,
      result.score,
      result.checks?.format,
      result.checks?.mxRecords,
      result.checks?.smtp,
      result.checks?.disposable === false,
      result.checks?.roleBased === false,
      result.checks?.freeProvider,
      Array.isArray(result.reason) ? result.reason.join(', ') : result.reason,
      JSON.stringify(result.checks || {})
    ];
    
    const savedResult = await this.pool.query(query, values);
    
    // Cache result
    await this.cacheValidation(result);
    
    return savedResult.rows[0];
  }

  async cacheValidation(result) {
    const query = `
      INSERT INTO validation_cache (email, valid, score, checks)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (email) 
      DO UPDATE SET 
        valid = $2, 
        score = $3, 
        checks = $4,
        cached_at = NOW(),
        expires_at = NOW() + INTERVAL '30 days'
    `;
    
    await this.pool.query(query, [
      result.email,
      result.valid,
      result.score,
      JSON.stringify(result.checks || {})
    ]);
  }

  async getCachedValidation(email) {
    const query = `
      SELECT * FROM validation_cache 
      WHERE email = $1 AND expires_at > NOW()
    `;
    
    const result = await this.pool.query(query, [email]);
    return result.rows[0];
  }

  async getJobResults(jobId) {
    const jobQuery = 'SELECT * FROM validation_jobs WHERE job_id = $1';
    const jobResult = await this.pool.query(jobQuery, [jobId]);
    
    if (jobResult.rows.length === 0) {
      return null;
    }
    
    const resultsQuery = 'SELECT * FROM validation_results WHERE job_id = $1';
    const resultsResult = await this.pool.query(resultsQuery, [jobId]);
    
    return {
      job: jobResult.rows[0],
      results: resultsResult.rows
    };
  }

  async getOrganizationStats(organizationId) {
    const query = 'SELECT * FROM organization_stats WHERE organization_id = $1';
    const result = await this.pool.query(query, [organizationId]);
    
    if (result.rows.length === 0) {
      return {
        totalValidations: 0,
        validEmails: 0,
        invalidEmails: 0,
        monthlyUsage: 0
      };
    }
    
    return result.rows[0];
  }

  async updateJobResults(jobId, data) {
    const query = `
      UPDATE validation_jobs 
      SET status = $1, 
          report_path = $2,
          completed_at = $3,
          progress = 100
      WHERE job_id = $4
      RETURNING *
    `;
    
    const result = await this.pool.query(query, [
      data.status,
      data.reportPath,
      data.completedAt,
      jobId
    ]);
    
    return result.rows[0];
  }
}

module.exports = new DatabaseService();
