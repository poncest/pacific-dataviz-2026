# =============================================================================
# 06_observed_signals.R
# Pacific Dataviz Challenge 2026 — Observed-signals element
#
# Purpose: ground the piece's warming framing in OBSERVED official data.
#   Visual: Tuvalu sea-surface temperature (SST) anomaly trend — the chartable
#           signal (negative for a century → +0.6–0.9 °C recently).
#   Cited:  Sea Level Anomalies — too coarse (0.1 m rounding) to trend-chart, so
#           it's reported as a figure for the prose / data-sources block, not plotted.
#
# §9 compliance: BOTH datasets are on the official 2026 list (.Stat Climate
#   Change Indicators). Either alone satisfies §9; both over-satisfy it.
#
# HONESTY GUARDRAILS (do not violate):
#   - This is LOCAL sea-surface temperature anomaly. It is NOT the global
#     1°C/1.5°C warming target. Never equate the two. Frame as "the ocean
#     around Tuvalu is measurably warming," distinct from the global thresholds.
#   - The source file is mislabeled "Mean surface temperature" but the indicator
#     is SST_ANOM = SEA SURFACE temperature. Cite it as "sea surface temperature."
#
# Data:   data/  (two .Stat exports; adjust filenames below if you renamed them)
# Output: output/06_observed/tuvalu_sst_trend.png   (7 × 4 in · 320 dpi)
#
# Author:  Steven Ponce
# Session: 10 — May 31, 2026
# =============================================================================


# -----------------------------------------------------------------------------
# 0. Libraries
# -----------------------------------------------------------------------------
library(ggplot2)
library(ggtext)
library(showtext)
library(here)


# -----------------------------------------------------------------------------
# 1. Typography — matches 03_ / 05_ exactly
# -----------------------------------------------------------------------------
font_add_google("Big Shoulders",  family = "big_shoulders")
font_add_google("DM Sans",        family = "dm_sans")
font_add_google("JetBrains Mono", family = "jetbrains_mono")
showtext_auto()
showtext_opts(dpi = 320)


# -----------------------------------------------------------------------------
# 2. Pacific Currents palette — locked in Session 2
# -----------------------------------------------------------------------------
clrs <- list(
  abyss = "#07142F", tide = "#102447", reef = "#4FE0CC", coral = "#FF7A59",
  sand  = "#F2EDE2", mist = "#6E83AB", land = "#4A5E35", hair = "#2A4A87"
)
col_abyss <- clrs$abyss; col_tide <- clrs$tide; col_reef <- clrs$reef
col_coral <- clrs$coral; col_sand <- clrs$sand; col_mist <- clrs$mist
col_hair  <- clrs$hair


# -----------------------------------------------------------------------------
# 3. Data — read the two .Stat exports from data/
#    Adjust these filenames if you renamed them in your data/ folder.
# -----------------------------------------------------------------------------
sst_file <- "Mean_surface_temperature_anomalies_filtered_2026-05-31.csv"
sl_file  <- "Sea_level_anomalies_filtered_2026-05-31.csv"

sst_raw <- read.csv(here::here("data", sst_file), check.names = TRUE)

# Tuvalu sea-surface temperature anomaly series (indicator SST_ANOM, °C)
sst_tv <- subset(sst_raw, GEO_PICT == "TV",
                 select = c(TIME_PERIOD, OBS_VALUE))
sst_tv <- sst_tv[order(sst_tv$TIME_PERIOD), ]
names(sst_tv) <- c("year", "anom_c")

# Peak figure for the annotation — the warmest year in the record (computed,
# so it stays accurate if the data is re-pulled). A min/max range over the last
# decade would catch cool outlier years (e.g. the 2022 dip) and read as "+-0.1".
peak_i    <- which.max(sst_tv$anom_c)
peak_year <- sst_tv$year[peak_i]
peak_val  <- sst_tv$anom_c[peak_i]


# -----------------------------------------------------------------------------
# 4. Theme — Pacific Currents dark, consistent with map / slope outputs
# -----------------------------------------------------------------------------
theme_pacific_trend <- function() {
  theme_minimal(base_family = "dm_sans") +
    theme(
      plot.background  = element_rect(fill = col_abyss, color = NA),
      panel.background = element_rect(fill = col_tide,  color = NA),
      panel.border     = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(color = alpha(col_hair, 0.25),
                                        linewidth = 0.3),
      axis.text.x = element_text(family = "jetbrains_mono", color = col_sand,
                                 size = 10, margin = margin(t = 6)),
      axis.text.y = element_text(family = "jetbrains_mono", color = col_mist,
                                 size = 9),
      axis.title  = element_blank(),
      axis.ticks  = element_blank(),
      plot.title = element_text(family = "big_shoulders", color = col_sand,
                                size = 20, face = "bold", margin = margin(b = 6)),
      plot.subtitle = element_markdown(family = "dm_sans", color = col_mist,
                                       size = 10, margin = margin(b = 16)),
      plot.caption = element_text(family = "jetbrains_mono", color = col_mist,
                                  size = 7, hjust = 0, lineheight = 1.3,
                                  margin = margin(t = 14)),
      plot.margin = margin(t = 20, r = 26, b = 16, l = 16)
    )
}


