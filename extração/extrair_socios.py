import time

import pandas as pd
import requests
from tqdm import tqdm

# 1. Carregar o arquivo e limpar os CNPJs
print("Carregando base de contratos...")
# Ajuste o nome do arquivo e o separador conforme sua base
df_contratos = pd.read_csv('contratos_amazonas.csv', sep=';')

# Remove pontos, barras e traços do CNPJ
df_contratos['cnpj_clean'] = df_contratos['CNPJ_Fornecedor'].str.replace(r'\D', '', regex=True)

# Pega apenas os CNPJs únicos válidos
cnpjs_unicos = df_contratos[df_contratos['cnpj_clean'].str.len() == 14]['cnpj_clean'].unique()
print(f"Total de CNPJs únicos para buscar: {len(cnpjs_unicos)}")

# 2. Consultar a BrasilAPI
dados_socios = []
erros = []

print("Buscando sócios na BrasilAPI...")
for cnpj in tqdm(cnpjs_unicos):
    url = f"https://brasilapi.com.br/api/cnpj/v1/{cnpj}"
    
    try:
        response = requests.get(url, timeout=10)
        
        if response.status_code == 200:
            dados = response.json()
            qsa = dados.get('qsa', []) # Quadro de Sócios e Administradores
            
            # Se a empresa não tiver sócios listados, salva pelo menos a razão social
            if not qsa:
                dados_socios.append({
                    'cnpj_empresa': cnpj,
                    'razao_social': dados.get('razao_social', ''),
                    'nome_socio': 'NÃO INFORMADO',
                    'cpf_cnpj_socio': '',
                    'qualificacao': ''
                })
            else:
                for socio in qsa:
                    dados_socios.append({
                        'cnpj_empresa': cnpj,
                        'razao_social': dados.get('razao_social', ''),
                        'nome_socio': socio.get('nome_socio', ''),
                        'cpf_cnpj_socio': socio.get('cnpj_cpf_do_socio', ''),
                        'qualificacao': socio.get('qualificacao_socio', '')
                    })
        else:
            erros.append({'cnpj': cnpj, 'status': response.status_code})
            
    except requests.exceptions.RequestException as e:
        erros.append({'cnpj': cnpj, 'status': 'Timeout/Erro de Conexão'})
    
    # Pausa de 0.5 segundos para evitar bloqueio por excesso de requisições
    time.sleep(0.5)

# 3. Salvar os resultados
df_socios = pd.DataFrame(dados_socios)
df_socios.to_csv('tabela_sociedades.csv', index=False, sep=';')

print(f"Extração concluída! {len(df_socios)} relacionamentos salvos em 'tabela_sociedades.csv'.")
if erros:
    print(f"Houve falha na consulta de {len(erros)} CNPJs. Verifique a lista de erros.")    