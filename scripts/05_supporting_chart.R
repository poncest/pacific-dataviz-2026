# =============================================================================
# 05_supporting_chart.R  ·  v2
# Pacific Dataviz Challenge 2026 — Supporting Chart
#
# Chart: "A Half-Degree of Warming, Twice the Exposure"  (Direction A — slope)
#        Subtitle: "Exposed land area by sea-level scenario"
# Metric: Modeled share of Funafuti land exposed under SLR scenarios
# Data:   Derived from bathtub flood model on bias-corrected DEM
#         0.0m → 0.0% | 1.0m → 4.5% | 1.5m → 8.5%
#
# v2 change (Session 9): replaces the v1 vertical-bar chart with a slope.
#   The bars treated the three scenarios as co-equal categories. The slope
#   makes the 1.0m → 1.5m segment the story: muted line into the first point,
#   bold coral into the last. "The jump that matters" carries the argument.
#   B-style human-stakes (homes/people) is the post-June-1 upgrade, not here.
#
# Output: output/05_supporting/funafuti_exposure_slope.png
#         7 × 5 in · 320 dpi
#         (renamed from funafuti_exposure_bar.png — update the image line in
#          04_closeread_prototype.qmd; see section 7 note below.)
#
# Placement in QMD: after the three-map scroll, not a fourth sticky.
# The scroll shows WHERE land is exposed. This chart shows HOW MUCH.
#
# Author:  Steven Ponce
# Session: 9 — May 30, 2026  (v2 — Direction A slope, replaces v1 bar)
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
  coral  = "#FF7A59",   # flood signal — the 1.0m → 1.5m jump
  sand   = "#F2EDE2",   # body text
  mist   = "#6E83AB",   # captions, muted labels, baseline
  land   = "#4A5E35",   # dry land olive (unused in slope; kept for parity)
  hair   = "#2A4A87"    # hairline borders / grid
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
y_00  <- 0.0
y_10m <- 4.5
y_15m <- 8.5

# x = numeric positions so a line can connect the scenarios left → right.
# pt_color / pt_size drive per-point identity aesthetics (no legend).
exposure_data <- data.frame(
  scenario_label = c("+0.0m", "+1.0m", "+1.5m"),
  x              = c(1, 2, 3),
  exposed_pct    = c(y_00, y_10m, y_15m),
  pt_color       = c(col_mist, col_sand, col_coral),
  pt_size        = c(2.5, 4.5, 6.0)   # baseline recedes; endpoint carries the emphasis
)

# Two segments so the jump can carry its own weight.
seg_context <- data.frame(x = 1, xend = 2, y = y_00,  yend = y_10m)  # muted
seg_jump    <- data.frame(x = 2, xend = 3, y = y_10m, yend = y_15m)  # coral

# Annotation anchors — first-pass values; nudge after first render
# (chart-eval rule: lock coordinates once, by eye, after seeing the plot).
# The slope leaves the upper-LEFT empty; the callout lives there, and both
# lines sit ABOVE the data max (8.5) so they never cross the line.
ann_x  <- 0.92    # left edge of callout block (data x)
ann_y1 <- 9.8     # callout headline
ann_y2 <- 8.9     # callout subnote

# Callout wording — DECIDED (Session 9): "jump" over "threshold". The line
# visually jumps, the exposure jumps, it reads conversationally, and it avoids
# a fourth "threshold" (already in the piece title, standfirst, and scroll).
callout_head <- "The jump that matters"        # rejected alt: "The threshold that matters"
callout_sub  <- "+1.0m \u2192 +1.5m nearly doubles land exposure"


# -----------------------------------------------------------------------------
# 4. Theme — Pacific Currents dark, consistent with map outputs
# -----------------------------------------------------------------------------
theme_pacific_slope <- function() {
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
        color     = alpha(col_hair, 0.25),   # softened — editorial, not analytical
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
      axis.title.y = element_blank(),       # dropped — subtitle + "%" ticks + direct labels carry it
      axis.ticks   = element_blank(),
      
      # Titles
      plot.title = element_text(
        family  = "big_shoulders",
        color   = col_sand,
        size    = 20,
        face    = "bold",
        margin  = margin(b = 6)
      ),
      plot.subtitle = element_markdown(          # ggtext — parity with map outputs
        family     = "dm_sans",
        color      = col_mist,
        size       = 10,
        lineheight = 1.4,
        margin     = margin(b = 18)
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
      plot.margin = margin(t = 20, r = 26, b = 16, l = 16)
    )
}


