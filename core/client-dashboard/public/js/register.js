// ================================================
// Sistema de Registro Completo
// ================================================

let currentStep = 1;
let userData = {};

// Máscaras e validações
document.addEventListener('DOMContentLoaded', () => {
    setupInputMasks();
    setupPasswordStrength();
    setupVerificationInputs();
});

// Configurar máscaras de input
function setupInputMasks() {
    // Máscara para CPF/CNPJ
    const cpfCnpjInput = document.getElementById('cpfCnpj');
    cpfCnpjInput.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, '');

        // Identificar se é CPF ou CNPJ
        if (value.length <= 11) {
            // CPF: 000.000.000-00
            value = value.replace(/(\d{3})(\d)/, '$1.$2');
            value = value.replace(/(\d{3})(\d)/, '$1.$2');
            value = value.replace(/(\d{3})(\d{1,2})/, '$1-$2');
        } else {
            // CNPJ: 00.000.000/0000-00
            value = value.replace(/(\d{2})(\d)/, '$1.$2');
            value = value.replace(/(\d{3})(\d)/, '$1.$2');
            value = value.replace(/(\d{3})(\d)/, '$1/$2');
            value = value.replace(/(\d{4})(\d)/, '$1-$2');
        }

        e.target.value = value;
        validateCpfCnpj(value);
    });

    // Máscara para telefone
    const phoneInput = document.getElementById('phone');
    phoneInput.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, '');

        if (value.length <= 11) {
            // Formato: (00) 00000-0000 ou (00) 0000-0000
            value = value.replace(/(\d{2})(\d)/, '($1) $2');
            if (value.length > 10) {
                value = value.replace(/(\d{5})(\d)/, '$1-$2');
            } else {
                value = value.replace(/(\d{4})(\d)/, '$1-$2');
            }
        }

        e.target.value = value;
        validatePhone(value);
    });
}

// Validar CPF/CNPJ em tempo real
async function validateCpfCnpj(value) {
    const cleanValue = value.replace(/\D/g, '');
    const errorSpan = document.getElementById('cpfCnpjError');
    const successSpan = document.getElementById('cpfCnpjSuccess');

    errorSpan.textContent = '';
    successSpan.textContent = '';

    if (cleanValue.length === 11 || cleanValue.length === 14) {
        try {
            const response = await fetch('/api/validate/cpf-cnpj', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ document: cleanValue })
            });

            const result = await response.json();

            if (result.valid) {
                successSpan.textContent = `✓ ${result.type} válido`;
            } else {
                errorSpan.textContent = result.error || 'Documento inválido';
            }
        } catch (error) {
            console.error('Erro ao validar documento:', error);
        }
    }
}

// Validar telefone em tempo real
async function validatePhone(value) {
    const cleanValue = value.replace(/\D/g, '');
    const errorSpan = document.getElementById('phoneError');
    const successSpan = document.getElementById('phoneSuccess');

    errorSpan.textContent = '';
    successSpan.textContent = '';

    if (cleanValue.length >= 10) {
        if (cleanValue.length === 10 || cleanValue.length === 11) {
            successSpan.textContent = '✓ Telefone válido';
        } else {
            errorSpan.textContent = 'Telefone inválido';
        }
    }
}

// Configurar medidor de força da senha
function setupPasswordStrength() {
    const passwordInput = document.getElementById('password');
    const strengthBar = document.getElementById('passwordStrengthBar');

    passwordInput.addEventListener('input', (e) => {
        const password = e.target.value;
        const strength = calculatePasswordStrength(password);

        strengthBar.className = 'password-strength-bar';
        if (strength.score <= 2) {
            strengthBar.classList.add('strength-weak');
        } else if (strength.score <= 3) {
            strengthBar.classList.add('strength-medium');
        } else {
            strengthBar.classList.add('strength-strong');
        }
    });
}

