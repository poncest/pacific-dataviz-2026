# =============================================================================
# 02_threshold_derivation.R
# Pacific Dataviz Challenge 2026 — Tuvalu SLR Scenario
#
# PURPOSE: First real render. Answer one question:
#   "Does this geography emotionally read at all?"
#
# OUTPUTS: Four separate PNGs — one per SLR scenario
#   output/02_renders/funafuti_slr_00.png
#   output/02_renders/funafuti_slr_05.png
#   output/02_renders/funafuti_slr_10.png
#   output/02_renders/funafuti_slr_15.png
#
# DESIGN CONSTRAINTS (this script only):
#   - Full atoll view, no zoom
#   - Minimal styling — no brand palette, no annotation, no inset
#   - OSM coastline attempted; DEM-only fallback if rate-limited
#   - No Closeread, no composite panels
#
# QUESTIONS THIS RENDER ANSWERS:
#   - Does the ring structure read?
#   - Does the lagoon relationship read?
#   - Does the thinness of land read?
#   - Does spatial fragmentation register?
#   - Do inundation patches visually register?
#   - Does GLO-30 resolution collapse the narrow strips?
#
# LIMITATION NOTE (carry forward to all downstream scripts):
#   GLO-30 DEM has vegetation canopy bias (~1-3m inflation on Pacific atolls).
#   A uniform -1.8m correction has been applied, calibrated to published
#   ground-truth elevations (Yamano et al. 2007, Tuck et al. 2019).
#   Flood extents represent low-elevation coastal fringe exposure under
#   each SLR scenario, not wholesale inundation. Results should be read
#   as a reproducible scenario model, not an official flood forecast.
#   When official SPC/NIWA PARTneR 2 data becomes available (June 2026),
#   replace dem_corrected.tif via 00_official_data_prep.R.
# =============================================================================

library(terra)
library(sf)
library(ggplot2)
library(tidyterra)
library(osmdata)
library(dplyr)

dir.create("output/02_renders", recursive = TRUE, showWarnings = FALSE)

cat("\n=== 02_threshold_derivation.R ===\n")

# -----------------------------------------------------------------------------
# STEP 1 — Load corrected DEM and workspace
# -----------------------------------------------------------------------------

cat("\n[1/4] Loading data...\n")

dem_corrected <- rast("output/01_checks/dem_corrected.tif")
load("output/01_checks/workspace.RData")

cat("  DEM loaded:", nrow(dem_corrected), "x", ncol(dem_corrected), "pixels\n")
cat("  Bias correction applied: ", BIAS_CORRECTION, "m\n")

# -----------------------------------------------------------------------------
# STEP 2 — Attempt OSM coastline
# Overpass API rate limits ~1 request per 60s for anonymous users.
# If this fails, DEM-derived land mask is used as fallback.
# -----------------------------------------------------------------------------

cat("\n[2/4] Attempting OSM coastline download...\n")

coast_lines <- tryCatch({
  cat("  Querying Overpass API (may take 30-60s)...\n")
  result <- opq(bbox = c(
    bbox_vals["xmin"], bbox_vals["ymin"],
    bbox_vals["xmax"], bbox_vals["ymax"]
  )) |>
    add_osm_feature(key = "natural", value = "coastline") |>
    osmdata_sf()
  
  lines <- result$osm_lines
  if (!is.null(lines) && nrow(lines) > 0) {
    cat("  OSM coastline: SUCCESS\n")
    cat("  Features:", nrow(lines), "\n")
    cat("  Total points:", sum(sapply(
      st_geometry(lines),
      function(g) nrow(st_coordinates(g))
    )), "\n")
    lines
  } else {
    cat("  OSM returned no lines. Trying polygons...\n")
    polys <- result$osm_polygons
    if (!is.null(polys) && nrow(polys) > 0) {
      cat("  OSM coastline polygons:", nrow(polys), "\n")
      polys
    } else {
      cat("  No coastline features returned.\n")
      NULL
    }
  }
}, error = function(e) {
  cat("  OSM FAILED:", conditionMessage(e), "\n")
  cat("  Proceeding with DEM-only render.\n")
  NULL
})

osm_available <- !is.null(coast_lines)
cat("  OSM coastline available:", osm_available, "\n")

# -----------------------------------------------------------------------------
# STEP 3 — Derive flood scenario rasters
# Three-level raster: 0 = ocean, 1 = dry land, 2 = flooded land
# -----------------------------------------------------------------------------

cat("\n[3/4] Deriving flood scenario rasters...\n")

slr_thresholds <- c(0.0, 0.5, 1.0, 1.5)
scenario_names <- c("slr_00", "slr_05", "slr_10", "slr_15")
scenario_labels <- sprintf("%.1fm", slr_thresholds)

make_scenario_raster <- function(dem, slr) {
  ifel(dem <= 0, 0,           # ocean / below MSL
       ifel(dem <= slr, 2,         # flooded land
            1))                     # dry land
}

