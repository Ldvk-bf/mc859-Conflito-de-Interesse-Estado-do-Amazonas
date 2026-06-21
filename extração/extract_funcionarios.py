import os
import re
import time

import requests

# Lista completa de órgãos extraída do portal
orgaos = [
    # {"nome": "ADAF", "id": "76"}, {"nome": "ADS", "id": "445"}, {"nome": "APOSENTADOS_EXECUTIVO", "id": "127"},
    # {"nome": "APOSENTADOS_ALEAM", "id": "10113"}, {"nome": "APOSENTADOS_PGJ", "id": "10108"}, {"nome": "APOSENTADOS_TCE", "id": "10106"},
    # {"nome": "APOSENTADOS_TJA", "id": "10110"}, {"nome": "ARSEPAM", "id": "93"}, {"nome": "CASA_CIVIL", "id": "77"},
    # {"nome": "CASA_MILITAR", "id": "94"}, {"nome": "CB_CIVIS", "id": "95"}, {"nome": "CBMAM", "id": "96"},
    # {"nome": "CETAM", "id": "74"}, {"nome": "CGE", "id": "75"}, {"nome": "CSC", "id": "97"},
    # {"nome": "DEFESA_CIVIL", "id": "13891"}, {"nome": "DETRAN", "id": "98"}, {"nome": "ERGSP", "id": "99"},
    # {"nome": "FAAR", "id": "4572"}, {"nome": "FAPEAM", "id": "100"}, {"nome": "FCECON", "id": "101"},
    # {"nome": "FEH", "id": "86"},
    # {"nome": "FEPIAM", "id": "396"}, {"nome": "FHAJ", "id": "102"},
    # {"nome": "FHEMOAM", "id": "103"}, {"nome": "FMT-AM", "id": "104"}, {"nome": "FUHAM", "id": "92"},
    # {"nome": "FUNATI", "id": "12954"}, 
    {"nome": "AMAZONPREV", "id": "87"}, {"nome": "VILA_OLIMPICA", "id": "105"},
    {"nome": "FUNTEC", "id": "106"}, {"nome": "FVS", "id": "17"}, {"nome": "IDAM", "id": "107"},
    {"nome": "IMPRENSA_OFICIAL", "id": "108"}, {"nome": "IPAAM", "id": "109"}, {"nome": "IPEM-AM", "id": "110"},
    {"nome": "JUCEA", "id": "111"}, {"nome": "OUVIDORIA", "id": "112"}, {"nome": "PENSIONISTAS_EXEC", "id": "128"},
    {"nome": "PENSIONISTAS_ALEAM", "id": "10112"}, {"nome": "PENSIONISTAS_PGJ", "id": "10107"}, {"nome": "PENSIONISTAS_TCE", "id": "10105"},
    {"nome": "PENSIONISTAS_TJA", "id": "10109"}, {"nome": "PGE", "id": "80"}, {"nome": "PM_ATIVOS", "id": "113"},
    {"nome": "PM_CIVIS", "id": "114"}, {"nome": "POLICIA_CIVIL", "id": "115"}, {"nome": "PROCON", "id": "4573"},
    {"nome": "PRODAM", "id": "136"}, {"nome": "SEAD", "id": "90"}, {"nome": "SEAP", "id": "73"},
    {"nome": "SEAS", "id": "82"}, {"nome": "SEC", "id": "126"}, {"nome": "SECOM", "id": "72"},
    {"nome": "SECT", "id": "122"}, {"nome": "SEDECTI", "id": "83"}, {"nome": "SEDEL", "id": "13378"},
    {"nome": "SEDUC", "id": "91"}, {"nome": "SEDURB", "id": "13748"}, {"nome": "SEFAZ", "id": "89"},
    {"nome": "SEGOV", "id": "13280"}, {"nome": "SEIND", "id": "22"}, {"nome": "SEINFRA", "id": "116"},
    {"nome": "SEJEL", "id": "117"}, {"nome": "SEJUSC", "id": "84"}, {"nome": "SEMA", "id": "81"},
    {"nome": "SEMIG", "id": "13281"}, {"nome": "SEPA", "id": "14377"}, {"nome": "SEPCD", "id": "14378"},
    {"nome": "SEPED", "id": "118"}, {"nome": "SEPET", "id": "14376"}, {"nome": "SEPROR", "id": "119"},
    {"nome": "SERFI", "id": "397"}, {"nome": "SERGB", "id": "79"}, {"nome": "SES", "id": "88"},
    {"nome": "SETRAB", "id": "120"}, {"nome": "SGVG", "id": "78"}, {"nome": "SNPH", "id": "121"},
    {"nome": "SRMM", "id": "71"}, {"nome": "SSP", "id": "123"}, {"nome": "SUHAB", "id": "124"},
    {"nome": "UEA", "id": "125"}, {"nome": "UGPADEAM", "id": "13800"}, {"nome": "UGPE", "id": "85"}
]

