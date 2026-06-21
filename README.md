# Conflito de Interesse — Estado do Amazonas

Projeto desenvolvido para a disciplina **MC859** (Ciência de Dados na Prática) da Unicamp.

Investiga potenciais conflitos de interesse na administração pública do Amazonas, cruzando dados da folha de pagamento de servidores estaduais com o quadro societário de empresas que possuem contratos com órgãos do estado.

## Fontes de dados

- **Folha de pagamento**: servidores públicos estaduais (vínculos por órgão)
- **Quadro societário**: sócios de empresas com contratos firmados com órgãos estaduais
- **Contratos**: Portal de Transparência do Estado do Amazonas

Os dados brutos não estão versionados. O repositório contém apenas versões anonimizadas (GEXF comprimido) para fins de análise e reprodutibilidade.

## Pipeline

```
Extração → Matching de nomes → Construção do grafo → Exportação → Análise
```

| Script | Descrição |
|---|---|
| `extração/` | Coleta e limpeza dos dados brutos |
| `consolidar_folha.py` | Consolida CSVs da folha de pagamento |
| `matching_naming_socios_funcionarios.py` | Matching fuzzy entre nomes de sócios e servidores |
| `converter_dados_base_para_neo4j.py` | Gera CSVs de nós e arestas para importação no Neo4j |
| `converter_neo4j_para_gexf.py` | Exporta o grafo do Neo4j para GEXF |
| `anonimizar_grafos.py` / `anonimizar_neo4j.py` | Anonimiza os dados para versionamento público |
| `prota_analisar_grafos.py` | Análise estrutural dos grafos (grau, componentes, etc.) |

## Tecnologias

- **Python** — processamento e análise
- **Neo4j** — banco de dados de grafos
- **NetworkX** — análise de grafos em Python
- **Gephi** — visualização dos grafos
- **Matplotlib** — geração de gráficos

## Resultados

As análises geradas estão em `analises/`, incluindo distribuições de grau, top entidades (funcionários e empresas), tipos de vínculo e casos ilustrativos (ex.: SEDUC, SES).

Os grafos anonimizados estão em `dados_anonimizados/` no formato GEXF comprimido (`.gexf.gz`).
