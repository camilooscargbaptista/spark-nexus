// SMS Service - Versão Simplificada (sem Twilio)
class SMSService {
    constructor() {
        console.log('📱 SMS Service initialized (mock mode - Twilio not configured)');
        this.enabled = false;
        
        // Verificar se Twilio está configurado
        if (process.env.TWILIO_ACCOUNT_SID && 
            process.env.TWILIO_ACCOUNT_SID !== 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx') {
            try {
                const twilio = require('twilio');
                this.client = twilio(
                    process.env.TWILIO_ACCOUNT_SID,
                    process.env.TWILIO_AUTH_TOKEN
                );
                this.enabled = true;
                console.log('✅ Twilio configured and ready');
            } catch (error) {
                console.log('⚠️ Twilio not available, SMS disabled');
            }
        }
    }

    async sendVerificationSMS(phone, code) {
        if (!this.enabled) {
            console.log(`📱 [MOCK] SMS would be sent to ${phone}: Your code is ${code}`);
            return { success: true, mock: true };
        }
        
        try {
            const message = await this.client.messages.create({
                body: `Spark Nexus - Seu código de verificação é: ${code}`,
                from: process.env.TWILIO_PHONE_NUMBER,
                to: phone
            });
            return { success: true, messageId: message.sid };
        } catch (error) {
            console.error('SMS Error:', error);
            return { success: false, error: error.message };
        }
    }

    async sendVerificationWhatsApp(phone, code) {
        if (!this.enabled) {
            console.log(`💬 [MOCK] WhatsApp would be sent to ${phone}: Your code is ${code}`);
            return { success: true, mock: true };
        }
        
        try {
            const message = await this.client.messages.create({
                body: `Spark Nexus - Seu código de verificação é: ${code}`,
                from: `whatsapp:${process.env.TWILIO_PHONE_NUMBER}`,
                to: `whatsapp:${phone}`
            });
            return { success: true, messageId: message.sid };
        } catch (error) {
            console.error('WhatsApp Error:', error);
            return { success: false, error: error.message };
        }
    }
}

module.exports = SMSService;
