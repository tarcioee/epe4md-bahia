# =============================================================================
# Modelo 4MD (EPE) - recorte Bahia / Salvador e cenários regulatórios
#
# O que este script faz:
#   1. Define cenários de regras de compensação (Lei 14.300 e alternativas).
#   2. Para cada cenário, calcula o payback dos sistemas na área da Coelba (BA).
#   3. Roda a projeção completa do 4MD e filtra a Bahia.
#   4. Estima Salvador aplicando a participação histórica da cidade na Bahia
#      (arquivo participacao_salvador.csv, gerado por fatia_salvador.R).
#   5. Exporta tudo para resultados_cenarios.xlsx e gráficos em graficos/.
#
# Para rodar:  Rscript cenarios_bahia.R
# Para mudar premissas: edite a seção "CONFIGURAÇÃO" abaixo.
# =============================================================================

.libPaths(Sys.getenv("R_LIBS_USER"))
suppressPackageStartupMessages({
  library(epe4md)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# ---------------------------- CONFIGURAÇÃO -----------------------------------
ano_base      <- 2025
ano_final     <- 2035
distribuidora <- "COELBA"   # única distribuidora da BA no modelo
uf_alvo       <- "BA"

dir_premissas <- system.file(sprintf("dados_premissas/%d", ano_base), package = "epe4md")
premissas_epe <- readxl::read_xlsx(file.path(dir_premissas, "premissas_reg.xlsx"))

# Cada cenário é uma tabela premissas_reg (ano, alternativa, p_transicao, binomia, demanda_g).
# alternativa: 0 = compensa tudo | 1 = paga Fio B (TUSD Distribuição)
#              2 = + TUSD Transmissão | 3 = + TUSD Encargos | 4 = + Perdas | 5 = só compensa TE Energia
# p_transicao: fração da alternativa efetivamente cobrada (escalonamento).
# Altera colunas da tabela de premissas a partir de um ano
muda <- function(base, a_partir_de, ...) {
  mods <- list(...)
  for (col in names(mods)) base[[col]][base$ano >= a_partir_de] <- mods[[col]]
  base
}

cenarios <- list(
  "1_regra_antiga"      = premissas_epe %>% mutate(alternativa = 0, p_transicao = 1, demanda_g = FALSE),
  "2_lei14300_padrao"   = premissas_epe,
  "3_fioB_integral"     = muda(premissas_epe, 2023, alternativa = 1, p_transicao = 1),
  "4_pos2029_encargos"  = muda(premissas_epe, 2029, alternativa = 3, p_transicao = 1),
  "5_pos2029_binomia"   = muda(premissas_epe, 2029, binomia = TRUE)
)
# -----------------------------------------------------------------------------

dir.create("graficos", showWarnings = FALSE)

# Participação de Salvador (opcional)
part_ssa <- if (file.exists("participacao_salvador.csv")) {
  readr::read_csv("participacao_salvador.csv", show_col_types = FALSE)
} else NULL

# Casos de payback (custos, geração etc.) não dependem do cenário: calcula uma vez
casos <- epe4md_casos_payback(ano_base = ano_base, ano_max_resultado = ano_final,
                              dir_dados_premissas = dir_premissas) %>%
  filter(nome_4md == distribuidora)

paybacks <- list(); projecoes <- list()

for (nome in names(cenarios)) {
  message("\n>>> Cenário: ", nome)
  prem <- cenarios[[nome]]

  pb <- suppressWarnings(epe4md_payback(
    ano_base = ano_base, casos_payback = casos, premissas_reg = prem,
    dir_dados_premissas = dir_premissas))
  paybacks[[nome]] <- pb %>%
    filter(fonte_resumo == "Fotovoltaica", ano >= 2020, ano <= ano_final) %>%
    select(ano, segmento, payback, payback_desc, tir_real) %>%
    mutate(cenario = nome)

  res <- suppressWarnings(epe4md_calcula(
    premissas_reg = prem, ano_base = ano_base, ano_max_resultado = ano_final))
  projecoes[[nome]] <- res %>%
    filter(uf == uf_alvo) %>%
    group_by(ano, segmento) %>%
    summarise(adotantes = sum(adotantes_mes), potencia_mw = sum(pot_mes_mw),
              geracao_gwh = sum(energia_mwh) / 1000, .groups = "drop") %>%
    mutate(cenario = nome)
}

payback_df <- bind_rows(paybacks)

# Sensibilidade: payback descontado (Lei 14.300) para diferentes taxas de desconto
sensib <- bind_rows(lapply(c(0.08, 0.10, 0.13, 0.16, 0.20), function(tx) {
  suppressWarnings(epe4md_payback(
    ano_base = ano_base, casos_payback = casos, premissas_reg = cenarios[["2_lei14300_padrao"]],
    taxa_desconto_nominal = tx, dir_dados_premissas = dir_premissas)) %>%
    filter(fonte_resumo == "Fotovoltaica", ano >= 2020, ano <= ano_final) %>%
    select(ano, segmento, payback_desc, tir_real) %>%
    mutate(taxa_desconto = tx)
}))
proj_seg   <- bind_rows(projecoes)

proj_ba <- proj_seg %>%
  group_by(cenario, ano) %>%
  summarise(adotantes_ano = sum(adotantes), potencia_ano_mw = sum(potencia_mw),
            geracao_gwh = sum(geracao_gwh), .groups = "drop") %>%
  group_by(cenario) %>%
  mutate(adotantes_acum = cumsum(adotantes_ano),
         potencia_acum_mw = cumsum(potencia_ano_mw)) %>%
  ungroup()

# Salvador: histórico real da ANEEL até o ano base; depois, projeção da Bahia x
# participação da cidade por segmento. Geração: Bahia x participação na potência.
proj_ssa <- NULL
if (!is.null(part_ssa)) {
  est <- proj_seg %>%
    left_join(part_ssa, by = "segmento") %>%
    mutate(across(c(part_adotantes, part_potencia), ~ coalesce(.x, 0))) %>%
    group_by(cenario, ano) %>%
    summarise(adotantes_ano = sum(adotantes * part_adotantes),
              potencia_ano_mw = sum(potencia_mw * part_potencia),
              geracao_gwh = sum(geracao_gwh * part_potencia), .groups = "drop")

  hist_real <- readr::read_csv("historico_salvador_bahia.csv", show_col_types = FALSE) %>%
    filter(local == "Salvador", ano <= ano_base) %>%
    select(ano, adotantes_real = ucs, potencia_real = pot_mw)

  proj_ssa <- est %>%
    left_join(hist_real, by = "ano") %>%
    mutate(adotantes_ano   = ifelse(ano <= ano_base, coalesce(adotantes_real, 0), adotantes_ano),
           potencia_ano_mw = ifelse(ano <= ano_base, coalesce(potencia_real, 0), potencia_ano_mw)) %>%
    select(-adotantes_real, -potencia_real) %>%
    group_by(cenario) %>%
    arrange(ano, .by_group = TRUE) %>%
    mutate(adotantes_acum = cumsum(adotantes_ano),
           potencia_acum_mw = cumsum(potencia_ano_mw)) %>%
    ungroup()
}

# Tabela-resumo: payback residencial por cenário (formato largo, fácil de ler)
payback_resid <- payback_df %>%
  filter(segmento %in% c("residencial", "comercial_bt", "comercial_at")) %>%
  select(cenario, segmento, ano, payback) %>%
  mutate(payback = round(payback, 1)) %>%
  pivot_wider(names_from = cenario, values_from = payback) %>%
  arrange(segmento, ano)

abas <- list(
  "Leia-me" = tibble(info = c(
    "Modelo 4MD (EPE) - recorte Bahia (Coelba) e Salvador",
    sprintf("Ano base %d, projeção até %d", ano_base, ano_final),
    "Cenários:",
    "1_regra_antiga: compensa todas as componentes (sem Lei 14.300)",
    "2_lei14300_padrao: premissas da EPE (Fio B escalonado 15%..100% de 2023 a 2029)",
    "3_fioB_integral: paga 100% do Fio B desde 2023 (sem escalonamento)",
    "4_pos2029_encargos: a partir de 2029 paga Fio B + Transmissão + Encargos",
    "5_pos2029_binomia: Lei 14.300 + tarifa binômia na baixa tensão a partir de 2029",
    "payback em anos (25 = não se paga na vida útil); tir_real em fração (0.10 = 10% a.a.)",
    if (is.null(part_ssa)) "Salvador: não calculado (falta participacao_salvador.csv)"
    else "Salvador: histórico real ANEEL até o ano base; depois Bahia x participação da cidade por segmento (2023-2025)")),
  "Payback_comparado" = payback_resid,
  "Payback_detalhe"   = payback_df,
  "Sensib_taxa_desc"  = sensib,
  "Projecao_BA"       = proj_ba,
  "Projecao_BA_segm"  = proj_seg
)
if (!is.null(proj_ssa)) abas[["Projecao_Salvador"]] <- proj_ssa
if (!is.null(part_ssa)) abas[["Participacao_SSA"]] <- part_ssa
writexl::write_xlsx(abas, "resultados_cenarios.xlsx")

# --------------------------------- Gráficos ----------------------------------
tema <- theme_minimal(base_size = 12) + theme(legend.position = "bottom")

g1 <- payback_df %>% filter(segmento == "residencial") %>%
  ggplot(aes(ano, payback, colour = cenario)) + geom_line(linewidth = 1) +
  labs(title = "Payback de um sistema FV residencial - Coelba (BA)",
       x = NULL, y = "Payback simples (anos)", colour = NULL) + tema
ggsave("graficos/payback_residencial.png", g1, width = 9, height = 5.5, dpi = 150)

g2 <- ggplot(proj_ba, aes(ano, potencia_acum_mw / 1000, colour = cenario)) +
  geom_line(linewidth = 1) +
  labs(title = "Capacidade instalada acumulada de MMGD - Bahia",
       x = NULL, y = "GW", colour = NULL) + tema
ggsave("graficos/potencia_bahia.png", g2, width = 9, height = 5.5, dpi = 150)

if (!is.null(proj_ssa)) {
  g3 <- ggplot(proj_ssa, aes(ano, potencia_acum_mw, colour = cenario)) +
    geom_line(linewidth = 1) +
    labs(title = "Capacidade instalada acumulada de MMGD - Salvador (estimativa)",
         x = NULL, y = "MW", colour = NULL) + tema
  ggsave("graficos/potencia_salvador.png", g3, width = 9, height = 5.5, dpi = 150)
}

# Dados para o site (docs/data.json)
dir.create("docs", showWarnings = FALSE)
hist_ssa <- if (file.exists("historico_salvador_bahia.csv"))
  readr::read_csv("historico_salvador_bahia.csv", show_col_types = FALSE) else NULL
jsonlite::write_json(list(
  ano_base = ano_base, ano_final = ano_final,
  payback = payback_df, sensibilidade = sensib,
  projecao_ba = proj_ba, projecao_ba_segmento = proj_seg,
  projecao_salvador = proj_ssa, participacao_salvador = part_ssa,
  historico_salvador = hist_ssa
), "docs/data.json", digits = 5, auto_unbox = TRUE, na = "null")

message("\nPronto: resultados_cenarios.xlsx, graficos/ e docs/data.json")