scenarios <- lapply(seq_along(slr_thresholds), function(i) {
  slr <- slr_thresholds[i]
  r   <- make_scenario_raster(dem_corrected, slr)
  
  # Count for console
  vals      <- values(r, na.rm = TRUE)
  n_land    <- sum(vals == 1, na.rm = TRUE)
  n_flooded <- sum(vals == 2, na.rm = TRUE)
  n_total   <- n_land + n_flooded
  pct       <- if (n_total > 0) round(n_flooded / n_total * 100, 1) else 0
  
  cat("  SLR", sprintf("%.1fm", slr), "->",
      n_flooded, "flooded pixels /", n_total, "land pixels",
      sprintf("(%.1f%%)\n", pct))
  
  list(
    slr     = slr,
    name    = scenario_names[i],
    label   = scenario_labels[i],
    raster  = r,
    pct     = pct
  )
})

# -----------------------------------------------------------------------------
# STEP 4 — Render four maps
#
# VISUAL APPROACH (minimal, diagnostic):
#   Ocean:      light blue  #c9e8f5
#   Dry land:   olive green #6B7F52  (slightly darker than 01_ for contrast)
#   Flooded:    coral       #FF7A59
#   Background: white
#   No annotation, no title styling, no brand palette yet
#   Coastline overlaid if OSM available
#
# WHAT TO LOOK FOR IN THE OUTPUT:
#   - Ring structure: is the atoll arc legible?
#   - Lagoon: does the interior blue read as water?
#   - Land thinness: do the narrow motu strips survive at this zoom?
#   - Flood patches: do the orange areas register visually?
#   - Runway: ~179.196E, -8.525S — should be a thin strip on Fongafale
# -----------------------------------------------------------------------------

cat("\n[4/4] Rendering four scenario maps...\n")

render_scenario <- function(scenario, osm_lines = NULL, bbox) {
  
  # Convert raster to data frame
  df <- as.data.frame(scenario$raster, xy = TRUE) |>
    rename(type = 3) |>
    mutate(type = factor(type,
                         levels = c(0, 1, 2),
                         labels = c("Ocean", "Dry land", "Flooded")
    )) |>
    filter(!is.na(type))
  
  p <- ggplot(df) +
    geom_raster(aes(x = x, y = y, fill = type)) +
    scale_fill_manual(
      values = c(
        "Ocean"    = "#c9e8f5",
        "Dry land" = "#6B7F52",
        "Flooded"  = "#FF7A59"
      ),
      name = NULL
    )
  
  # Add OSM coastline if available
  if (!is.null(osm_lines)) {
    p <- p + geom_sf(
      data        = osm_lines,
      color       = "#2C3E20",
      linewidth   = 0.35,
      inherit.aes = FALSE
    )
  }
  
  p <- p +
    coord_sf(
      xlim = c(bbox["xmin"], bbox["xmax"]),
      ylim = c(bbox["ymin"], bbox["ymax"]),
      expand = FALSE
    ) +
    labs(
      title    = paste0("Funafuti Atoll — SLR ", scenario$label),
      subtitle = paste0(
        scenario$pct, "% of land area exposed | ",
        if (!is.null(osm_lines)) "OSM coastline" else "DEM-only render"
      ),
      caption = paste0(
        "GLO-30 DEM + ", BIAS_CORRECTION, "m canopy bias correction | ",
        "Bathtub threshold model | Not an official flood forecast"
      ),
      x = NULL, y = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title      = element_text(face = "bold", size = 14),
      plot.subtitle   = element_text(color = "gray40", size = 10),
      plot.caption    = element_text(color = "gray50", size = 8, hjust = 0),
      legend.position = "bottom",
      legend.key.size = unit(0.8, "lines"),
      panel.grid      = element_blank(),
      axis.text       = element_text(size = 8, color = "gray50")
    )
  
  p
}

# Render and save each scenario
for (s in scenarios) {
  cat("  Rendering", s$name, "...\n")
  
  p <- render_scenario(s, osm_lines = coast_lines, bbox = bbox_vals)
  
  outfile <- file.path("output/02_renders", paste0("funafuti_", s$name, ".png"))
  ggsave(outfile, p, width = 7, height = 8, dpi = 200)
  cat("  Saved:", outfile, "\n")
}

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------

cat("\n=== RENDER SUMMARY ===\n")
cat("\nFour maps saved to output/02_renders/\n")
cat("OSM coastline:", if (osm_available) "YES" else "NO (DEM-only)", "\n")
cat("\nFlood coverage by scenario:\n")
for (s in scenarios) {
  cat("  SLR", s$label, "->", s$pct, "% of land area flooded\n")
}

cat("\n--- REVIEW CHECKLIST ---\n")
cat("Open each PNG and assess:\n")
cat("  [ ] Ring structure legible at full-atoll zoom?\n")
cat("  [ ] Lagoon reads as water (blue interior)?\n")
cat("  [ ] Narrow motu strips survive (not collapsed to single pixels)?\n")
cat("  [ ] Flooded patches (orange) visually register?\n")
cat("  [ ] Fongafale islet (NE strip, ~179.19E) recognizable?\n")
cat("  [ ] Southern motus (below -8.55S) preserved?\n")
cat("  [ ] SLR 0.0m looks clean (no spurious orange)?\n")
cat("  [ ] Progression 0.0 -> 0.5 -> 1.0 -> 1.5m visually readable?\n")

cat("\nIf geography reads: proceed to 03_visual_language_refinement.R\n")
cat("If narrow strips collapse: try z=14 DEM in elevatr (re-run 01_)\n")
cat("If flood patches too small to register: document as limitation,\n")
cat("  consider narrative reframe toward coastal fringe exposure\n")

cat("\n=== DONE ===\n\n")