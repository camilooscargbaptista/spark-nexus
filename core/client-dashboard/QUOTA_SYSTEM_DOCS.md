# Sistema de Quota - Documentação

## Instalação Concluída ✅

O sistema de quota foi instalado com sucesso!

## Arquivos Criados

- `services/QuotaService.js` - Serviço principal de gerenciamento de quotas
- `middleware/quotaMiddleware.js` - Middleware para proteção de endpoints
- `server.js` - Atualizado com integração do sistema de quota

## Como Funciona

1. Cada organização tem um limite mensal de validações
2. O sistema verifica automaticamente antes de cada validação
3. Incrementa o contador após validações bem-sucedidas
4. Bloqueia quando o limite é excedido
5. Reseta automaticamente no início de cada mês

## Endpoints de API

### Obter Resumo de Quota
```bash
GET /api/user/quota/summary
Authorization: Bearer {token}

Response:
{
  "organization": "Demo Organization",
  "plan": "free",
  "used": 150,
  "limit": 1000,
  "remaining": 850,
  "percentage": 15
}
```

### Obter Estatísticas Completas
```bash
GET /api/user/quota
Authorization: Bearer {token}
```

## Headers de Resposta

Todos os endpoints de validação retornam:
- `X-RateLimit-Limit` - Limite total
- `X-RateLimit-Remaining` - Validações restantes
- `X-RateLimit-Used` - Já utilizadas
- `X-Organization-Plan` - Plano atual

## Limites por Plano

- **Free**: 1.000 validações/mês
- **Starter**: 10.000 validações/mês
- **Professional**: 50.000 validações/mês
- **Enterprise**: 999.999 validações/mês

## Troubleshooting

Se houver erros:

1. Verifique se as tabelas foram criadas no banco:
   ```sql
   SELECT * FROM tenant.organizations LIMIT 1;
   ```

2. Verifique os logs:
   ```bash
   docker-compose logs --tail=100 client-dashboard
   ```

3. Teste manualmente o QuotaService:
   ```bash
   docker exec -it sparknexus-client node -e "
     const QS = require('./services/QuotaService');
     const qs = new QS();
     qs.checkQuota('UUID_DA_ORG').then(console.log);
   "
   ```
