"""
Consolida todos os CSVs de folha de pagamento em um único arquivo limpo.

Saída: data/folha_consolidada.csv
Colunas: orgao, periodo, nome, nome_normalizado, lotacao, cargo, funcao, vinculo, remuneracao_total
"""

import csv
import os
import re
import sys
import unicodedata
from pathlib import Path

# Alguns arquivos têm campos muito longos (texto sem quebra)
csv.field_size_limit(sys.maxsize)

PASTA_FOLHA = Path("data/folha_pagamento_am")
SAIDA = Path("data/dados_base/nome_funcionario-orgao_publico(funcionarios).csv")

# Colunas de saída padronizadas
COLUNAS_SAIDA = [
    "orgao", "periodo_inicio", "periodo_fim", "nome", "nome_normalizado",
    "lotacao", "cargo", "funcao", "vinculo", "remuneracao_total"
]


def normalizar_nome(nome: str) -> str:
    """Remove acentos, pontuação, espaços extras e converte para maiúsculo."""
    if not nome:
        return ""
    # Maiúsculo
    nome = nome.strip().upper()
    # Remove acentos
    nome = unicodedata.normalize("NFD", nome)
    nome = "".join(c for c in nome if unicodedata.category(c) != "Mn")
    # Remove pontuação exceto espaço
    nome = re.sub(r"[^A-Z\s]", "", nome)
    # Colapsa espaços múltiplos
    nome = re.sub(r"\s+", " ", nome).strip()
    return nome


def extrair_periodo(nome_arquivo: str) -> str:
    """Extrai período YYYY-MM do nome do arquivo (ex: 233_201705.csv -> 2017-05)."""
    match = re.search(r"_(\d{6})\.", nome_arquivo)
    if match:
        raw = match.group(1)
        return f"{raw[:4]}-{raw[4:]}"
    return ""


def limpar_valor(valor: str) -> str:
    """Remove espaços e caracteres invisíveis de valores monetários."""
    return valor.strip().replace("\xa0", "").replace(" ", "") if valor else ""

# Mano isso aq foi bizarro, puta merda, geninal!!
def detectar_formato(header: list[str]) -> str:
    """
    Retorna o formato do CSV baseado no header.
    Formatos:
      'padrao'   - NOME;LOTACAO;CARGO;FUNCAO;VINCULO;...
      'classe'   - NOME;LOTACAO;CARGO;CLASSE / PADRÃO;FUNCAO;CARGA HR SEM;DT DE ADMISSAO;VINCULO;...
      'semclasse'- NOME;LOTACAO;CARGO;FUNCAO;CARGA HR SEM;DT DE ADMISSAO;VINCULO;...
      'prodam'   - NOME;SECAO;FUNCAO;CARGO;REMUNERACAOLEGALTOTAL;...
      'vazio'    - header em branco (linha de metadado, pular)
    """
    if not header or not header[0]:
        return "vazio"

    h = [c.strip().upper() for c in header]

    if "SECAO" in h or "REMUNERACAOLEGALTOTAL" in h:
        return "prodam"
    if "CLASSE / PADR" in " ".join(h) or "CLASSE" in h:
        return "classe"
    if "CARGA HR SEM" in " ".join(h) or "DT DE ADMISSAO" in " ".join(h):
        return "semclasse"
    if h[0] == "NOME":
        return "padrao"

    return "vazio"


def extrair_linha(row: list[str], formato: str) -> dict | None:
    """Extrai campos relevantes de uma linha conforme o formato."""

    def safe(idx):
        return row[idx].strip() if idx < len(row) else ""

    if formato == "padrao":
        # NOME;LOTACAO;CARGO;FUNCAO;VINCULO;REMUNERACAO LEGAL TOTAL;...
        nome = safe(0)
        if not nome:
            return None
        return {
            "nome": nome,
            "lotacao": safe(1),
            "cargo": safe(2),
            "funcao": safe(3),
            "vinculo": safe(4),
            "remuneracao_total": limpar_valor(safe(5)),
        }

    elif formato == "classe":
        # NOME;LOTACAO;CARGO;CLASSE/PADRÃO;FUNCAO;CARGA HR;DT ADMISSAO;VINCULO;REMUNERACAO...
        nome = safe(0)
        if not nome:
            return None
        return {
            "nome": nome,
            "lotacao": safe(1),
            "cargo": safe(2),
            "funcao": safe(4),
            "vinculo": safe(7),
            "remuneracao_total": limpar_valor(safe(8)),
        }

    elif formato == "semclasse":
        # NOME;LOTACAO;CARGO;FUNCAO;CARGA HR;DT ADMISSAO;VINCULO;REMUNERACAO...
        nome = safe(0)
        if not nome:
            return None
        return {
            "nome": nome,
            "lotacao": safe(1),
            "cargo": safe(2),
            "funcao": safe(3),
            "vinculo": safe(6),
            "remuneracao_total": limpar_valor(safe(7)),
        }

    elif formato == "prodam":
        # NOME;SECAO;FUNCAO;CARGO;REMUNERACAOLEGALTOTAL;...
        nome = safe(0)
        if not nome:
            return None
        return {
            "nome": nome,
            "lotacao": safe(1),
            "cargo": safe(3),
            "funcao": safe(2),
            "vinculo": "",
            "remuneracao_total": limpar_valor(safe(4)),
        }

    return None


