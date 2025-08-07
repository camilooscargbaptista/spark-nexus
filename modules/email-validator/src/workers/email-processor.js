const Bull = require('bull');
const emailService = require('../services/email-service');
const reportService = require('../services/report-service');
const databaseService = require('../services/database-service');

class EmailProcessor {
  constructor() {
    const redisConfig = {
      host: process.env.REDIS_HOST || 'redis',
      port: process.env.REDIS_PORT || 6379,
      password: process.env.REDIS_PASSWORD || 'SparkRedis2024!'
    };

    this.queue = new Bull('email-validation', {
      redis: redisConfig
    });

    this.setupProcessor();
  }

  setupProcessor() {
    this.queue.process('validate-emails', async (job) => {
      const { emails, userEmail, organizationId, fileName } = job.data;
      
      console.log(`Processing job ${job.id}: ${emails.length} emails for ${userEmail}`);
      
      const results = [];
      const totalEmails = emails.length;
      
      for (let i = 0; i < totalEmails; i++) {
        const result = await emailService.validateSingleEmail(emails[i]);
        results.push(result);
        
        // Update progress
        const progress = Math.round((i + 1) / totalEmails * 100);
        await job.progress(progress);
        
        // Rate limiting
        if (i % 10 === 0) {
          console.log(`Job ${job.id}: ${progress}% complete`);
        }
      }
      
      // Generate report
      console.log(`Generating report for job ${job.id}`);
      const reportPath = await reportService.generateReport(results, 'excel');
      
      // Send email with report
      if (userEmail) {
        console.log(`Sending report to ${userEmail}`);
        await reportService.sendReportByEmail(userEmail, job.id, results, reportPath);
      }
      
      // Save to database
      await databaseService.updateJobResults(job.id, {
        status: 'completed',
        results: results,
        reportPath: reportPath,
        completedAt: new Date()
      });
      
      return {
        success: true,
        summary: {
          total: results.length,
          valid: results.filter(r => r.valid).length,
          invalid: results.filter(r => !r.valid).length
        },
        reportPath: reportPath
      };
    });

    console.log('✅ Email processor worker started');
  }
}

// Start worker
new EmailProcessor();

// Handle shutdown
process.on('SIGTERM', () => {
  console.log('Worker shutting down...');
  process.exit(0);
});