// Calcular força da senha
function calculatePasswordStrength(password) {
    const checks = {
        length: password.length >= 8,
        uppercase: /[A-Z]/.test(password),
        lowercase: /[a-z]/.test(password),
        numbers: /\d/.test(password),
        special: /[!@#$%^&*(),.?":{}|<>]/.test(password)
    };

    const score = Object.values(checks).filter(Boolean).length;

    return { checks, score };
}

// Configurar inputs de verificação
function setupVerificationInputs() {
    // Email verification
    const emailInputs = document.querySelectorAll('.email-code');
    emailInputs.forEach((input, index) => {
        input.addEventListener('input', (e) => {
            if (e.target.value && index < emailInputs.length - 1) {
                emailInputs[index + 1].focus();
            }
        });

        input.addEventListener('keydown', (e) => {
            if (e.key === 'Backspace' && !e.target.value && index > 0) {
                emailInputs[index - 1].focus();
            }
        });
    });

    // Phone verification
    const phoneInputs = document.querySelectorAll('.phone-code');
    phoneInputs.forEach((input, index) => {
        input.addEventListener('input', (e) => {
            if (e.target.value && index < phoneInputs.length - 1) {
                phoneInputs[index + 1].focus();
            }
        });

        input.addEventListener('keydown', (e) => {
            if (e.key === 'Backspace' && !e.target.value && index > 0) {
                phoneInputs[index - 1].focus();
            }
        });
    });
}

// Handle registro form
document.getElementById('registerForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const alertBox = document.getElementById('alertBox');
    const formData = new FormData(e.target);

    // Validar senhas
    if (formData.get('password') !== formData.get('confirmPassword')) {
        document.getElementById('confirmPasswordError').textContent = 'As senhas não coincidem';
        return;
    }

    // Validar força da senha
    const strength = calculatePasswordStrength(formData.get('password'));
    if (strength.score < 4) {
        document.getElementById('passwordError').textContent = 'Senha deve ter maiúsculas, minúsculas, números e caracteres especiais';
        return;
    }

    // Preparar dados
    userData = {
        firstName: formData.get('firstName'),
        lastName: formData.get('lastName'),
        cpfCnpj: formData.get('cpfCnpj').replace(/\D/g, ''),
        email: formData.get('email'),
        phone: formData.get('phone').replace(/\D/g, ''),
        company: formData.get('company'),
        password: formData.get('password')
    };

    try {
        // Enviar para o servidor
        const response = await fetch('/api/auth/register', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(userData)
        });

        const result = await response.json();

        if (response.ok) {
            // Mostrar email no step 2
            document.getElementById('emailDisplay').textContent = userData.email;
            document.getElementById('phoneDisplay').textContent = formData.get('phone');

            // Avançar para step 2
            showStep(2);
        } else {
            alertBox.className = 'alert alert-error';
            alertBox.textContent = result.error || 'Erro ao criar conta';
            alertBox.style.display = 'block';
        }
    } catch (error) {
      console.log('error --> ', error);
        alertBox.className = 'alert alert-error';
        alertBox.textContent = 'Erro ao conectar com o servidor';
        alertBox.style.display = 'block';
    }
});

// Mostrar step específico
function showStep(step) {
    currentStep = step;

    // Atualizar indicadores
    document.querySelectorAll('.step').forEach((el, index) => {
        if (index < step - 1) {
            el.classList.add('completed');
            el.classList.remove('active');
        } else if (index === step - 1) {
            el.classList.add('active');
            el.classList.remove('completed');
        } else {
            el.classList.remove('active', 'completed');
        }
    });

    // Mostrar conteúdo do step
    document.querySelectorAll('.step-content').forEach((el, index) => {
        el.classList.toggle('active', index === step - 1);
    });
}

// Verificar email
async function verifyEmail() {
    const inputs = document.querySelectorAll('.email-code');
    const code = Array.from(inputs).map(i => i.value).join('');

    if (code.length !== 6) {
        SparkModal.warning('Digite o código completo', 'Código incompleto');
        return;
    }

    try {
        const response = await fetch('/api/auth/verify-email', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: userData.email,
                token: code
            })
        });

        const result = await response.json();

        if (response.ok) {
            showStep(3);
        } else {
            SparkModal.error(result.error || 'Código inválido', 'Erro na verificação');
        }
    } catch (error) {
        SparkModal.error('Erro ao verificar email', 'Erro');
    }
}

// Verificar telefone
async function verifyPhone() {
    const inputs = document.querySelectorAll('.phone-code');
    const code = Array.from(inputs).map(i => i.value).join('');

    if (code.length !== 6) {
        SparkModal.warning('Digite o código completo', 'Código incompleto');
        return;
    }

    try {
        const response = await fetch('/api/auth/verify-phone', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: userData.email,
                token: code
            })
        });

        const result = await response.json();

        if (response.ok) {
            SparkModal.success('Cadastro completo! Redirecionando para login...', '✅ Sucesso');
            setTimeout(() => {
                window.location.href = '/login';
            }, 2000);
        } else {
            SparkModal.error(result.error || 'Código inválido', 'Erro na verificação');
        }
    } catch (error) {
        SparkModal.error('Erro ao verificar telefone', 'Erro');
    }
}

// Reenviar código de email
async function resendEmailCode() {
    try {
        const response = await fetch('/api/auth/resend-email', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: userData.email })
        });

        if (response.ok) {
            SparkModal.success('Código reenviado para seu email', 'Código enviado');
        }
    } catch (error) {
        SparkModal.error('Erro ao reenviar código', 'Erro');
    }
}

// Reenviar código de telefone
async function resendPhoneCode(method) {
    try {
        const response = await fetch('/api/auth/resend-phone', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: userData.email,
                phone: userData.phone,
                method: method // 'sms' ou 'whatsapp'
            })
        });

        if (response.ok) {
            SparkModal.success(`Código reenviado via ${method.toUpperCase()}`, 'Código enviado');
        }
    } catch (error) {
        SparkModal.error('Erro ao reenviar código', 'Erro');
    }
}
