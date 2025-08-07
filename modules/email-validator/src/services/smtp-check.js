const net = require('net');
const dns = require('dns').promises;

class SMTPCheck {
  async verifyEmail(email) {
    const [localPart, domain] = email.split('@');
    
    try {
      // Get MX records
      const mxRecords = await dns.resolveMx(domain);
      if (mxRecords.length === 0) {
        return { valid: false, reason: 'No MX records' };
      }
      
      // Sort by priority
      mxRecords.sort((a, b) => a.priority - b.priority);
      
      // Try to connect to SMTP server
      for (const mx of mxRecords) {
        const result = await this.checkSMTP(mx.exchange, email);
        if (result !== null) {
          return result;
        }
      }
      
      return { valid: false, reason: 'Could not verify' };
    } catch (error) {
      return { valid: false, reason: error.message };
    }
  }
  
  checkSMTP(mxHost, email) {
    return new Promise((resolve) => {
      const client = new net.Socket();
      let step = 0;
      let valid = false;
      
      const timeout = setTimeout(() => {
        client.destroy();
        resolve(null);
      }, 5000);
      
      client.connect(25, mxHost, () => {
        // Connected
      });
      
      client.on('data', (data) => {
        const response = data.toString();
        const code = response.substring(0, 3);
        
        switch (step) {
          case 0: // Initial connection
            if (code === '220') {
              client.write('HELO mail.example.com\r\n');
              step++;
            }
            break;
            
          case 1: // HELO response
            if (code === '250') {
              client.write('MAIL FROM:<test@example.com>\r\n');
              step++;
            }
            break;
            
          case 2: // MAIL FROM response
            if (code === '250') {
              client.write(`RCPT TO:<${email}>\r\n`);
              step++;
            }
            break;
            
          case 3: // RCPT TO response
            if (code === '250') {
              valid = true;
            } else if (code === '550') {
              valid = false;
            }
            client.write('QUIT\r\n');
            break;
            
          case 4: // QUIT response
            clearTimeout(timeout);
            client.destroy();
            resolve({ valid, reason: valid ? 'Mailbox exists' : 'Mailbox not found' });
            break;
        }
      });
      
      client.on('error', () => {
        clearTimeout(timeout);
        resolve(null);
      });
      
      client.on('close', () => {
        clearTimeout(timeout);
        resolve(null);
      });
    });
  }
}

module.exports = new SMTPCheck();
