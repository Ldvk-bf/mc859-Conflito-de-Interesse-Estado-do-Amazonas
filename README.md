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
- **Flutter** — aplicativo de visualização interativa

## Resultados

As análises geradas estão em `analises/`, incluindo distribuições de grau, top entidades (funcionários e empresas), tipos de vínculo e casos ilustrativos (ex.: SEDUC, SES).

Os grafos anonimizados estão em `dados_anonimizados/` no formato GEXF comprimido (`.gexf.gz`).

## Aplicativo Flutter (`conflito_de_interesse/`)

Aplicativo multiplataforma (Android, iOS, macOS, Linux, Windows, Web) para exploração interativa dos dados de conflito de interesse.

### Funcionalidades

- **Resultados** — listagem e busca de registros com filtros por nome, score de risco, valor financeiro, tipo de ciclo e distância temporal
- **Favoritos** — marcação e acompanhamento de casos de interesse
- **Exportar** — seleção e exportação de registros em CSV (com toggle de anonimização)
- **Analytics** — gráficos e métricas agregadas sobre os conflitos (histogramas, barras, cartões de métricas)

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.11
- Dart SDK ≥ 3.11 (incluído no Flutter)
- Para Android: Android Studio + emulador ou dispositivo físico
- Para iOS/macOS: Xcode instalado (macOS apenas)

### Como rodar

```bash
cd conflito_de_interesse

# Instalar dependências
flutter pub get

# Rodar no dispositivo/emulador padrão
flutter run

# Rodar especificando plataforma
flutter run -d macos       # macOS
flutter run -d chrome      # Web
flutter run -d android     # Android (emulador ou dispositivo)
```

### Dados

O app carrega os dados de `assets/data/conflito_de_interesse_full.csv`, que deve ser gerado pelo pipeline Python antes de rodar o aplicativo. O arquivo **não está versionado** por conter dados não anonimizados; substitua-o pela versão anonimizada disponível em `dados_anonimizados/dados_derivados/` se necessário.
