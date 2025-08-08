// Email Validator Worker
const amqp = require('amqplib');
const nodemailer = require('nodemailer');

console.log('🚀 Email Validator Worker starting...');

// Configuração do email (Titan)
const emailTransporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.titan.email',
    port: parseInt(process.env.SMTP_PORT || 587),
    secure: false,
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
    }
});

// Conectar ao RabbitMQ
async function startWorker() {
    try {
        const connection = await amqp.connect('amqp://rabbitmq:5672');
        const channel = await connection.createChannel();
        
        const queue = 'email_validation';
        await channel.assertQueue(queue, { durable: true });
        
        console.log('✅ Worker connected to RabbitMQ');
        console.log('⏳ Waiting for messages...');
        
        channel.consume(queue, async (msg) => {
            if (msg) {
                const data = JSON.parse(msg.content.toString());
                console.log('📧 Processing:', data.email);
                
                // Processar validação
                // Aqui você adicionaria a lógica de validação real
                
                channel.ack(msg);
            }
        });
    } catch (error) {
        console.error('❌ Worker error:', error);
        setTimeout(startWorker, 5000); // Retry após 5 segundos
    }
}

startWorker();
