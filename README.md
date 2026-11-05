# 4MD Bahia: micro e minigeração distribuída na Bahia e em Salvador

Recorte regional do modelo [4MD da EPE](https://epe-gov-br.github.io/epe4md/) para a **Bahia** (área da Coelba) e para **Salvador**. Inclui uma comparação de **cenários regulatórios** (Lei 14.300/2022) e do **payback** de quem instala painéis fotovoltaicos.

**Site com os resultados:** https://tarcioee.github.io/epe4md-bahia/

## O que tem aqui

| Arquivo | O que faz |
|---|---|
| `fatia_salvador.R` | Lê a base de dados abertos da ANEEL e calcula a participação de Salvador na MMGD da Bahia, por segmento (2023–2025). |
| `cenarios_bahia.R` | Roda o 4MD em 5 cenários regulatórios, calcula payback/TIR na Coelba e faz a sensibilidade à taxa de desconto. Também projeta a Bahia, estima Salvador e exporta Excel, gráficos e `docs/data.json`. |
| `consumo_bahia.R` | Compara a geração da MMGD com a energia distribuída pela Coelba e calcula a penetração (adotantes / unidades consumidoras). |
| `teste_bahia.R` | Teste mínimo: uma rodada do modelo filtrando a Bahia. |
| `resultados_cenarios.xlsx` | Todos os resultados em planilha. |
| `docs/` | Site (GitHub Pages), artigo e relatório. |

## Como reproduzir

1. Instale o R (≥ 4.3) e os pacotes:
   ```r
   install.packages(c("remotes", "tidyverse", "readxl", "writexl", "arrow", "jsonlite"))
   remotes::install_github("EPE-GOV-BR/epe4md")
   ```
2. Baixe `empreendimento-geracao-distribuida.parquet` em
   [dadosabertos.aneel.gov.br](https://dadosabertos.aneel.gov.br/dataset/relacao-de-empreendimentos-de-geracao-distribuida).
3. Rode, nesta ordem:
   ```bash
   Rscript fatia_salvador.R caminho/empreendimento-geracao-distribuida.parquet
   Rscript cenarios_bahia.R
   Rscript consumo_bahia.R
   ```
   A rodada completa leva cerca de 15–20 minutos (são 5 projeções nacionais).

## Como mudar premissas

Tudo fica na seção **CONFIGURAÇÃO** no topo de `cenarios_bahia.R`:

- `ano_base`, `ano_final`: horizonte da projeção.
- `cenarios`: cada cenário é uma tabela `premissas_reg` (ano, alternativa, p_transicao, binomia, demanda_g). Para criar um novo, copie uma linha e use `muda(premissas_epe, ano, coluna = valor)`.
- Outros parâmetros do modelo (inflação, taxa de desconto, custo de reforço de rede, filtro de renda etc.) podem ser passados para `epe4md_calcula()` e `epe4md_payback()`. Veja `?epe4md_calcula`.

Para outra cidade, troque `municipio <- "Salvador"` em `fatia_salvador.R`. Para outro estado, troque `distribuidora` e `uf_alvo`.

## Limitações

- O 4MD trabalha por distribuidora/UF. Salvador é uma **estimativa** (projeção da BA × participação histórica da cidade), não uma rodada própria do modelo.
- A base da ANEEL registra o município da **usina**. A geração remota instalada no interior que abate contas em Salvador não entra na fatia da capital.
- O consumo de referência (energia distribuída pela Coelba em 2024) vem do relatório da companhia e não da EPE.

Modelo 4MD © Empresa de Pesquisa Energética (GPL-3). Este repositório só aplica o modelo a um recorte regional.
