# =============================================================================
# MMGD x consumo na Bahia
#
# Compara a geração projetada da MMGD na Bahia com a energia distribuída pela
# Coelba e calcula a penetração (adotantes / unidades consumidoras).
#
# Referência de consumo: energia distribuída pela Neoenergia Coelba em 2024 =
# 24.641 GWh (relatório da companhia; inclui mercado cativo, livre e GD).
# Para os anos seguintes, aplica a taxa de crescimento de mercado das premissas
# do próprio 4MD (crescimento_mercado.xlsx). Para trás, usa 2023 = 23.308 GWh.
#
# Rodar depois de cenarios_bahia.R:  Rscript consumo_bahia.R
# =============================================================================

.libPaths(Sys.getenv("R_LIBS_USER"))
suppressPackageStartupMessages({ library(dplyr); library(tidyr) })

ano_base <- 2025
dir_prem <- system.file(sprintf("dados_premissas/%d", ano_base), package = "epe4md")

energia_ref <- tibble(ano = c(2023, 2024), energia_gwh = c(23308, 24641))
cresc <- readxl::read_xlsx(file.path(dir_prem, "crescimento_mercado.xlsx"))

anos <- 2024:2035
energia <- tibble(ano = anos) %>%
  left_join(cresc, by = "ano") %>%
  mutate(fator = cumprod(ifelse(ano == 2024, 1, 1 + coalesce(taxa_crescimento_mercado, 0))),
         energia_gwh = 24641 * fator) %>%
  select(ano, energia_gwh) %>%
  bind_rows(energia_ref %>% filter(ano == 2023)) %>%
  arrange(ano)

# Unidades consumidoras de baixa tensão + grupo A da Coelba (premissas EPE)
uc <- function(f) readxl::read_xlsx(file.path(dir_prem, f)) %>%
  filter(nome_4md == "COELBA") %>%
  pivot_longer(-nome_4md, names_to = "ano", values_to = "n") %>%
  mutate(ano = as.numeric(ano))
res <- readxl::read_xlsx(file.path(dir_prem, "fator_tecnico.xlsx")) %>% filter(nome_4md == "COELBA")
ucs <- uc("consumidores_b2b3.xlsx") %>% rename(b2b3 = n) %>%
  left_join(uc("consumidores_a.xlsx") %>% rename(grupo_a = n), by = c("nome_4md", "ano"))

proj <- readxl::read_xlsx("resultados_cenarios.xlsx", sheet = "Projecao_BA")

consumo <- proj %>%
  filter(ano >= 2023) %>%
  left_join(energia, by = "ano") %>%
  mutate(part_geracao_consumo = geracao_gwh / energia_gwh) %>%
  select(cenario, ano, geracao_gwh, energia_gwh, part_geracao_consumo, adotantes_acum)

# Penetração: adotantes acumulados / (domicílios + UCs B2/B3 + grupo A).
# Domicílios: total de domicílios da Coelba (fator_tecnico.xlsx, domicilios_pp), mantido constante.
total_uc_base <- res$domicilios_pp + tail(ucs$b2b3, 1) + tail(ucs$grupo_a, 1)
consumo <- consumo %>% mutate(penetracao = adotantes_acum / total_uc_base)

readr::write_csv(consumo, "consumo_bahia.csv")

# Acrescenta ao data.json do site
j <- jsonlite::read_json("docs/data.json", simplifyVector = TRUE)
j$consumo <- consumo
j$consumo_nota <- "Energia distribuída Coelba 2024 = 24.641 GWh (relatório da companhia), projetada com a taxa de crescimento de mercado das premissas 4MD."
jsonlite::write_json(j, "docs/data.json", digits = 5, auto_unbox = TRUE, na = "null")

print(as.data.frame(consumo %>% filter(ano %in% c(2024, 2025, 2030, 2035)) %>%
  mutate(across(c(part_geracao_consumo, penetracao), ~ round(.x * 100, 1)))))
