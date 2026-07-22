#!/usr/bin/env Rscript
# Generates the two data-driven figures for the slide deck:
#   chart-cost.svg          input vs output token pricing (asymmetry)
#   chart-context-rot.svg   "lost in the middle" + degradation with length
#
# Numbers are illustrative and date-stamped (mid-2026). The point is the
# SHAPE of each relationship, not exact values. Built in R/ggplot2 on
# purpose: the audience knows R, and the deck is about coding agents.

suppressPackageStartupMessages({
  library(ggplot2)
})

# --- shared look -------------------------------------------------------------
ink    <- "#1f2933"
slate  <- "#52606d"
blue   <- "#2b6cb0"   # input / context
amber  <- "#dd6b20"   # output
green  <- "#2f855a"
coral  <- "#c53030"
grid   <- "#e2e8f0"

theme_slide <- function(base_size = 15) {
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(colour = ink),
      plot.title       = element_text(face = "bold", size = base_size + 3),
      plot.subtitle    = element_text(colour = slate, size = base_size - 2),
      plot.caption     = element_text(colour = slate, size = base_size - 4, hjust = 0),
      axis.title       = element_text(colour = slate),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = grid),
      legend.position  = "top",
      legend.title     = element_blank(),
      strip.text       = element_text(face = "bold", colour = ink, size = base_size),
      plot.margin      = margin(12, 16, 10, 12)
    )
}

here <- function(f) file.path(dirname(sub("--file=", "",
  grep("--file=", commandArgs(FALSE), value = TRUE)[1])), f)
if (is.na(here("x"))) here <- function(f) f   # fallback for interactive use

# --- 1. input vs output pricing ---------------------------------------------
cost <- data.frame(
  model = factor(rep(c("Model A\n(e.g. Claude Sonnet 4.5)",
                       "Model B\n(e.g. Gemini 2.5 Pro)"), each = 2),
                 levels = c("Model A\n(e.g. Claude Sonnet 4.5)",
                            "Model B\n(e.g. Gemini 2.5 Pro)")),
  kind  = factor(rep(c("Input (reading)", "Output (writing)"), 2),
                 levels = c("Input (reading)", "Output (writing)")),
  price = c(3, 15, 1.25, 10)
)

p_cost <- ggplot(cost, aes(model, price, fill = kind)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_text(aes(label = paste0("$", price)),
            position = position_dodge(width = 0.7), vjust = -0.4,
            size = 4.6, fontface = "bold", colour = ink) +
  scale_fill_manual(values = c("Input (reading)" = blue,
                               "Output (writing)" = amber)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title    = "Output tokens cost several times more than input",
    subtitle = "Price per 1,000,000 tokens — reading is cheap, writing is expensive",
    x = NULL, y = "USD per million tokens",
    caption  = "Illustrative, mid-2026. Exact prices change constantly; the 4–8× gap is the durable point."
  ) +
  theme_slide()

ggsave(here("chart-cost.svg"), p_cost, width = 8.2, height = 4.6, bg = "white", device = grDevices::svg)

# --- 2a. lost in the middle --------------------------------------------------
pos <- seq(0, 1, length.out = 50)
mid <- data.frame(
  position = pos,
  # U-shaped: high at ends, dips in the middle
  accuracy = 0.62 + 0.36 * (2 * (pos - 0.5))^2
)
mid$panel <- "Where the fact sits in the window"

p_mid <- ggplot(mid, aes(position, accuracy)) +
  geom_line(colour = blue, linewidth = 1.6) +
  annotate("text", x = 0.5, y = 0.555, label = "buried in the middle\n→ easy to miss",
           colour = coral, size = 4, lineheight = 0.95) +
  scale_x_continuous(breaks = c(0, 0.5, 1),
                     labels = c("start", "middle", "end")) +
  scale_y_continuous(labels = scales::percent, limits = c(0.5, 1.02)) +
  labs(x = "position of the key fact", y = "chance it's used correctly") +
  facet_wrap(~panel) +
  theme_slide()

# --- 2b. degradation with length --------------------------------------------
len <- data.frame(
  tokens   = c(2, 10, 25, 50, 100, 250, 500, 1000) * 1e3,
  accuracy = c(0.95, 0.93, 0.90, 0.86, 0.80, 0.72, 0.64, 0.55)
)
len$panel <- "As the context gets longer"

p_len <- ggplot(len, aes(tokens, accuracy)) +
  geom_line(colour = amber, linewidth = 1.6) +
  geom_point(colour = amber, size = 2.4) +
  scale_x_log10(labels = function(x) ifelse(x >= 1e6, paste0(x / 1e6, "M"),
                                             paste0(x / 1e3, "K"))) +
  scale_y_continuous(labels = scales::percent, limits = c(0.5, 1.02)) +
  labs(x = "tokens in context (log scale)", y = "answer quality") +
  facet_wrap(~panel) +
  theme_slide()

# combine the two panels side by side
suppressPackageStartupMessages({
  has_patchwork <- requireNamespace("patchwork", quietly = TRUE)
})
if (has_patchwork) {
  combined <- patchwork::wrap_plots(p_mid, p_len, ncol = 2) +
    patchwork::plot_annotation(
      title = "More context is not always better",
      subtitle = "Schematic of two robust findings: \"lost in the middle\" and degradation with length",
      caption = "Schematic, based on Liu et al. 2023 (\"Lost in the Middle\") and 2025 \"context rot\" studies. Curves are illustrative.",
      theme = theme_slide()
    )
  ggsave(here("chart-context-rot.svg"), combined, width = 9.6, height = 4.4, bg = "white", device = grDevices::svg)
} else {
  # fallback: just save the lost-in-the-middle panel
  ggsave(here("chart-context-rot.svg"),
         p_mid + labs(title = "More context is not always better"),
         width = 6, height = 4.4, bg = "white", device = grDevices::svg)
}

cat("charts written to", dirname(here("chart-cost.svg")), "\n")
