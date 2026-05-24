# =============================================================================
# 01_funafuti_data_check.R
# Pacific Dataviz Challenge 2026 — Tuvalu SLR Scenario
# 
# PURPOSE: Answer the four spatial questions before any styling.
#   Q1. Can we get usable elevation data?
#   Q2. Does Funafuti render cleanly?
#   Q3. Are the elevation values plausible?
#   Q4. Does the 30m DEM create unacceptable artifacts?
#
# PACKAGES: terra, sf, ggplot2, elevatr, tidyterra, dplyr, tidyr, progress
# RUN FROM: project root (pacific-dataviz-2026/)
# OUTPUT:   diagnostic plots saved to output/01_checks/
#           dem_raw.tif + workspace.RData for use by 01b_bias_correction.R
# =============================================================================

library(terra)
library(sf)
library(ggplot2)
library(elevatr)
library(tidyterra)
library(dplyr)
library(tidyr)
library(progress)

# Output directory
dir.create("output/01_checks", recursive = TRUE, showWarnings = FALSE)

cat("\n=== 01_funafuti_data_check.R ===\n")

# -----------------------------------------------------------------------------
# STEP 1 — Define Funafuti bounding box
# -----------------------------------------------------------------------------

cat("\n[1/4] Defining bounding box...\n")

bbox_vals <- c(
  xmin = 179.05,
  ymin = -8.68,
  xmax = 179.28,
  ymax = -8.38
)

bbox_sf <- st_bbox(bbox_vals, crs = st_crs(4326)) |> st_as_sfc() |> st_as_sf()

cat("  Bounding box:", paste(round(bbox_vals, 3), collapse = ", "), "\n")
cat("  Width (approx):",
    round((bbox_vals["xmax"] - bbox_vals["xmin"]) * 111 * cos(-8.5 * pi/180), 1), "km\n")
cat("  Height (approx):",
    round((bbox_vals["ymax"] - bbox_vals["ymin"]) * 111, 1), "km\n")

# OSM skipped for now (Overpass rate limits)
# Will be added in a dedicated OSM script once rate limit clears
coast_lines <- NULL
buildings   <- NULL

# -----------------------------------------------------------------------------
# STEP 2 — Download elevation data via elevatr
# -----------------------------------------------------------------------------

cat("\n[2/4] Downloading DEM (z=12, ~39m resolution)...\n")

dem_raw <- tryCatch({
  get_elev_raster(
    locations = bbox_sf,
    z         = 12,
    src       = "aws",
    clip      = "bbox"
  )
}, error = function(e) {
  cat("  ERROR:", conditionMessage(e), "\n")
  NULL
})

if (is.null(dem_raw)) {
  stop("DEM download failed. Check internet connection and elevatr installation.")
}

dem <- rast(dem_raw)
cat("  DEM downloaded successfully.\n")
cat("  Resolution:", paste(round(res(dem) * 111000, 0), collapse = " x "), "meters (approx)\n")
cat("  Dimensions:", nrow(dem), "rows x", ncol(dem), "cols\n")

elev_vals <- values(dem, na.rm = TRUE)
cat("\n  --- Elevation diagnostics ---\n")
cat("  Min elevation:", round(min(elev_vals), 2), "m\n")
cat("  Max elevation:", round(max(elev_vals), 2), "m\n")
cat("  Mean elevation:", round(mean(elev_vals), 2), "m\n")
cat("  Median elevation:", round(median(elev_vals), 2), "m\n")
cat("  % pixels <= 0m:", round(mean(elev_vals <= 0) * 100, 1), "%\n")
cat("  % pixels <= 1m:", round(mean(elev_vals <= 1) * 100, 1), "%\n")
cat("  % pixels <= 2m:", round(mean(elev_vals <= 2) * 100, 1), "%\n")
cat("  % pixels <= 3m:", round(mean(elev_vals <= 3) * 100, 1), "%\n")

# -----------------------------------------------------------------------------
# STEP 3 — Derive flood extents (bathtub model)
# -----------------------------------------------------------------------------

cat("\n[3/4] Deriving flood extents...\n")

slr_thresholds <- c(0.0, 0.5, 1.0, 1.5)

flood_extents <- lapply(slr_thresholds, function(slr) {
  flooded   <- ifel(dem > 0 & dem <= slr, 1, NA)
  n_flooded <- global(flooded, "sum", na.rm = TRUE)$sum
  pct       <- round(n_flooded / sum(!is.na(values(dem))) * 100, 1)
  cat("  SLR", sprintf("%.1fm", slr), "->",
      formatC(n_flooded, format = "f", digits = 0), "flooded pixels",
      sprintf("(%.1f%% of land area)\n", pct))
  list(slr = slr, raster = flooded, n_flooded = n_flooded, pct_flooded = pct)
})
names(flood_extents) <- paste0("slr_", gsub("\\.", "", as.character(slr_thresholds)))

# -----------------------------------------------------------------------------
# STEP 4 — Diagnostic plots
# -----------------------------------------------------------------------------

cat("\n[4/4] Generating diagnostic plots...\n")

# --- Plot A: Raw DEM ---
cat("  Plot A: Raw DEM...\n")

dem_land <- ifel(dem > 0, dem, NA)

