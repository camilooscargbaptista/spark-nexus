#!/bin/bash

# ================================================
# ADICIONAR DOMÍNIOS BRASILEIROS AO TLD SCORING
# ================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🇧🇷 ADICIONANDO DOMÍNIOS BRASILEIROS COMPLETOS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ================================================
# PASSO 1: Criar arquivo com TLDs brasileiros expandidos
# ================================================
echo -e "${YELLOW}1. Criando lista completa de TLDs brasileiros...${NC}"

cat > brazilian_tlds.json << 'EOF'
{
  "regional_brazil_complete": {
    "com.br": { "score": 9, "trust": "very_high", "category": "regional", "weight": 0.95, "description": "Comercial brasileiro" },
    "org.br": { "score": 8, "trust": "high", "category": "regional", "weight": 0.9, "description": "Organização brasileira" },
    "gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo brasileiro" },
    "edu.br": { "score": 10, "trust": "very_high", "category": "educational", "weight": 1.0, "description": "Educacional brasileiro" },
    "net.br": { "score": 7, "trust": "high", "category": "regional", "weight": 0.85, "description": "Rede brasileira" },
    "emp.br": { "score": 8, "trust": "high", "category": "business", "weight": 0.9, "description": "Empresa brasileira" },
    "ind.br": { "score": 8, "trust": "high", "category": "industry", "weight": 0.9, "description": "Indústria brasileira" },
    "inf.br": { "score": 7, "trust": "high", "category": "information", "weight": 0.85, "description": "Informação brasileira" },
    "adv.br": { "score": 8, "trust": "high", "category": "professional", "weight": 0.9, "description": "Advocacia brasileira" },
    "adm.br": { "score": 8, "trust": "high", "category": "professional", "weight": 0.9, "description": "Administração brasileira" },
    "eng.br": { "score": 8, "trust": "high", "category": "professional", "weight": 0.9, "description": "Engenharia brasileira" },
    "med.br": { "score": 9, "trust": "very_high", "category": "professional", "weight": 0.95, "description": "Medicina brasileira" },
    "odo.br": { "score": 8, "trust": "high", "category": "professional", "weight": 0.9, "description": "Odontologia brasileira" },
    "vet.br": { "score": 8, "trust": "high", "category": "professional", "weight": 0.9, "description": "Veterinária brasileira" },
    "pro.br": { "score": 8, "trust": "high", "category": "professional", "weight": 0.9, "description": "Profissional liberal brasileiro" },
    "agr.br": { "score": 7, "trust": "high", "category": "agriculture", "weight": 0.85, "description": "Agricultura brasileira" },
    "am.br": { "score": 7, "trust": "high", "category": "radio", "weight": 0.85, "description": "Rádio AM brasileiro" },
    "fm.br": { "score": 7, "trust": "high", "category": "radio", "weight": 0.85, "description": "Rádio FM brasileiro" },
    "tv.br": { "score": 8, "trust": "high", "category": "media", "weight": 0.9, "description": "Televisão brasileira" },
    "radio.br": { "score": 7, "trust": "high", "category": "media", "weight": 0.85, "description": "Rádio brasileiro" },
    "jor.br": { "score": 7, "trust": "high", "category": "media", "weight": 0.85, "description": "Jornalismo brasileiro" },
    "eco.br": { "score": 7, "trust": "high", "category": "ecology", "weight": 0.85, "description": "Ecologia brasileira" },
    "tur.br": { "score": 7, "trust": "high", "category": "tourism", "weight": 0.85, "description": "Turismo brasileiro" },
    "art.br": { "score": 7, "trust": "high", "category": "arts", "weight": 0.85, "description": "Arte brasileira" },
    "esp.br": { "score": 7, "trust": "high", "category": "sports", "weight": 0.85, "description": "Esporte brasileiro" },
    "mil.br": { "score": 10, "trust": "very_high", "category": "military", "weight": 1.0, "description": "Militar brasileiro" },
    "b.br": { "score": 6, "trust": "medium", "category": "blog", "weight": 0.7, "description": "Blog brasileiro" },
    "blog.br": { "score": 6, "trust": "medium", "category": "blog", "weight": 0.7, "description": "Blog brasileiro" },
    "nom.br": { "score": 6, "trust": "medium", "category": "personal", "weight": 0.7, "description": "Nome pessoal brasileiro" },
    "ntr.br": { "score": 7, "trust": "high", "category": "notary", "weight": 0.85, "description": "Notarial brasileiro" },
    "ong.br": { "score": 8, "trust": "high", "category": "nonprofit", "weight": 0.9, "description": "ONG brasileira" },
    "coop.br": { "score": 8, "trust": "high", "category": "cooperative", "weight": 0.9, "description": "Cooperativa brasileira" },
    "det.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "DETRAN brasileiro" },
    "jus.br": { "score": 10, "trust": "very_high", "category": "justice", "weight": 1.0, "description": "Justiça brasileira" },
    "leg.br": { "score": 10, "trust": "very_high", "category": "legislative", "weight": 1.0, "description": "Legislativo brasileiro" },
    "ac.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Acre" },
    "al.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Alagoas" },
    "ap.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Amapá" },
    "am.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Amazonas" },
    "ba.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo da Bahia" },
    "ce.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Ceará" },
    "df.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Distrito Federal" },
    "es.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Espírito Santo" },
    "go.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Goiás" },
    "ma.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Maranhão" },
    "mt.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Mato Grosso" },
    "ms.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Mato Grosso do Sul" },
    "mg.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Minas Gerais" },
    "pa.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Pará" },
    "pb.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo da Paraíba" },
    "pr.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Paraná" },
    "pe.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Pernambuco" },
    "pi.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Piauí" },
    "rj.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Rio de Janeiro" },
    "rn.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Rio Grande do Norte" },
    "rs.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Rio Grande do Sul" },
    "ro.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Rondônia" },
    "rr.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Roraima" },
    "sc.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Santa Catarina" },
    "sp.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de São Paulo" },
    "se.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo de Sergipe" },
    "to.gov.br": { "score": 10, "trust": "very_high", "category": "government", "weight": 1.0, "description": "Governo do Tocantins" }
  },
  "brazilian_popular_companies": {
    "globo.com": { "score": 9, "trust": "very_high", "category": "media", "weight": 0.95, "description": "Rede Globo" },
    "uol.com.br": { "score": 8, "trust": "high", "category": "portal", "weight": 0.9, "description": "Portal UOL" },
    "terra.com.br": { "score": 8, "trust": "high", "category": "portal", "weight": 0.9, "description": "Portal Terra" },
    "ig.com.br": { "score": 7, "trust": "high", "category": "portal", "weight": 0.85, "description": "Portal iG" },
    "r7.com": { "score": 8, "trust": "high", "category": "media", "weight": 0.9, "description": "Portal R7 - Record" },
    "band.com.br": { "score": 8, "trust": "high", "category": "media", "weight": 0.9, "description": "Band" },
    "sbt.com.br": { "score": 8, "trust": "high", "category": "media", "weight": 0.9, "description": "SBT" },
    "estadao.com.br": { "score": 9, "trust": "very_high", "category": "news", "weight": 0.95, "description": "Estadão" },
    "folha.com.br": { "score": 9, "trust": "very_high", "category": "news", "weight": 0.95, "description": "Folha de S.Paulo" },
    "veja.com.br": { "score": 8, "trust": "high", "category": "news", "weight": 0.9, "description": "Revista Veja" },
    "exame.com": { "score": 8, "trust": "high", "category": "business", "weight": 0.9, "description": "Revista Exame" },
    "bb.com.br": { "score": 10, "trust": "very_high", "category": "banking", "weight": 1.0, "description": "Banco do Brasil" },
    "caixa.gov.br": { "score": 10, "trust": "very_high", "category": "banking", "weight": 1.0, "description": "Caixa Econômica Federal" },
    "itau.com.br": { "score": 10, "trust": "very_high", "category": "banking", "weight": 1.0, "description": "Banco Itaú" },
    "santander.com.br": { "score": 10, "trust": "very_high", "category": "banking", "weight": 1.0, "description": "Banco Santander" },
    "bradesco.com.br": { "score": 10, "trust": "very_high", "category": "banking", "weight": 1.0, "description": "Banco Bradesco" },
    "nubank.com.br": { "score": 9, "trust": "very_high", "category": "fintech", "weight": 0.95, "description": "Nubank" },
    "mercadolivre.com.br": { "score": 9, "trust": "very_high", "category": "ecommerce", "weight": 0.95, "description": "Mercado Livre" },
    "americanas.com.br": { "score": 8, "trust": "high", "category": "ecommerce", "weight": 0.9, "description": "Lojas Americanas" },
    "submarino.com.br": { "score": 8, "trust": "high", "category": "ecommerce", "weight": 0.9, "description": "Submarino" },
    "magazineluiza.com.br": { "score": 9, "trust": "very_high", "category": "ecommerce", "weight": 0.95, "description": "Magazine Luiza" },
    "casasbahia.com.br": { "score": 8, "trust": "high", "category": "ecommerce", "weight": 0.9, "description": "Casas Bahia" },
    "extra.com.br": { "score": 8, "trust": "high", "category": "ecommerce", "weight": 0.9, "description": "Extra" },
    "pontofrio.com.br": { "score": 8, "trust": "high", "category": "ecommerce", "weight": 0.9, "description": "Ponto Frio" }
  },
  "brazilian_universities": {
    "usp.br": { "score": 10, "trust": "very_high", "category": "educational", "weight": 1.0, "description": "Universidade de São Paulo" },
    "unicamp.br": { "score": 10, "trust": "very_high", "category": "educational", "weight": 1.0, "description": "Unicamp" },
    "ufrj.br": { "score": 10, "trust": "very_high", "category": "educational", "weight": 1.0, "description": "UFRJ" },
    "ufmg.br": { "score": 10, "trust": "very_high", "category": "educational", "weight": 1.0, "description": "UFMG" },
    "unesp.br": { "score": 10, "trust": "very_high", "category": "educational", "weight": 1.0, "description": "UNESP" },
    "unifesp.br": { "score": 10, "trust": "very_high", "category": "educational", "weight": 1.0, "description": "UNIFESP" },
    "puc-rio.br": { "score": 9, "trust": "very_high", "category": "educational", "weight": 0.95, "description": "PUC-Rio" },
    "pucsp.br": { "score": 9, "trust": "very_high", "category": "educational", "weight": 0.95, "description": "PUC-SP" },
    "fgv.br": { "score": 10, "trust": "very_high", "category": "educational", "weight": 1.0, "description": "FGV" },
    "insper.edu.br": { "score": 9, "trust": "very_high", "category": "educational", "weight": 0.95, "description": "Insper" }
  }
}
EOF

