#!/bin/bash

# Script para atualizar listas automaticamente

# Atualizar TLDs (diariamente às 3h)
echo "0 3 * * * cd /app && node scripts/updateTLDs.js >> /var/log/tld-update.log 2>&1" | crontab -

# Atualizar lista de disposable (semanalmente, domingos às 4h)
echo "0 4 * * 0 cd /app && node scripts/updateDisposable.js >> /var/log/disposable-update.log 2>&1" | crontab -

echo "✅ Cron jobs configurados"