def ler_csv(caminho: Path) -> tuple[str, list[list[str]]]:
    """Lê um CSV tentando encodings comuns. Retorna (encoding_usado, linhas)."""
    for enc in ("utf-8", "latin-1", "cp1252"):
        try:
            with open(caminho, encoding=enc, newline="") as f:
                linhas = list(csv.reader(f, delimiter=";"))
            return enc, linhas
        except UnicodeDecodeError:
            continue
    return "latin-1", []


def processar_pasta(pasta: Path) -> list[dict]:
    """Processa todos os CSVs de uma pasta de órgão."""
    orgao = pasta.name
    registros = []

    for arquivo in sorted(pasta.glob("*.csv")):
        periodo = extrair_periodo(arquivo.name)
        _, linhas = ler_csv(arquivo)

        if not linhas:
            continue

        # PRODAM tem 2 linhas antes do header real
        inicio_header = 0
        if linhas[0] and not linhas[0][0].strip():
            # Procura primeira linha com "NOME"
            for i, linha in enumerate(linhas):
                if linha and linha[0].strip().upper() == "NOME":
                    inicio_header = i
                    break

        header = linhas[inicio_header]
        formato = detectar_formato(header)

        if formato == "vazio":
            continue

        for linha in linhas[inicio_header + 1:]:
            if not linha or not linha[0].strip():
                continue
            # Pula linhas que são repetição do header (alguns arquivos repetem)
            if linha[0].strip().upper() == "NOME":
                continue

            dado = extrair_linha(linha, formato)
            if not dado:
                continue

            nome_norm = normalizar_nome(dado["nome"])
            if not nome_norm:
                continue

            registros.append({
                "orgao": orgao,
                "periodo": periodo,
                "nome": dado["nome"].strip(),
                "nome_normalizado": nome_norm,
                "lotacao": dado.get("lotacao", "").strip(),
                "cargo": dado.get("cargo", "").strip(),
                "funcao": dado.get("funcao", "").strip(),
                "vinculo": dado.get("vinculo", "").strip(),
                "remuneracao_total": dado.get("remuneracao_total", ""),
            })

    return registros


def deduplicar(registros: list[dict]) -> list[dict]:
    """
    Deduplica por (nome_normalizado, orgao).
    Rastreia periodo_inicio (primeira aparição) e periodo_fim (última aparição).
    Os dados funcionais (cargo, lotacao, etc.) vêm do registro mais recente.
    """
    agregado: dict[tuple, dict] = {}

    for r in registros:
        chave = (r["nome_normalizado"], r["orgao"])
        periodo = r["periodo"]

        if chave not in agregado:
            agregado[chave] = {**r, "periodo_inicio": periodo, "periodo_fim": periodo}
        else:
            atual = agregado[chave]
            # Atualiza intervalo
            if periodo < atual["periodo_inicio"]:
                atual["periodo_inicio"] = periodo
            if periodo > atual["periodo_fim"]:
                # Período mais recente: atualiza também os dados funcionais
                atual["periodo_fim"] = periodo
                atual["lotacao"] = r["lotacao"]
                atual["cargo"] = r["cargo"]
                atual["funcao"] = r["funcao"]
                atual["vinculo"] = r["vinculo"]
                atual["remuneracao_total"] = r["remuneracao_total"]

    return list(agregado.values())


def main():
    print("Iniciando consolidação da folha de pagamento...")

    todos_registros = []
    pastas = sorted(PASTA_FOLHA.iterdir())
    total_pastas = len(pastas)

    for i, pasta in enumerate(pastas, 1):
        if not pasta.is_dir():
            continue
        print(f"[{i:02d}/{total_pastas}] {pasta.name}...", end=" ", flush=True)
        registros = processar_pasta(pasta)
        print(f"{len(registros)} registros brutos")
        todos_registros.extend(registros)

    print(f"\nTotal bruto (com duplicatas): {len(todos_registros):,}")

    deduplicados = deduplicar(todos_registros)
    print(f"Total após deduplicação:      {len(deduplicados):,}")

    # Ordena por orgao e nome_normalizado para facilitar leitura
    deduplicados.sort(key=lambda r: (r["orgao"], r["nome_normalizado"]))

    SAIDA.parent.mkdir(exist_ok=True)
    with open(SAIDA, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUNAS_SAIDA, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(deduplicados)

    print(f"\nArquivo gerado: {SAIDA}")
    print(f"Registros únicos: {len(deduplicados):,}")


if __name__ == "__main__":
    main()
