// ================================================
// Exemplos de uso do Validador Avançado
// ================================================

const axios = require('axios');

const API_URL = 'http://localhost:4201';
const TOKEN = 'SEU_TOKEN_AQUI'; // Obter via login

// Exemplo 1: Validação Rápida (sem autenticação)
async function quickValidation() {
    try {
        const response = await axios.post(`${API_URL}/api/validate/quick`, {
            email: 'test@gmail.com'
        });

        console.log('Validação Rápida:', response.data);
        // { email: 'test@gmail.com', valid: true, score: 75, risk: 'low' }
    } catch (error) {
        console.error('Erro:', error.response.data);
    }
}

// Exemplo 2: Validação Completa (com autenticação)
async function completeValidation() {
    try {
        const response = await axios.post(
            `${API_URL}/api/validate/complete`,
            {
                email: 'ceo@company.com',
                checkMX: true,
                checkSMTP: false,
                detailed: true
            },
            {
                headers: {
                    'Authorization': `Bearer ${TOKEN}`
                }
            }
        );

        console.log('Validação Completa:', JSON.stringify(response.data, null, 2));
    } catch (error) {
        console.error('Erro:', error.response.data);
    }
}

// Exemplo 3: Validação em Lote
async function batchValidation() {
    try {
        const response = await axios.post(
            `${API_URL}/api/validate/batch`,
            {
                emails: [
                    'valid@gmail.com',
                    'invalid@tempmail.com',
                    'typo@gmial.com'
                ],
                options: {
                    checkMX: true,
                    checkDisposable: true
                }
            },
            {
                headers: {
                    'Authorization': `Bearer ${TOKEN}`
                }
            }
        );

        console.log('Job criado:', response.data);

        // Verificar status do job
        setTimeout(async () => {
            const jobStatus = await axios.get(
                `${API_URL}/api/validate/job/${response.data.jobId}`,
                {
                    headers: {
                        'Authorization': `Bearer ${TOKEN}`
                    }
                }
            );
            console.log('Status do Job:', jobStatus.data);
        }, 5000);
    } catch (error) {
        console.error('Erro:', error.response.data);
    }
}

// Exemplo 4: Upload de CSV
async function uploadCSV() {
    const FormData = require('form-data');
    const fs = require('fs');

    const form = new FormData();
    form.append('file', fs.createReadStream('emails.csv'));

    try {
        const response = await axios.post(
            `${API_URL}/api/validate/upload-csv`,
            form,
            {
                headers: {
                    ...form.getHeaders(),
                    'Authorization': `Bearer ${TOKEN}`
                }
            }
        );

        console.log('Upload CSV:', response.data);
    } catch (error) {
        console.error('Erro:', error.response.data);
    }
}

// Executar exemplos
async function runExamples() {
    console.log('🧪 Executando exemplos...
');

    await quickValidation();
    console.log('\n---\n');

    // Para testar com autenticação, faça login primeiro e adicione o token
    // await completeValidation();
    // await batchValidation();
}

runExamples();