# De 2014 a 2026
anos = range(2014, 2027) 

session = requests.Session()
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': 'https://www.transparencia.am.gov.br/pessoal/',
    'X-Requested-With': 'XMLHttpRequest'
}

url_ajax = 'https://www.transparencia.am.gov.br/wp-admin/admin-ajax.php'

output_dir = "folha_pagamento_am"
os.makedirs(output_dir, exist_ok=True)

print("Entrando na página principal para pegar Cookies...")
try:
    session.get('https://www.transparencia.am.gov.br/pessoal/', headers=headers, timeout=15)
    print("Cookies capturados. Iniciando coleta em massa...")
except Exception as e:
    print(f"Erro ao acessar a página inicial: {e}")

for orgao in orgaos:
    id_seletor = orgao['id']
    nome_orgao = orgao['nome']
    
    orgao_dir = os.path.join(output_dir, nome_orgao.replace('/', '_').replace(' ', '_'))
    os.makedirs(orgao_dir, exist_ok=True)
    
    print(f"\n[{nome_orgao}] ======================================")
    
    for ano in anos:
        payload = {
            'action': 'get_meses_docs',
            'ano': str(ano),
            'orgao_id': id_seletor
        }
        
        try:
            res = session.post(url_ajax, data=payload, headers=headers, timeout=15)
            
            if res.status_code == 200:
                arquivos_csv = re.findall(r'(\d+_\d{6}\.csv)', res.text)
                arquivos_pdf = re.findall(r'(\d+_\d{6}\.pdf)', res.text)
                
                arquivos_encontrados = arquivos_csv if arquivos_csv else arquivos_pdf
                
                if not arquivos_encontrados:
                    print(f"  └ Ano {ano}: ❌ Nenhum arquivo listado.")
                    continue
                
                for nome_arquivo in set(arquivos_encontrados):
                    link = f"https://www.transparencia.am.gov.br/arquivos/{ano}/{nome_arquivo}"
                    filepath = os.path.join(orgao_dir, nome_arquivo)
                    
                    if os.path.exists(filepath):
                        print(f"  └ Ano {ano}: ⏭️ JÁ EXISTE ({nome_arquivo})")
                        continue
                    
                    try:
                        arquivo_res = session.get(link, stream=True, headers=headers, timeout=15)
                        
                        if arquivo_res.status_code == 200 and 'text/html' not in arquivo_res.headers.get('Content-Type', ''):
                            with open(filepath, 'wb') as f:
                                f.write(arquivo_res.content)
                            print(f"  └ Ano {ano}: ✅ BAIXADO ({nome_arquivo})")
                        else:
                            print(f"  └ Ano {ano}: ⚠️ Erro {arquivo_res.status_code} ou HTML retornado ({nome_arquivo})")
                    except Exception as e:
                        print(f"  └ Ano {ano}: ❌ Falha ao baixar {nome_arquivo} - {e}")
                    
                    time.sleep(0.5) 
            else:
                 print(f"  └ Ano {ano}: ❌ Erro ao consultar API ({res.status_code})")
                 
        except Exception as e:
            print(f"  └ Ano {ano}: Erro de conexão ao processar - {e}")
        
        time.sleep(1) 

print("\nColeta finalizada!")