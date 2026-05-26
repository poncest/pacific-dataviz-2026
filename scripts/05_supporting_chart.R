# =============================================================================
# 05_supporting_chart.R
# Pacific Dataviz Challenge 2026 — Supporting Chart
#
# Chart: "A Half-Degree of Warming, Twice the Exposure"
# Metric: Modeled share of Funafuti land exposed under SLR scenarios
# Data:   Derived from bathtub flood model on bias-corrected DEM
#         0.0m → 0.0% | 1.0m → 4.5% | 1.5m → 8.5%
#
# Output: output/05_supporting/funafuti_exposure_bar.png
#         7 × 5 in · 320 dpi
#
# Placement in QMD: after the three-map scroll, not a fourth sticky.
# The scroll shows WHERE land is exposed. This chart shows HOW MUCH.
#
# Author:  Steven Ponce
# Session: 6 — May 25, 2026
# =============================================================================


# -----------------------------------------------------------------------------
# 0. Libraries
# -----------------------------------------------------------------------------
library(ggplot2)
library(ggtext)
library(showtext)
library(here)


# -----------------------------------------------------------------------------
# 1. Typography — matches 03_visual_language_refinement.R exactly
# -----------------------------------------------------------------------------
font_add_google("Big Shoulders",         family = "big_shoulders")
font_add_google("DM Sans",               family = "dm_sans")
font_add_google("JetBrains Mono",        family = "jetbrains_mono")
showtext_auto()
showtext_opts(dpi = 320)


# -----------------------------------------------------------------------------
# 2. Pacific Currents palette — locked in Session 2
#    Using `clrs` (not `colors`) to avoid grDevices::colors() collision
# -----------------------------------------------------------------------------
clrs <- list(
  abyss  = "#07142F",   # page + chart background
  tide   = "#102447",   # panel background
  reef   = "#4FE0CC",   # teal — accent, annotation
  coral  = "#FF7A59",   # flood signal — 1.0m and 1.5m bars
  sand   = "#F2EDE2",   # body text
  mist   = "#6E83AB",   # captions, muted labels
  land   = "#4A5E35",   # dry land olive — 0.0m bar
  hair   = "#2A4A87"    # hairline borders
)

# Scalar extraction — safe inside aes() and annotate()
col_abyss  <- clrs$abyss
col_tide   <- clrs$tide
col_reef   <- clrs$reef
col_coral  <- clrs$coral
col_sand   <- clrs$sand
col_mist   <- clrs$mist
col_land   <- clrs$land
col_hair   <- clrs$hair


# -----------------------------------------------------------------------------
# 3. Data — derived from 02_threshold_derivation.R output
#    These are the locked numbers from the bias-corrected bathtub model.
#    When SPC official data arrives: re-run 02_ and update these three values.
# -----------------------------------------------------------------------------
exposure_data <- data.frame(
  scenario    = factor(
    c("+0.0m", "+1.0m", "+1.5m"),
    levels = c("+0.0m", "+1.0m", "+1.5m")   # left → right: rising scenario
  ),
  exposed_pct = c(0.0, 4.5, 8.5),
  bar_color   = c(col_land, col_coral, col_coral),  # olive baseline, coral threshold bars
  bar_alpha   = c(0.7, 0.75, 1.0)                  # 1.5m bar is fullest intensity
)

# Scalar anchors for annotations — hardcoded after first render (chart-eval rule)
y_10m  <- 4.5
y_15m  <- 8.5
y_mid  <- (y_10m + y_15m) / 2   # 6.5 — midpoint (reference)
x_bar2 <- 2                      # numeric position of +1.0m bar
x_bar3 <- 3                      # numeric position of +1.5m bar


# -----------------------------------------------------------------------------
# 4. Theme — Pacific Currents dark, consistent with map outputs
# -----------------------------------------------------------------------------
theme_pacific_bar <- function() {
  theme_minimal(base_family = "dm_sans") +
    theme(
      # Canvas
      plot.background  = element_rect(fill = col_abyss, color = NA),
      panel.background = element_rect(fill = col_tide,  color = NA),
      panel.border     = element_blank(),
      
      # Grid — horizontal only, very faint
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(
        color     = col_hair,
        linewidth = 0.3,
        linetype  = "solid"
      ),
      
      # Axes
      axis.text.x  = element_text(
        family = "jetbrains_mono",
        color  = col_sand,
        size   = 11,
        margin = margin(t = 6)
      ),
      axis.text.y  = element_text(
        family = "jetbrains_mono",
        color  = col_mist,
        size   = 9
      ),
      axis.title.x = element_blank(),
      axis.title.y = element_text(
        family = "dm_sans",
        color  = col_mist,
        size   = 9,
        margin = margin(r = 8)
      ),
      axis.ticks   = element_blank(),
      
      # Titles
      plot.title = element_text(
        family  = "big_shoulders",
        color   = col_sand,
        size    = 20,
        face    = "bold",
        margin  = margin(b = 6)
      ),
      plot.subtitle = element_markdown(           # ggtext — enables inline color
        family    = "dm_sans",
        color     = col_mist,
        size      = 10,
        lineheight = 1.4,
        margin    = margin(b = 18)
      ),
      plot.caption = element_text(
        family    = "jetbrains_mono",
        color     = col_mist,
        size      = 7,
        hjust     = 0,
        lineheight = 1.3,
        margin    = margin(t = 14)
      ),
      
      # Margins
      plot.margin = margin(t = 20, r = 48, b = 16, l = 16)
    )
}


