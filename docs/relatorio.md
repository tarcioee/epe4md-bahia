---
title: "Relatório: modelo 4MD aplicado à Bahia e a Salvador"
date: "5 de novembro de 2026"
lang: pt-BR
---

[← Voltar ao site](index.html){.voltar}

## Resumo

Pegamos o modelo 4MD da EPE, que projeta a micro e minigeração distribuída (MMGD) no Brasil, e o aplicamos à **Bahia** e a **Salvador**. Em seguida, comparamos **5 cenários de regras de compensação** (Lei 14.300) para ver quando ainda vale a pena instalar painéis solares (*payback*) e quanto a MMGD representa do consumo do estado. Tudo está automatizado em scripts R, publicado neste site e acompanhado de um mini-artigo de iniciação científica.

## O que foi pedido (áudio)

1. Rodar o 4MD em escala menor que a nacional: **estado da Bahia** e **cidade de Salvador**.
2. Ligar o modelo às **mudanças de regulação da MMGD** para entender **em que situação vale a pena instalar** painéis fotovoltaicos (*payback*) e a questão do **consumo**.

## O que foi feito

| Etapa | Como | Resultado |
|---|---|---|
| Instalação | R 4.6.2 + pacote `epe4md` 0.1.5 (EPE) + `arrow`, `tidyverse` | Modelo rodando localmente |
| Recorte Bahia | Resultados nacionais filtrados por UF (BA = distribuidora Coelba) | Projeção anual por segmento até 2035 |
| Recorte Salvador | Base de dados abertos da ANEEL (município de cada usina): histórico real até 2025 + participação da cidade (2023–2025) aplicada à projeção | Estimativa anual até 2035 |
| Cenários regulatórios | 5 versões da tabela `premissas_reg` (regra antiga, Lei 14.300, Fio B integral, pós-2029 com encargos, pós-2029 binômia) | Projeções e *payback* por cenário |
| *Payback* e TIR | Fluxo de caixa do próprio modelo, por segmento e ano, na Coelba | *Payback* simples, descontado e TIR real |
| Sensibilidade | Taxa de desconto de 8% a 20% a.a. | Robustez do *payback* |
| Consumo | Geração MMGD × energia distribuída pela Coelba (24.641 GWh em 2024) e adotantes × unidades consumidoras | Participação no consumo e penetração |
| Entregáveis | Site interativo, planilha Excel, mini-artigo (PDF/HTML), código no GitHub | Este site |

## Principais resultados

- **Ainda vale a pena instalar.** Pelas premissas da EPE, o *payback* residencial na Coelba fica entre **1,7 e 3,4 anos em 2030**, conforme o cenário. A Lei 14.300 acrescenta cerca de meio ano. A tarifa binômia na baixa tensão (cenário 5) seria a regra mais pesada.
- **Segmento mais afetado:** geração **remota comercial em alta tensão**, que deixa de se pagar com as regras novas (era ~8 anos na regra antiga).
- **Bahia:** 2,60 GW e 507 mil adotantes em 2025. Em 2035, **4,24 GW** na Lei 14.300, contra 4,52 GW na regra antiga (−6%) e 4,04 GW com tarifa binômia (−11%).
- **Consumo:** a MMGD gerou cerca de **14%** da energia distribuída na Bahia em 2025 e chega a **18–20%** em 2035. A penetração vai de 10,7% para ~15% das unidades consumidoras.
- **Salvador:** 4,3% dos adotantes e 5,1% da potência da Bahia (2023–2025). Tinha **151 MW** em 2025 e chega a **~247 MW** em 2035 (de 238 a 260 MW, conforme o cenário).

## Pontos de atenção (limitações)

1. **Queda brusca em 2026 em todos os cenários.** O modelo considera que o mercado potencial da geração remota residencial e do comercial em baixa tensão na Bahia já se esgotou com o boom de 2022–2025. É um efeito do modelo, não da regulação, e vale discutir com o orientador.
2. ***Payback* baixo.** ~2 anos é menos que os 3–5 anos que o mercado costuma citar. As premissas nacionais (custo R\$ 2,84/Wp, fator de capacidade 17%) podem ser otimistas para a Bahia.
3. **Cenário "Fio B integral" com mais adoção que a Lei 14.300.** Provável efeito da calibração da curva S com o histórico.
4. **Salvador é estimativa.** A ANEEL registra o município da usina, então a geração remota no interior que abate contas em Salvador não entra.
5. **Consumo de referência** vem do relatório da Coelba, não da EPE.

## Arquivos

- **Site interativo:** [index.html](index.html)
- **Mini-artigo:** [PDF](artigo.pdf) · [HTML](artigo.html) (o autor e o orientador estão como `[Nome do Autor]` e `[Orientador(a)]`, para preencher)
- **Planilha completa:** [resultados_cenarios.xlsx](resultados_cenarios.xlsx)
- **Código:** <https://github.com/tarcioee/epe4md-bahia>
  - `fatia_salvador.R`: participação de Salvador (ANEEL)
  - `cenarios_bahia.R`: cenários, *payback*, sensibilidade, projeções e exportação
  - `consumo_bahia.R`: MMGD × consumo e penetração
  - `figuras_artigo.R`: figuras do artigo

## Como mudar algo e rodar de novo

1. Edite a seção **CONFIGURAÇÃO** em `cenarios_bahia.R` (ano, cenários, parâmetros).
2. Rode `Rscript cenarios_bahia.R`, depois `Rscript consumo_bahia.R` e `Rscript figuras_artigo.R` (~8 minutos ao todo).
3. Para outra cidade, troque `municipio` em `fatia_salvador.R`.

## Próximos passos sugeridos

- Calibrar custo, irradiação e autoconsumo com dados da Bahia e comparar o *payback* com o de instaladores locais.
- Tratar a geração compartilhada separadamente no mercado potencial.
- Testar outros parâmetros do modelo: baterias (`simula_bateria = TRUE`), incentivos (`desconto_capex_local`) e filtros de renda.
