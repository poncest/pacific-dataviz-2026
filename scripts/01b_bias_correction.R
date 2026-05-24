# =============================================================================
# 01b_bias_correction.R
# Pacific Dataviz Challenge 2026 — Tuvalu SLR Scenario
#
# PURPOSE: Correct vegetation canopy bias in GLO-30 DEM for Funafuti.
#
# PROBLEM: SRTM-derived DEMs measure the top of vegetation canopy, not bare
# ground. On Funafuti, coconut palms and structures inflate land elevations
# by ~2-3m. This suppresses the bathtub flood signal.
#
# FIX: Apply a uniform vertical offset to land pixels, calibrated to
# published ground-truth elevations for Fongafale islet.
#
# PUBLISHED REFERENCE ELEVATIONS (Funafuti / Fongafale):
#   Yamano et al. (2007): mean land elevation ~1.0m above MSL
#   Tuck et al. (2019): modal elevation 1.0-1.5m, max ~3m
#   Donner & Webber (2014): highest point ~3m, mean ~1.2m
#
# OUTPUT: output/01_checks/dem_corrected.tif  <- canonical DEM for all
#         subsequent scripts (02, 03, 04)
# NOTE:   When official SPC data arrives, replace dem_corrected.tif via
#         00_official_data_prep.R — everything downstream is unchanged.
# =============================================================================

library(terra)
library(ggplot2)
library(tidyr)
library(dplyr)
library(tidyterra)

cat("\n=== 01b_bias_correction.R ===\n")

# -----------------------------------------------------------------------------
# STEP 1 — Load data
# NOTE: terra SpatRasters must NOT go into save()/load() — C++ pointers do
# not survive serialization. Always reload with rast() from the .tif file.
# -----------------------------------------------------------------------------

cat("\n[1/4] Loading workspace...\n")

dem <- rast("output/01_checks/dem_raw.tif")
load("output/01_checks/workspace.RData")
dem <- rast("output/01_checks/dem_raw.tif")  # overwrite broken terra object from workspace

cat("  Loaded: dem, flood_extents, bbox_vals, slr_thresholds\n")

land_mask     <- dem > 0
land_vals_raw <- values(dem)[values(land_mask) == 1]
land_vals_raw <- land_vals_raw[!is.na(land_vals_raw)]

cat("  Uncorrected land elevation — median:", round(median(land_vals_raw), 2),
    "m | max:", round(max(land_vals_raw), 2), "m\n")

# -----------------------------------------------------------------------------
# STEP 2 — Apply bias correction
# Applies ONLY to land pixels (dem > 0). Ocean bathymetry unchanged.
# After correction, clamp any over-corrected land pixels to 0 minimum.
# -----------------------------------------------------------------------------

cat("\n[2/4] Applying canopy bias correction...\n")

BIAS_CORRECTION <- -1.8   # meters — central estimate
BIAS_LOW        <- -1.5   # conservative
BIAS_HIGH       <- -2.1   # aggressive

dem_corrected <- ifel(dem > 0, dem + BIAS_CORRECTION, dem)
dem_corrected <- ifel(dem > 0 & dem_corrected < 0, 0, dem_corrected)

land_vals_corr <- values(dem_corrected)[values(land_mask) == 1]
land_vals_corr <- land_vals_corr[!is.na(land_vals_corr)]

cat("  Correction applied:", BIAS_CORRECTION, "m to land pixels\n")
cat("  Corrected land elevation — median:", round(median(land_vals_corr), 2),
    "m | max:", round(max(land_vals_corr), 2), "m\n")
cat("  % land pixels <= 0.5m:", round(mean(land_vals_corr <= 0.5) * 100, 1), "%\n")
cat("  % land pixels <= 1.0m:", round(mean(land_vals_corr <= 1.0) * 100, 1), "%\n")
cat("  % land pixels <= 1.5m:", round(mean(land_vals_corr <= 1.5) * 100, 1), "%\n")
cat("  % land pixels <= 2.0m:", round(mean(land_vals_corr <= 2.0) * 100, 1), "%\n")