# -----------------------------------------------------------------------------
# 5. Build chart
# -----------------------------------------------------------------------------

# Subtitle: inline coral color on the threshold finding — matches scroll pattern
subtitle_text <- paste0(
  "Modeled share of Funafuti land exposed under sea-level rise scenarios<br>",
  "<span style='color:", col_coral, "'>At 1.5m, exposure is nearly double the 1.0m value</span>"
)

# Caption — two lines to prevent right-edge clipping (same fix as maps)
caption_text <- paste0(
  "Derived from bias-corrected SRTM/GLO-30 DEM · Bathtub inundation model · Canopy bias: −1.8m\n",
  "Not an official flood model · Open pipeline · See methodology for assumptions"
)

chart <- ggplot(
  data    = exposure_data,
  mapping = aes(x = scenario, y = exposed_pct)
) +
  
  # --- Bars ---
  geom_col(
    aes(fill = scenario, alpha = bar_alpha),
    width = 0.52,
    show.legend = FALSE
  ) +
  scale_fill_manual(
    values = c(
      "+0.0m" = col_land,
      "+1.0m" = col_coral,
      "+1.5m" = col_coral
    )
  ) +
  scale_alpha_identity() +
  
  # --- Y axis ---
  scale_y_continuous(
    limits = c(0, 12),                          # headroom for bracket + label above
    breaks = c(0, 2, 4, 6, 8, 10),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0))
  ) +
  
  # --- Data labels on bars ---
  # 0.0m: show "0.0%" in mist (not coral — it's the baseline, not the signal)
  geom_text(
    data    = exposure_data[exposure_data$scenario == "+0.0m", ],
    mapping = aes(label = "0.0%", y = 0.4),
    family  = "jetbrains_mono",
    color   = col_mist,
    size    = 3.5,
    vjust   = 0
  ) +
  # 1.0m and 1.5m: coral percentage labels above bars
  geom_text(
    data    = exposure_data[exposure_data$scenario != "+0.0m", ],
    mapping = aes(
      label = paste0(exposed_pct, "%"),
      y     = exposed_pct + 0.35
    ),
    family  = "jetbrains_mono",
    color   = col_coral,
    size    = 4,
    vjust   = 0,
    fontface = "bold"
  ) +
  
  # --- Bracket: "nearly doubles" label sits ABOVE the two coral bars ---
  # Horizontal span line between bar 2 top and bar 3 top
  annotate(
    "segment",
    x = x_bar2, xend = x_bar3,
    y = y_15m + 0.6, yend = y_15m + 0.6,
    color     = col_reef,
    linewidth = 0.5
  ) +
  # Left tick down to bar 2 top
  annotate(
    "segment",
    x = x_bar2, xend = x_bar2,
    y = y_10m,  yend = y_15m + 0.6,
    color     = col_reef,
    linewidth = 0.5
  ) +
  # Right tick down to bar 3 top
  annotate(
    "segment",
    x = x_bar3, xend = x_bar3,
    y = y_15m,  yend = y_15m + 0.6,
    color     = col_reef,
    linewidth = 0.5
  ) +
  # Label centered above the span line
  annotate(
    "text",
    x      = (x_bar2 + x_bar3) / 2,
    y      = y_15m + 1.0,
    label  = "nearly doubles",
    family = "dm_sans",
    color  = col_reef,
    size   = 3.4,
    hjust  = 0.5,
    fontface = "italic"
  ) +
  
  # --- Labels and theme ---
  labs(
    title    = "A Half-Degree of Warming, Twice the Exposure",
    subtitle = subtitle_text,
    y        = "Share of land exposed (%)",
    caption  = caption_text
  ) +
  coord_cartesian(clip = "off") +       # labels and bracket can extend beyond panel
  theme_pacific_bar()


# -----------------------------------------------------------------------------
# 6. Save
# -----------------------------------------------------------------------------
output_dir <- here::here("output", "05_supporting")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

ggsave(
  filename = file.path(output_dir, "funafuti_exposure_bar.png"),
  plot     = chart,
  width    = 7,
  height   = 5,
  dpi      = 320,
  bg       = col_abyss
)

message("✓ funafuti_exposure_bar.png written to output/05_supporting/")


# -----------------------------------------------------------------------------
# 7. QMD placement note (not executed — reference only)
# -----------------------------------------------------------------------------
# After the .cr-section closing ::: in 04_closeread_prototype.qmd,
# add the chart as a static figure in the methodology section or
# as a standalone section between scroll and methodology:
#
# ## The Numbers Behind the Maps
#
# ```{r}
# #| echo: false
# #| out-width: "100%"
# knitr::include_graphics("output/05_supporting/funafuti_exposure_bar.png")
# ```
#
# Or as raw markdown image (simpler, no R chunk needed):
# ![](output/05_supporting/funafuti_exposure_bar.png)
#
# Suggested caption prose (place below image in QMD):
# "The bathtub model that generated the maps above also yields a direct
#  exposure estimate. The jump from 1.0m to 1.5m — the gap between a
#  1°C and a 1.5°C warming trajectory — nearly doubles the share of
#  Funafuti land at flood risk."
# =============================================================================