echo -e "${GREEN}✅ Arquivo brazilian_tlds.json criado${NC}"

# ================================================
# PASSO 2: Criar script para mesclar com o arquivo existente
# ================================================
echo -e "\n${YELLOW}2. Criando script para adicionar TLDs brasileiros...${NC}"

cat > merge_tlds.js << 'EOF'
const fs = require('fs');
const path = require('path');

try {
    // Carregar arquivo existente
    const existingPath = '/app/data/tldScores.json';
    const existingData = JSON.parse(fs.readFileSync(existingPath, 'utf8'));
    
    // Carregar novos TLDs brasileiros
    const brazilianPath = '/tmp/brazilian_tlds.json';
    const brazilianData = JSON.parse(fs.readFileSync(brazilianPath, 'utf8'));
    
    // Fazer backup do arquivo original
    const backupPath = '/app/data/tldScores.backup.json';
    fs.writeFileSync(backupPath, JSON.stringify(existingData, null, 2));
    console.log('✅ Backup criado:', backupPath);
    
    // Mesclar dados
    let mergedData = { ...existingData };
    let addedCount = 0;
    
    // Adicionar ou atualizar TLDs brasileiros
    for (const category in brazilianData) {
        if (!mergedData[category]) {
            mergedData[category] = {};
        }
        
        for (const tld in brazilianData[category]) {
            if (!mergedData[category][tld]) {
                mergedData[category][tld] = brazilianData[category][tld];
                addedCount++;
                console.log(`  + Adicionado: ${tld} (${brazilianData[category][tld].description})`);
            }
        }
    }
    
    // Salvar arquivo atualizado
    fs.writeFileSync(existingPath, JSON.stringify(mergedData, null, 2));
    
    console.log(`\n✅ Total de ${addedCount} novos TLDs brasileiros adicionados!`);
    console.log('✅ Arquivo tldScores.json atualizado com sucesso!');
    
    // Estatísticas
    let totalTLDs = 0;
    for (const category in mergedData) {
        totalTLDs += Object.keys(mergedData[category]).length;
    }
    console.log(`📊 Total de TLDs no sistema: ${totalTLDs}`);
    
} catch (error) {
    console.error('❌ Erro ao mesclar TLDs:', error.message);
    process.exit(1);
}
EOF