pct_15 <- round(mean(land_vals_corr <= 1.5) * 100, 1)
cat("\n  PLAUSIBILITY: % land <= 1.5m =", pct_15, "%\n")
if (pct_15 >= 40 && pct_15 <= 80) {
  cat("  OK — within expected range (40-80%). Correction well-calibrated.\n")
} else if (pct_15 < 40) {
  cat("  WARNING — lower than expected. Consider BIAS_CORRECTION <- -2.1\n")
} else {
  cat("  WARNING — higher than expected. Consider BIAS_CORRECTION <- -1.5\n")
}

# -----------------------------------------------------------------------------
# STEP 3 — Re-derive flood extents with corrected DEM
# -----------------------------------------------------------------------------

cat("\n[3/4] Re-deriving flood extents with corrected DEM...\n")

n_land <- sum(values(land_mask) == 1, na.rm = TRUE)

flood_extents_corrected <- lapply(slr_thresholds, function(slr) {
  flooded   <- ifel(dem_corrected > 0 & dem_corrected <= slr, 1, NA)
  n_flooded <- global(flooded, "sum", na.rm = TRUE)$sum
  pct       <- round(n_flooded / n_land * 100, 1)
  cat("  SLR", sprintf("%.1fm", slr), "->",
      formatC(n_flooded, format = "f", digits = 0), "flooded pixels",
      sprintf("(%.1f%% of land area)\n", pct))
  list(slr = slr, raster = flooded, n_flooded = n_flooded, pct_flooded = pct)
})
names(flood_extents_corrected) <-
  paste0("slr_", gsub("\\.", "", as.character(slr_thresholds)))

# -----------------------------------------------------------------------------
# STEP 4 — Diagnostic plots
# Plot D: Before/after histogram
# Plot E: Corrected four-panel flood comparison
# Plot F: Sensitivity check across three correction magnitudes
# -----------------------------------------------------------------------------

cat("\n[4/4] Generating diagnostic plots...\n")

# --- Plot D: Before/after histogram ---
cat("  Plot D: Before/after elevation histogram...\n")

hist_df <- bind_rows(
  data.frame(elevation = land_vals_raw,  version = "Uncorrected (raw GLO-30)"),
  data.frame(elevation = land_vals_corr, version = paste0("Corrected (", BIAS_CORRECTION, "m offset)"))
) |>
  filter(elevation >= 0, elevation <= 8)


corr_label <- paste0("Corrected (", BIAS_CORRECTION, "m offset)")

p_hist_comparison <- ggplot(hist_df, aes(x = elevation, fill = version)) +
  geom_histogram(binwidth = 0.25, position = "identity", alpha = 0.65,
                 color = "white", linewidth = 0.2) +
  geom_vline(xintercept = c(0.5, 1.0, 1.5),
             linetype = "dashed", linewidth = 0.8,
             color = c("#FF9966", "#FF4444", "#CC0000")) +
  annotate("text", x = c(0.5, 1.0, 1.5) + 0.06, y = Inf,
           label = c("SLR 0.5m", "SLR 1.0m", "SLR 1.5m"),
           color = c("#FF9966", "#FF4444", "#CC0000"),
           hjust = 0, vjust = 1.5, size = 3) +
  scale_fill_manual(values = c(
    "Uncorrected (raw GLO-30)" = "#B0B0B0",
    setNames("#4FE0CC", corr_label)
  )) +
  scale_x_continuous(limits = c(0, 8), breaks = 0:8) +
  labs(
    title    = "Funafuti Elevation Distribution — Before vs After Bias Correction",
    subtitle = paste0(
      "Gray = raw GLO-30 (canopy-inflated) | Teal = corrected (",
      BIAS_CORRECTION, "m offset) | Published mean land elevation ~1.0-1.2m"
    ),
    x = "Elevation (m)", y = "Number of pixels", fill = NULL,
    caption = "Calibrated to Yamano et al. (2007), Tuck et al. (2019)."
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "bottom")

