# Sistema de Quota - Exemplos de Uso

## Endpoints de Quota Disponíveis

### 1. Obter Estatísticas Completas
```bash
GET /api/user/quota
Authorization: Bearer {token}

Response:
{
    "organization": {
        "id": "uuid",
        "name": "Minha Empresa",
        "plan": "free"
    },
    "quota": {
        "max_validations": 1000,
        "validations_used": 150,
        "validations_remaining": 850,
        "usage_percentage": 15,
        "next_reset_date": "2025-02-01",
        "daily_average": 5
    },
    "history": [...],
    "alerts": []
}
```

### 2. Obter Resumo Simplificado
```bash
GET /api/user/quota/summary
Authorization: Bearer {token}

Response:
{
    "organization": "Minha Empresa",
    "plan": "free",
    "used": 150,
    "limit": 1000,
    "remaining": 850,
    "percentage": 15,
    "nextReset": "2025-02-01",
    "alerts": []
}
```

### 3. Validação com Quota
```bash
POST /api/validate/single
Authorization: Bearer {token}
Content-Type: application/json

{
    "email": "teste@example.com"
}

Headers na Resposta:
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 849
X-RateLimit-Used: 151
X-Organization-Plan: free
```

### 4. Erro de Quota Excedida
```json
{
    "error": "Limite de validações excedido",
    "code": "QUOTA_EXCEEDED",
    "details": {
        "message": "Limite excedido. Apenas 0 validações restantes",
        "limit": 1000,
        "used": 1000,
        "remaining": 0,
        "requested": 1,
        "plan": "free",
        "nextResetDate": "2025-02-01"
    },
    "suggestions": [
        "Aguarde até o próximo período de faturamento",
        "Faça upgrade do seu plano para aumentar o limite"
    ]
}
```

## Dashboard - Componente de Quota

Adicione este HTML no dashboard para mostrar a quota:

```html
<div class="quota-widget">
    <h4>Quota de Validações</h4>
    <div class="quota-progress">
        <div class="progress-bar" id="quotaBar"></div>
    </div>
    <div class="quota-info">
        <span id="quotaUsed">0</span> / <span id="quotaLimit">0</span>
        <span class="quota-plan" id="quotaPlan">free</span>
    </div>
</div>

<script>
async function loadQuota() {
    const response = await fetch('/api/user/quota/summary', {
        headers: {
            'Authorization': 'Bearer ' + localStorage.getItem('token')
        }
    });

    if (response.ok) {
        const data = await response.json();
        document.getElementById('quotaUsed').textContent = data.used;
        document.getElementById('quotaLimit').textContent = data.limit;
        document.getElementById('quotaPlan').textContent = data.plan;
        document.getElementById('quotaBar').style.width = data.percentage + '%';

        // Alertas
        if (data.percentage >= 90) {
            document.getElementById('quotaBar').classList.add('danger');
        } else if (data.percentage >= 75) {
            document.getElementById('quotaBar').classList.add('warning');
        }
    }
}

// Carregar ao iniciar
loadQuota();

// Atualizar após cada validação
window.addEventListener('validation-complete', loadQuota);
</script>
```

## CSS para o Widget

```css
.quota-widget {
    padding: 15px;
    border: 1px solid #ddd;
    border-radius: 8px;
    margin: 20px 0;
}

.quota-progress {
    width: 100%;
    height: 20px;
    background: #f0f0f0;
    border-radius: 10px;
    overflow: hidden;
    margin: 10px 0;
}

.progress-bar {
    height: 100%;
    background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
    transition: width 0.3s ease;
}

.progress-bar.warning {
    background: linear-gradient(90deg, #f39c12 0%, #e67e22 100%);
}

.progress-bar.danger {
    background: linear-gradient(90deg, #e74c3c 0%, #c0392b 100%);
}

.quota-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 14px;
}

.quota-plan {
    background: #667eea;
    color: white;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
    text-transform: uppercase;
}
```