echo -e "${GREEN}✅ Script merge_tlds.js criado${NC}"

# ================================================
# PASSO 3: Copiar arquivos e executar no container
# ================================================
echo -e "\n${YELLOW}3. Aplicando TLDs brasileiros no container...${NC}"

# Copiar arquivos
docker cp brazilian_tlds.json sparknexus-client:/tmp/
docker cp merge_tlds.js sparknexus-client:/tmp/

# Executar merge
docker exec sparknexus-client node /tmp/merge_tlds.js

# ================================================
# PASSO 4: Atualizar o TLDAnalyzer para recarregar
# ================================================
echo -e "\n${YELLOW}4. Recarregando TLD Analyzer...${NC}"

cat > reload_analyzer.js << 'EOF'
const fs = require('fs');

try {
    // Adicionar método de reload no TLDAnalyzer se não existir
    const analyzerPath = '/app/services/validators/tldAnalyzer.js';
    let content = fs.readFileSync(analyzerPath, 'utf8');
    
    if (!content.includes('reloadTLDScores')) {
        // Adicionar método de reload
        const reloadMethod = `
    reloadTLDScores() {
        this.tldScores = this.loadTLDScores();
        this.analysisCache.clear();
        console.log('✅ TLD scores recarregados');
        return Object.keys(this.tldScores).length;
    }`;
        
        // Inserir antes do último }
        content = content.replace(/^}$/m, reloadMethod + '\n}');
        
        fs.writeFileSync(analyzerPath, content);
        console.log('✅ Método reloadTLDScores adicionado ao TLDAnalyzer');
    }
    
} catch (error) {
    console.error('Erro:', error.message);
}
EOF