# -----------------------------------------------------------------------------
# 5. Build chart — observed SST anomaly trend
# -----------------------------------------------------------------------------
caption_text <- paste0(
  "Source: SPC Pacific Data Hub \u00b7 Sea Surface Temperature anomalies (SST_ANOM), Tuvalu \u00b7 \u00b0C vs baseline\n",
  "Local ocean temperature \u2014 distinct from the global 1\u00b0C / 1.5\u00b0C warming targets"
)

# Annotation anchors — first-pass; nudge after first render (chart-eval rule)
ann_x <- 1862     # left edge of callout (data x = year)
ann_y <- 0.92     # callout y (\u00b0C)

trend <- ggplot(sst_tv, aes(x = year, y = anom_c)) +
  
  # zero baseline
  geom_hline(yintercept = 0, color = col_hair, linewidth = 0.4) +
  
  # annual variability — thin, faint
  geom_line(color = col_mist, linewidth = 0.4, alpha = 0.55) +
  
  # the signal — smoothed warming trend
  geom_smooth(method = "loess", span = 0.4, se = FALSE,
              color = col_coral, linewidth = 1.8) +
  
  # callout (upper-left empty space, above the cool early record)
  annotate("text", x = ann_x, y = ann_y, hjust = 0,
           label = "Recent years are the warmest observed",
           family = "dm_sans", color = col_coral, size = 4.0, fontface = "bold") +
  annotate("text", x = ann_x, y = ann_y - 0.22, hjust = 0,
           label = sprintf("%d reached +%.1f \u00b0C above baseline",
                           peak_year, peak_val),
           family = "dm_sans", color = col_sand, size = 3.2) +
  
  scale_x_continuous(breaks = seq(1860, 2020, by = 40),
                     expand = expansion(mult = c(0.02, 0.03))) +
  scale_y_continuous(breaks = seq(-1.5, 1.0, by = 0.5),
                     labels = function(y) sprintf("%+.1f\u00b0", y)) +
  coord_cartesian(ylim = c(-1.7, 1.15), clip = "off") +
  
  labs(
    title    = "The warming isn't hypothetical",
    subtitle = "Observed sea-surface temperature anomaly \u00b7 Tuvalu \u00b7 1850\u20132025",
    caption  = caption_text
  ) +
  theme_pacific_trend()


# -----------------------------------------------------------------------------
# 6. Save
# -----------------------------------------------------------------------------
output_dir <- here::here("output", "06_observed")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

ggsave(
  filename = file.path(output_dir, "tuvalu_sst_trend.png"),
  plot     = trend,
  width    = 7, height = 4, dpi = 320, bg = col_abyss
)
message("\u2713 tuvalu_sst_trend.png written to output/06_observed/")


# -----------------------------------------------------------------------------
# 7. Sea-level citation figure (NOT charted — reported for the data-sources block)
#    The series is rounded to 0.1 m, so it's cited as a stated figure, not plotted.
# -----------------------------------------------------------------------------
sl_raw <- read.csv(here::here("data", sl_file), check.names = TRUE)
sl_tv  <- subset(sl_raw, GEO_PICT == "TV", select = c(TIME_PERIOD, OBS_VALUE))
sl_tv  <- sl_tv[order(sl_tv$TIME_PERIOD), ]
sl_change <- tail(sl_tv$OBS_VALUE, 1) - head(sl_tv$OBS_VALUE, 1)

message(sprintf(
  "Sea-level citation: Tuvalu anomaly %+.1f m over %d\u2013%d (SPC, SEA_LVL). Funafuti tide gauge \u2248 3.9 mm/yr.",
  sl_change, min(sl_tv$TIME_PERIOD), max(sl_tv$TIME_PERIOD)
))


# -----------------------------------------------------------------------------
# 8. QMD placement note (not executed — reference only)
# -----------------------------------------------------------------------------
# Place this observed-signals chart near the scenarios (e.g., just before or
# after "The Numbers Behind the Maps"), as the observed anchor under the modeled
# thresholds:
#
#   ![](output/06_observed/tuvalu_sst_trend.png)
#
# Add BOTH official datasets to the .data-sources block in 04_ (§9 citation):
#   <li>Sea Surface Temperature anomalies, Tuvalu — SPC Pacific Data Hub
#       (.Stat Climate Change Indicators, <code>SST_ANOM</code>).</li>
#   <li>Sea Level Anomalies, Tuvalu — SPC Pacific Data Hub
#       (.Stat Climate Change Indicators, <code>SEA_LVL</code>); observed change
#       cited in text, Funafuti tide gauge ~3.9 mm/yr.</li>
#
# Suggested one-line prose anchor (keeps the global/local distinction honest):
#   "Globally the debate is framed as 1°C vs 1.5°C. Around Tuvalu, the ocean is
#    already measurably warmer — and the sea is already higher."
# =============================================================================