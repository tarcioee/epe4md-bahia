# Figuras do artigo (lê resultados_cenarios.xlsx e consumo_bahia.csv)
.libPaths(Sys.getenv("R_LIBS_USER"))
suppressPackageStartupMessages({ library(dplyr); library(ggplot2); library(readxl) })

f <- "resultados_cenarios.xlsx"
dir.create("docs/fig", recursive = TRUE, showWarnings = FALSE)
nomes <- c("1_regra_antiga" = "1 Regra antiga", "2_lei14300_padrao" = "2 Lei 14.300",
           "3_fioB_integral" = "3 Fio B integral", "4_pos2029_encargos" = "4 Pós-2029 encargos",
           "5_pos2029_binomia" = "5 Pós-2029 binômia")
segs <- c(residencial = "Residencial", residencial_remoto = "Residencial remoto",
          comercial_bt = "Comercial BT", comercial_at = "Comercial AT",
          comercial_at_remoto = "Comercial AT remoto")
cores <- c("#7a8794", "#d9822b", "#b23a48", "#2a6f97", "#3c9d5d")
tema <- theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())
salva <- function(g, nome) ggsave(file.path("docs/fig", nome), g, width = 7, height = 4, dpi = 200, bg = "white")
base <- 2025
corte <- geom_vline(xintercept = base + 0.5, linetype = "dotted", colour = "grey40")

pb <- read_xlsx(f, "Payback_detalhe") %>% mutate(cenario = nomes[cenario])
salva(pb %>% filter(segmento == "residencial") %>%
        ggplot(aes(ano, payback, colour = cenario)) + geom_line(linewidth = .9) +
        scale_colour_manual(values = cores) + corte +
        labs(x = NULL, y = "Payback simples (anos)", colour = NULL) + tema,
      "fig1_payback_residencial.png")

ba <- read_xlsx(f, "Projecao_BA") %>% mutate(cenario = nomes[cenario])
salva(ggplot(ba, aes(ano, potencia_acum_mw / 1000, colour = cenario)) + geom_line(linewidth = .9) +
        scale_colour_manual(values = cores) + corte +
        labs(x = NULL, y = "Potência acumulada (GW)", colour = NULL) + tema,
      "fig2_potencia_bahia.png")

sg <- read_xlsx(f, "Projecao_BA_segm") %>% filter(cenario == "2_lei14300_padrao") %>%
  mutate(segmento = segs[segmento])
salva(ggplot(sg, aes(ano, adotantes / 1000, fill = segmento)) + geom_col() +
        scale_fill_manual(values = c("#d9822b", "#f0c08a", "#2a6f97", "#9cc3dc", "#3c9d5d")) + corte +
        labs(x = NULL, y = "Novos adotantes no ano (mil)", fill = NULL) + tema,
      "fig3_adotantes_segmento.png")

ssa <- read_xlsx(f, "Projecao_Salvador") %>% mutate(cenario = nomes[cenario])
salva(ggplot(ssa, aes(ano, potencia_acum_mw, colour = cenario)) + geom_line(linewidth = .9) +
        scale_colour_manual(values = cores) + corte +
        labs(x = NULL, y = "Potência acumulada (MW)", colour = NULL) + tema,
      "fig4_potencia_salvador.png")

cs <- readr::read_csv("consumo_bahia.csv", show_col_types = FALSE) %>% mutate(cenario = nomes[cenario])
salva(ggplot(cs, aes(ano, part_geracao_consumo * 100, colour = cenario)) + geom_line(linewidth = .9) +
        scale_colour_manual(values = cores) + corte +
        labs(x = NULL, y = "Geração MMGD / energia distribuída (%)", colour = NULL) + tema,
      "fig5_geracao_consumo.png")

cat("Figuras salvas em docs/fig\n")