# -----------------------------------------------------------------------------
# 5. Build chart — Direction A: slope emphasising the 1.0m → 1.5m jump
# -----------------------------------------------------------------------------

# Caption — two lines to prevent right-edge clipping (same fix as maps)
caption_text <- paste0(
  "Derived from bias-corrected SRTM/GLO-30 DEM \u00b7 Bathtub inundation model \u00b7 Canopy bias: \u22121.8m\n",
  "Not an official flood model \u00b7 Open pipeline \u00b7 See methodology for assumptions"
)

chart <- ggplot() +
  
  # --- the two slope segments ---
  # baseline → 1.0m : context (muted, thin)
  geom_segment(
    data    = seg_context,
    mapping = aes(x = x, y = y, xend = xend, yend = yend),
    color     = col_mist,
    linewidth = 0.9
  ) +
  # 1.0m → 1.5m : the story (coral, thick, round caps)
  geom_segment(
    data    = seg_jump,
    mapping = aes(x = x, y = y, xend = xend, yend = yend),
    color     = col_coral,
    linewidth = 2.4,
    lineend   = "round"
  ) +
  
  # --- points (per-row identity color + size) ---
  geom_point(
    data    = exposure_data,
    mapping = aes(x = x, y = exposed_pct, color = pt_color, size = pt_size)
  ) +
  scale_color_identity() +
  scale_size_identity() +
  
  # --- value labels: baseline mist, 1.0m sand, 1.5m coral (bold) ---
  annotate("text", x = 1, y = y_00  + 0.55, label = "0.0%",
           family = "jetbrains_mono", color = col_mist, size = 3.5, vjust = 0) +
  annotate("text", x = 2, y = y_10m + 0.60, label = "4.5%",
           family = "jetbrains_mono", color = col_sand, size = 3.7, vjust = 0) +
  annotate("text", x = 3, y = y_15m + 0.65, label = "8.5%",
           family = "jetbrains_mono", color = col_coral, size = 4.4,
           fontface = "bold", vjust = 0) +
  
  # --- callout block (upper-left empty space) ---
  # Line 1: the argument, in coral (links to the coral segment)
  annotate("text", x = ann_x, y = ann_y1, label = callout_head,
           family = "dm_sans", color = col_coral, size = 4.2,
           fontface = "bold", hjust = 0) +
  # Line 2: the subnote, in sand
  annotate("text", x = ann_x, y = ann_y2, label = callout_sub,
           family = "dm_sans", color = col_sand, size = 3.2, hjust = 0) +
  
  # --- scales ---
  scale_x_continuous(
    breaks = c(1, 2, 3),
    labels = c("+0.0m", "+1.0m", "+1.5m"),
    expand = expansion(mult = c(0.10, 0.10))
  ) +
  scale_y_continuous(
    breaks = c(0, 2, 4, 6, 8, 10),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0))
  ) +
  coord_cartesian(ylim = c(0, 10.8), clip = "off") +   # headroom for callout
  
  # --- labels and theme ---
  labs(
    title    = "A Half-Degree of Warming, Twice the Exposure",
    subtitle = "Exposed land area by sea-level scenario",
    caption  = caption_text
  ) +
  theme_pacific_slope()


# -----------------------------------------------------------------------------
# 6. Save
# -----------------------------------------------------------------------------
output_dir <- here::here("output", "05_supporting")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

ggsave(
  filename = file.path(output_dir, "funafuti_exposure_slope.png"),
  plot     = chart,
  width    = 7,
  height   = 5,
  dpi      = 320,
  bg       = col_abyss
)

message("\u2713 funafuti_exposure_slope.png written to output/05_supporting/")


# -----------------------------------------------------------------------------
# 7. QMD placement note (not executed — reference only)
# -----------------------------------------------------------------------------
# In 04_closeread_prototype.qmd, the "Numbers Behind the Maps" section currently
# references the v1 bar PNG. Update the single image line:
#
#   FROM: ![](output/05_supporting/funafuti_exposure_bar.png)
#   TO:   ![](output/05_supporting/funafuti_exposure_slope.png)
#
# The surrounding prose ("The jump from 1.0m to 1.5m ... nearly doubles the
# share of Funafuti land at flood risk") still holds — no prose change needed.
#
# Or as an R chunk:
#
# ```{r}
# #| echo: false
# #| out-width: "100%"
# knitr::include_graphics("output/05_supporting/funafuti_exposure_slope.png")
# ```
# =============================================================================