ggsave("output/01_checks/D_bias_correction_histogram.png", p_hist_comparison,
       width = 10, height = 5.5, dpi = 150)
cat("  Saved: output/01_checks/D_bias_correction_histogram.png\n")

# --- Plot E: Corrected four-panel flood comparison ---
cat("  Plot E: Corrected flood comparison...\n")

make_scenario_raster <- function(dem, slr) {
  ifel(dem <= 0, 0, ifel(dem <= slr, 2, 1))
}

scenario_list_corr <- lapply(slr_thresholds, function(slr) {
  r <- make_scenario_raster(dem_corrected, slr)
  names(r) <- paste0("SLR ", sprintf("%.1f", slr), "m")
  r
})
scenario_stack_corr <- rast(scenario_list_corr)

pct_labels <- sapply(flood_extents_corrected, function(x) x$pct_flooded)
facet_labels <- setNames(
  paste0("SLR ", sprintf("%.1f", slr_thresholds), "m\n(", pct_labels, "% flooded)"),
  paste0("SLR ", sprintf("%.1f", slr_thresholds), "m")
)

scenario_df_corr <- as.data.frame(scenario_stack_corr, xy = TRUE) |>
  pivot_longer(cols = -c(x, y), names_to = "scenario", values_to = "type") |>
  mutate(
    type = factor(type, levels = c(0, 1, 2),
                  labels = c("Ocean", "Dry land", "Flooded")),
    scenario = factor(scenario,
                      levels = paste0("SLR ", sprintf("%.1f", slr_thresholds), "m")),
    scenario_label = factor(facet_labels[as.character(scenario)],
                            levels = facet_labels)
  )

p_flood_corrected <- ggplot(scenario_df_corr |> filter(!is.na(type))) +
  geom_raster(aes(x = x, y = y, fill = type)) +
  scale_fill_manual(
    values = c("Ocean" = "#c9e8f5", "Dry land" = "#8B9E6E", "Flooded" = "#FF7A59"),
    name   = NULL
  ) +
  facet_wrap(~scenario_label, nrow = 1) +
  coord_equal(
    xlim = c(bbox_vals["xmin"], bbox_vals["xmax"]),
    ylim = c(bbox_vals["ymin"], bbox_vals["ymax"])
  ) +
  labs(
    title    = "Funafuti Atoll — Corrected Bathtub Inundation Model",
    subtitle = paste0("After ", BIAS_CORRECTION, "m canopy bias correction | % of land area shown in panel headers"),
    caption  = paste0(
      "Methodology: GLO-30 DEM corrected for vegetation canopy bias (", BIAS_CORRECTION, "m). ",
      "Bathtub threshold model.\nFunafuti focal case only — not an official flood forecast."
    )
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title      = element_text(face = "bold"),
    legend.position = "bottom",
    axis.text       = element_text(size = 7),
    strip.text      = element_text(face = "bold", size = 9),
    panel.spacing   = unit(0.5, "lines")
  )

ggsave("output/01_checks/E_flood_corrected.png", p_flood_corrected,
       width = 14, height = 5.5, dpi = 150)
cat("  Saved: output/01_checks/E_flood_corrected.png\n")

# --- Plot F: Sensitivity check ---
cat("  Plot F: Correction sensitivity check...\n")

sensitivity_offsets <- c(BIAS_LOW, BIAS_CORRECTION, BIAS_HIGH)
sensitivity_labels  <- c(
  paste0("Conservative (", BIAS_LOW, "m)"),
  paste0("Central (", BIAS_CORRECTION, "m)"),
  paste0("Aggressive (", BIAS_HIGH, "m)")
)

