# =============================================================================
# Participação de Salvador na MMGD da Bahia (base de dados abertos da ANEEL)
#
# O 4MD projeta por distribuidora/UF. Para chegar em Salvador, este script mede
# quanto da MMGD da Bahia está em Salvador, por segmento, nos últimos anos, e
# grava participacao_salvador.csv (usado por cenarios_bahia.R).
#
# Entrada: arquivo da ANEEL "empreendimento-geracao-distribuida.parquet"
#   https://dadosabertos.aneel.gov.br/dataset/relacao-de-empreendimentos-de-geracao-distribuida
# Uso:  Rscript fatia_salvador.R caminho/para/empreendimento-geracao-distribuida.parquet
# =============================================================================

.libPaths(Sys.getenv("R_LIBS_USER"))
suppressPackageStartupMessages({
  library(arrow, warn.conflicts = FALSE)
  library(dplyr)
  library(readr)
})

arquivo   <- commandArgs(TRUE)[1]
anos_ref  <- 2023:2025   # janela usada para medir a participação (anos completos recentes)
municipio <- "Salvador"

segmento_tab <- readxl::read_xlsx(system.file("dados_premissas/2025/segmento.xlsx", package = "epe4md"))

ba <- open_dataset(arquivo) %>%
  filter(SigUF == "BA") %>%
  select(NomMunicipio, DscClasseConsumo, DscSubGrupoTarifario, DscModalidadeHabilitado,
         QtdUCRecebeCredito, MdaPotenciaInstaladaKW, DthAtualizaCadastralEmpreend) %>%
  collect() %>%
  mutate(
    ano = as.integer(format(DthAtualizaCadastralEmpreend, "%Y")),
    # mesma classificação usada em epe4md::epe4md_prepara_base
    classe = gsub("REBR", "Residencial", gsub("Iluminação pública", "Ilum. Púb.", DscClasseConsumo)),
    atbt = ifelse(DscSubGrupoTarifario %in% c("B1", "B2", "B3", "B4"), "BT", "AT"),
    local_remoto = ifelse(DscModalidadeHabilitado %in% c("Auto consumo remoto", "Compartilhada"),
                          "remoto", "local")
  ) %>%
  left_join(segmento_tab, by = c("classe", "atbt", "local_remoto"))

resumo <- function(d) d %>%
  group_by(segmento) %>%
  summarise(ucs = sum(QtdUCRecebeCredito, na.rm = TRUE),
            sistemas = n(),
            pot_mw = sum(MdaPotenciaInstaladaKW, na.rm = TRUE) / 1000, .groups = "drop")

janela  <- ba %>% filter(ano %in% anos_ref)
tot_ba  <- resumo(janela)
tot_ssa <- resumo(janela %>% filter(NomMunicipio == municipio))

part <- tot_ba %>%
  left_join(tot_ssa, by = "segmento", suffix = c("_ba", "_ssa")) %>%
  mutate(across(ends_with("_ssa"), ~ coalesce(.x, 0)),
         part_adotantes = ucs_ssa / ucs_ba,
         part_potencia  = pot_mw_ssa / pot_mw_ba) %>%
  filter(!is.na(segmento))

write_csv(part, "participacao_salvador.csv")

# Histórico anual Salvador x Bahia (para gráficos e para validar a aproximação)
hist <- ba %>%
  mutate(local = ifelse(NomMunicipio == municipio, "Salvador", "Resto da BA")) %>%
  group_by(ano, local) %>%
  summarise(sistemas = n(), ucs = sum(QtdUCRecebeCredito, na.rm = TRUE),
            pot_mw = sum(MdaPotenciaInstaladaKW, na.rm = TRUE) / 1000, .groups = "drop") %>%
  arrange(ano)
write_csv(hist, "historico_salvador_bahia.csv")

cat("Participação de Salvador na Bahia (", min(anos_ref), "-", max(anos_ref), "):\n", sep = "")
print(as.data.frame(part %>% select(segmento, ucs_ba, ucs_ssa, part_adotantes, pot_mw_ba, pot_mw_ssa, part_potencia)))
cat("\nTotal: adotantes", round(sum(part$ucs_ssa) / sum(part$ucs_ba) * 100, 1), "% | potência",
    round(sum(part$pot_mw_ssa) / sum(part$pot_mw_ba) * 100, 1), "%\n")
