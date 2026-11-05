# Teste rápido do modelo 4MD: projeção da Bahia até 2035
.libPaths(Sys.getenv("R_LIBS_USER"))
suppressPackageStartupMessages({
  library(epe4md)
  library(dplyr)
})

ano_base <- 2025

premissas <- readxl::read_xlsx(
  system.file(sprintf("dados_premissas/%d/premissas_reg.xlsx", ano_base), package = "epe4md")
)
cat("Premissas regulatórias:\n"); print(premissas, n = 20)

resultado <- epe4md_calcula(
  premissas_reg = premissas,
  ano_base = ano_base,
  ano_max_resultado = 2035
)

bahia <- resultado %>%
  filter(uf == "BA") %>%
  group_by(ano) %>%
  summarise(adotantes_ano = sum(adotantes_mes),
            potencia_ano_mw = sum(pot_mes_mw),
            geracao_gwh = sum(energia_mwh) / 1000) %>%
  mutate(adotantes_acum = cumsum(adotantes_ano),
         potencia_acum_mw = round(cumsum(potencia_ano_mw)))

cat("\nDistribuidoras na BA:", unique(resultado$nome_4md[resultado$uf == "BA"]), "\n\n")
print(bahia, n = 50)

writexl::write_xlsx(bahia, "resultado_bahia.xlsx")
cat("\nSalvo em resultado_bahia.xlsx\n")