p_dem <- ggplot() +
  geom_spatraster(data = dem_land) +
  scale_fill_viridis_c(
    name     = "Elevation (m)",
    na.value = "#c9e8f5",
    limits   = c(0, 5),
    oob      = scales::squish
  ) +
  coord_sf(
    xlim = c(bbox_vals["xmin"], bbox_vals["xmax"]),
    ylim = c(bbox_vals["ymin"], bbox_vals["ymax"])
  ) +
  labs(
    title    = "Funafuti Atoll — Raw DEM (elevatr z=12)",
    subtitle = "Elevation in meters | Ocean masked",
    caption  = "Data: AWS terrain tiles (GLO-30 derived) via elevatr"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "right")

ggsave("output/01_checks/A_raw_dem.png", p_dem, width = 8, height = 7, dpi = 150)
cat("  Saved: output/01_checks/A_raw_dem.png\n")

# --- Plot B: Elevation histogram ---
cat("  Plot B: Elevation histogram...\n")

land_vals <- data.frame(elevation = elev_vals[elev_vals > 0])

p_hist <- ggplot(land_vals, aes(x = elevation)) +
  geom_histogram(binwidth = 0.25, fill = "#4FE0CC", color = "white", linewidth = 0.2) +
  geom_vline(xintercept = c(0.5, 1.0, 1.5),
             color      = c("#FF7A59", "#FF4444", "#CC0000"),
             linetype   = "dashed", linewidth = 0.8) +
  annotate("text", x = c(0.5, 1.0, 1.5) + 0.05, y = Inf,
           label = c("SLR 0.5m", "SLR 1.0m", "SLR 1.5m"),
           color = c("#FF7A59", "#FF4444", "#CC0000"),
           hjust = 0, vjust = 1.5, size = 3) +
  scale_x_continuous(limits = c(0, 8), breaks = 0:8) +
  labs(
    title    = "Funafuti Land Elevation Distribution",
    subtitle = "Histogram of land pixel elevations (pixels > 0m) | Dashed lines = SLR thresholds",
    x        = "Elevation (m)",
    y        = "Number of pixels",
    caption  = "Source: AWS terrain tiles (GLO-30 derived) via elevatr"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))

ggsave("output/01_checks/B_elevation_histogram.png", p_hist,
       width = 9, height = 5, dpi = 150)
cat("  Saved: output/01_checks/B_elevation_histogram.png\n")

# --- Plot C: Four-panel flood comparison ---
cat("  Plot C: Four-panel flood comparison...\n")

make_scenario_raster <- function(dem, slr) {
  ifel(dem <= 0, 0, ifel(dem <= slr, 2, 1))
}

scenario_list <- lapply(slr_thresholds, function(slr) {
  r <- make_scenario_raster(dem, slr)
  names(r) <- paste0("SLR ", sprintf("%.1f", slr), "m")
  r
})
scenario_stack <- rast(scenario_list)

scenario_df <- as.data.frame(scenario_stack, xy = TRUE) |>
  pivot_longer(cols = -c(x, y), names_to = "scenario", values_to = "type") |>
  mutate(
    type     = factor(type, levels = c(0, 1, 2),
                      labels = c("Ocean", "Dry land", "Flooded")),
    scenario = factor(scenario,
                      levels = paste0("SLR ", sprintf("%.1f", slr_thresholds), "m"))
  )

p_comparison <- ggplot(scenario_df |> filter(!is.na(type))) +
  geom_raster(aes(x = x, y = y, fill = type)) +
  scale_fill_manual(
    values = c("Ocean" = "#c9e8f5", "Dry land" = "#8B9E6E", "Flooded" = "#FF7A59"),
    name   = NULL
  ) +
  facet_wrap(~scenario, nrow = 1) +
  coord_equal(
    xlim = c(bbox_vals["xmin"], bbox_vals["xmax"]),
    ylim = c(bbox_vals["ymin"], bbox_vals["ymax"])
  ) +
  labs(
    title    = "Funafuti Atoll — Bathtub Inundation Model",
    subtitle = "Orange = land exposed to flooding | Green = dry land | Blue = ocean",
    caption  = paste0(
      "Methodology: threshold-based bathtub model applied to GLO-30 DEM (via elevatr)\n",
      "Funafuti as focal case — not an official flood forecast"
    )
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title       = element_text(face = "bold"),
    legend.position  = "bottom",
    axis.text        = element_text(size = 7),
    strip.text       = element_text(face = "bold", size = 9),
    panel.spacing    = unit(0.5, "lines")
  )

ggsave("output/01_checks/C_flood_comparison.png", p_comparison,
       width = 14, height = 5, dpi = 150)
cat("  Saved: output/01_checks/C_flood_comparison.png\n")

# -----------------------------------------------------------------------------
# SAVE — terra object via writeRaster, everything else via save()
# NOTE: terra SpatRasters must NOT go into save()/load() — C++ pointers
#       do not survive serialization. Always use writeRaster() + rast().
# -----------------------------------------------------------------------------

cat("\nSaving outputs...\n")

writeRaster(dem, "output/01_checks/dem_raw.tif", overwrite = TRUE)
cat("  Saved: output/01_checks/dem_raw.tif\n")

save(flood_extents, coast_lines, buildings, bbox_vals, slr_thresholds,
     file = "output/01_checks/workspace.RData")
cat("  Saved: output/01_checks/workspace.RData\n")

cat("\n=== DONE — proceed to 01b_bias_correction.R ===\n\n")