sensitivity_df <- lapply(seq_along(sensitivity_offsets), function(i) {
  offset <- sensitivity_offsets[i]
  dem_s  <- ifel(dem > 0, dem + offset, dem)
  dem_s  <- ifel(dem > 0 & dem_s < 0, 0, dem_s)
  vals   <- values(dem_s)[values(land_mask) == 1]
  vals   <- vals[!is.na(vals) & vals >= 0 & vals <= 8]
  data.frame(elevation = vals, correction = sensitivity_labels[i])
}) |>
  bind_rows() |>
  mutate(correction = factor(correction, levels = sensitivity_labels))

p_sensitivity <- ggplot(sensitivity_df, aes(x = elevation, fill = correction)) +
  geom_histogram(binwidth = 0.25, position = "identity", alpha = 0.55,
                 color = "white", linewidth = 0.2) +
  geom_vline(xintercept = c(0.5, 1.0, 1.5),
             linetype = "dashed", color = "#CC4444", linewidth = 0.7) +
  annotate("rect", xmin = 1.0, xmax = 1.5, ymin = 0, ymax = Inf,
           alpha = 0.08, fill = "#4FE0CC") +
  annotate("text", x = 1.25, y = Inf, label = "Published\nmean range",
           vjust = 1.5, size = 2.8, color = "#2A9E8A") +
  scale_fill_manual(values = c("#B0B0B0", "#4FE0CC", "#FF7A59")) +
  scale_x_continuous(limits = c(0, 7), breaks = 0:7) +
  facet_wrap(~correction, nrow = 1) +
  labs(
    title    = "Sensitivity Check — Three Bias Correction Magnitudes",
    subtitle = "Shaded band = published mean land elevation range (1.0-1.5m) | Dashed = SLR thresholds",
    x = "Elevation (m)", y = "Number of pixels", fill = "Correction"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title      = element_text(face = "bold"),
    legend.position = "none",
    strip.text      = element_text(face = "bold")
  )

ggsave("output/01_checks/F_sensitivity_check.png", p_sensitivity,
       width = 12, height = 5, dpi = 150)
cat("  Saved: output/01_checks/F_sensitivity_check.png\n")

# -----------------------------------------------------------------------------
# SAVE — corrected DEM is the canonical input for all downstream scripts
# -----------------------------------------------------------------------------

cat("\nSaving outputs...\n")

writeRaster(dem_corrected, "output/01_checks/dem_corrected.tif", overwrite = TRUE)
cat("  Saved: output/01_checks/dem_corrected.tif\n")
cat("  <- Canonical DEM input for 02_visual_proof.R onwards\n")
cat("  <- When official SPC data arrives, replace via 00_official_data_prep.R\n")

save(flood_extents, flood_extents_corrected, coast_lines, buildings,
     bbox_vals, slr_thresholds, BIAS_CORRECTION,
     file = "output/01_checks/workspace.RData")
cat("  Saved: output/01_checks/workspace.RData\n")

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------

cat("\n=== BIAS CORRECTION SUMMARY ===\n")
cat("Correction applied:", BIAS_CORRECTION, "m to all land pixels\n\n")
cat("Flood coverage after correction:\n")
for (key in names(flood_extents_corrected)) {
  x <- flood_extents_corrected[[key]]
  cat("  SLR", sprintf("%.1f", x$slr), "m ->",
      sprintf("%.1f%%", x$pct_flooded), "of land area flooded\n")
}

cat("\nCheck plots D, E, F in output/01_checks/\n")
cat("If Plot E shows progressive, physically plausible flood spread:\n")
cat("  -> Proceed to 02_visual_proof.R\n")
cat("If coverage still looks too low: increase BIAS_CORRECTION (e.g. -2.1)\n")
cat("If coverage looks too aggressive: reduce BIAS_CORRECTION (e.g. -1.5)\n")

cat("\n=== DONE ===\n\n")