docker cp reload_analyzer.js sparknexus-client:/tmp/
docker exec sparknexus-client node /tmp/reload_analyzer.js

# ================================================
# PASSO 5: Reiniciar container
# ================================================
echo -e "\n${YELLOW}5. Reiniciando container para aplicar mudanças...${NC}"
docker-compose restart client-dashboard

echo -e "${YELLOW}⏳ Aguardando 10 segundos...${NC}"
sleep 10

# ================================================
# PASSO 6: Testar novos TLDs brasileiros
# ================================================
echo -e "\n${BLUE}6. Testando novos TLDs brasileiros...${NC}"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Teste 1: Domínio .com.br (comercial)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
curl -s -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"contato@empresa.com.br"}' | python3 -m json.tool 2>/dev/null | grep -E '"score"|"trust"|"recommendation"' || \
  echo "Erro no teste"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Teste 2: Domínio .gov.br (governo)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
curl -s -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"cidadao@receita.gov.br"}' | python3 -m json.tool 2>/dev/null | grep -E '"score"|"trust"|"recommendation"' || \
  echo "Erro no teste"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Teste 3: Universidade brasileira (.usp.br)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
curl -s -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"aluno@usp.br"}' | python3 -m json.tool 2>/dev/null | grep -E '"score"|"trust"|"recommendation"' || \
  echo "Erro no teste"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Teste 4: Banco brasileiro (.itau.com.br)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
curl -s -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"gerente@itau.com.br"}' | python3 -m json.tool 2>/dev/null | grep -E '"score"|"trust"|"recommendation"' || \
  echo "Erro no teste"

# ================================================
# PASSO 7: Limpar arquivos temporários
# ================================================
echo -e "\n${YELLOW}7. Limpando arquivos temporários...${NC}"
rm -f brazilian_tlds.json merge_tlds.js reload_analyzer.js

# ================================================
# FINALIZAÇÃO
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ DOMÍNIOS BRASILEIROS ADICIONADOS COM SUCESSO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BLUE}📊 RESUMO DA ATUALIZAÇÃO:${NC}"
echo -e "  ✅ 60+ TLDs .br oficiais adicionados"
echo -e "  ✅ 27 domínios de estados brasileiros (.gov.br)"
echo -e "  ✅ 24 empresas brasileiras populares"
echo -e "  ✅ 10 universidades brasileiras"
echo -e "  ✅ Categorias profissionais (.adv.br, .med.br, .eng.br)"

echo -e "\n${BLUE}🎯 SCORING CONFIGURADO:${NC}"
echo -e "  • .gov.br, .mil.br, .jus.br → Score 10 (máxima confiança)"
echo -e "  • .edu.br, universidades → Score 10 (educacional)"
echo -e "  • Bancos brasileiros → Score 10 (instituições financeiras)"
echo -e "  • .com.br, .org.br → Score 8-9 (alta confiança)"
echo -e "  • Profissionais liberais → Score 8-9 (confiável)"
echo -e "  • .blog.br, .nom.br → Score 6 (médio)"

echo -e "\n${BLUE}🧪 EXEMPLOS DE USO:${NC}"
echo ""
echo "# Testar empresa brasileira:"
echo 'curl -X POST http://localhost:4201/api/validate/advanced -H "Content-Type: application/json" -d '"'"'{"email":"vendas@loja.com.br"}'"'"' | python3 -m json.tool'
echo ""
echo "# Testar profissional liberal:"
echo 'curl -X POST http://localhost:4201/api/validate/advanced -H "Content-Type: application/json" -d '"'"'{"email":"doutor@med.br"}'"'"' | python3 -m json.tool'
echo ""
echo "# Testar governo estadual:"
echo 'curl -X POST http://localhost:4201/api/validate/advanced -H "Content-Type: application/json" -d '"'"'{"email":"contato@sp.gov.br"}'"'"' | python3 -m json.tool'

echo -e "\n${GREEN}🎉 Sistema atualizado e pronto para validar domínios brasileiros!${NC}"

# Verificar total de TLDs
echo -e "\n${YELLOW}📈 Verificando total de TLDs no sistema...${NC}"
docker exec sparknexus-client sh -c "grep -o '\"score\"' /app/data/tldScores.json | wc -l" | while read count; do
    echo -e "${GREEN}Total de TLDs cadastrados: $count${NC}"
done

exit 0