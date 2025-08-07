const fs = require('fs').promises;
const path = require('path');
const csv = require('csv-parse');
const XLSX = require('xlsx');

class EmailService {
  // Extrair emails de arquivo
  async extractEmailsFromFile(filePath, mimeType) {
    console.log(`Extracting emails from: ${filePath}`);
    
    try {
      let content;
      
      // Ler arquivo como texto
      if (mimeType.includes('text') || filePath.endsWith('.csv') || filePath.endsWith('.txt')) {
        content = await fs.readFile(filePath, 'utf-8');
        return this.extractEmailsFromText(content);
      } 
      // Ler Excel
      else if (filePath.endsWith('.xlsx') || filePath.endsWith('.xls')) {
        return this.extractEmailsFromExcel(filePath);
      }
      
      throw new Error('Unsupported file type');
    } catch (error) {
      console.error('Error extracting emails:', error);
      throw error;
    }
  }
  
  // Extrair emails de texto
  extractEmailsFromText(text) {
    const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
    const emails = text.match(emailRegex) || [];
    
    // Remover duplicatas
    const uniqueEmails = [...new Set(emails)];
    console.log(`Found ${uniqueEmails.length} unique emails`);
    
    return uniqueEmails;
  }
  
  // Extrair emails de Excel
  async extractEmailsFromExcel(filePath) {
    try {
      const workbook = XLSX.readFile(filePath);
      const emails = [];
      
      // Processar todas as planilhas
      workbook.SheetNames.forEach(sheetName => {
        const sheet = workbook.Sheets[sheetName];
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
        
        // Procurar emails em todas as células
        data.forEach(row => {
          row.forEach(cell => {
            if (typeof cell === 'string' && cell.includes('@')) {
              const extracted = this.extractEmailsFromText(cell);
              emails.push(...extracted);
            }
          });
        });
      });
      
      return [...new Set(emails)];
    } catch (error) {
      console.error('Error reading Excel:', error);
      return [];
    }
  }
  
  // Validar emails
  async validateEmails(emails) {
    const results = [];
    
    for (const email of emails) {
      const result = await this.validateSingleEmail(email);
      results.push(result);
    }
    
    return results;
  }
  
  // Validar um único email
  async validateSingleEmail(email) {
    // Validação básica
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const isValid = emailRegex.test(email);
    
    const [localPart, domain] = email.split('@') || ['', ''];
    
    // Verificações básicas
    const checks = {
      format: isValid,
      length: localPart.length <= 64 && domain.length <= 255,
      disposable: !this.isDisposableEmail(domain),
      roleBased: !this.isRoleBased(localPart),
      freeProvider: this.isFreeProvider(domain)
    };
    
    // Calcular score
    let score = 0;
    if (checks.format) score += 40;
    if (checks.length) score += 10;
    if (checks.disposable) score += 20;
    if (checks.roleBased) score += 20;
    if (!checks.freeProvider) score += 10;
    
    return {
      email,
      valid: score >= 60,
      score,
      checks,
      reason: isValid ? 'Valid format' : 'Invalid format'
    };
  }
  
  // Verificar se é email descartável
  isDisposableEmail(domain) {
    const disposableDomains = [
      'tempmail.com', 'throwaway.email', '10minutemail.com',
      'guerrillamail.com', 'mailinator.com', 'temp-mail.org',
      'disposable.com', 'tempmail.org'
    ];
    return disposableDomains.includes(domain?.toLowerCase());
  }
  
  // Verificar se é role-based
  isRoleBased(localPart) {
    const roleBasedPrefixes = [
      'admin', 'info', 'support', 'sales', 'contact',
      'help', 'service', 'team', 'staff', 'office'
    ];
    return roleBasedPrefixes.some(prefix => 
      localPart?.toLowerCase().startsWith(prefix)
    );
  }
  
  // Verificar se é provedor gratuito
  isFreeProvider(domain) {
    const freeProviders = [
      'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com',
      'aol.com', 'icloud.com', 'mail.com', 'protonmail.com'
    ];
    return freeProviders.includes(domain?.toLowerCase());
  }
}

module.exports = new EmailService();
