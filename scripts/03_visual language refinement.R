# =============================================================================
# 03_visual_language_refinement.R
# Pacific Dataviz Challenge 2026 — Tuvalu SLR Scenario
#
# PURPOSE: First branded render. Test the Pacific Currents visual system
#          on the actual map geometry.
#
# QUESTIONS THIS RENDER ANSWERS:
#   - Do motu strips survive on a dark background?
#   - Does the lagoon read as distinct from open ocean on dark?
#   - Does coral (#FF7A59) flood register against olive land on abyss?
#   - Does the geography feel fragile, exposed, serious?
#   - Does the three-act structure (0.0 / 1.0 / 1.5m) hold emotionally?
#
# OUTPUTS:
#   output/03_branded/funafuti_branded_00.png
#   output/03_branded/funafuti_branded_10.png
#   output/03_branded/funafuti_branded_15.png
#
# DESIGN DECISIONS (this script):
#   - Option A: dark everything — abyss background, dark ocean, coral flood
#   - Three scenarios only: 0.0m, 1.0m, 1.5m
#   - osmextract coastline attempted; DEM-only fallback
#   - Minimal annotation (title + SLR label only) — typography test only
#   - Artifact cleaning: minimum patch filter, lightest touch possible
#   - No inset, no Closeread, no full annotation system yet
#
# DISPLAY PARAMETERS (v4):
#   - min_pixels raised to 8: kills the stray isolated western land pixel
#     that was too small to be real atoll geometry at 19m resolution
#   - focal() dilation (1-cell outward expansion) replaces threshold buffer:
#     flood pixels expand into adjacent ocean cells, creating a wash that
#     reads as inundation approaching from the sea — both visually correct
#     and physically intuitive. NOT applied to 0.0m baseline.
#   - render_flood_buffer removed: superseded by dilation approach
#
# CHANGES FROM v3:
#   1. min_pixels: 4 → 8 (removes stray western pixel cluster)
#   2. focal() dilation replaces render_flood_buffer threshold expansion
#   3. render_flood_buffer parameter removed from render_branded()
#   4. Flood patch cleaning (min_flood_patch_pixels) retained
#   5. Caption updated: "flood extent dilated 1 cell" instead of "+0.15m"
#   6. Flood % still computed from exact methodological threshold (no dilation)
#
# LIMITATION NOTE (carried from 01b):
#   GLO-30 DEM + uniform -1.8m canopy bias correction. Flood extents
#   represent low-elevation coastal fringe exposure. Not an official
#   flood forecast. Replace via 00_official_data_prep.R when SPC data
#   arrives (June 2026).
# =============================================================================

library(terra)
library(sf)
library(ggplot2)
library(tidyterra)
library(dplyr)
library(showtext)
library(ggtext)

dir.create("output/03_branded", recursive = TRUE, showWarnings = FALSE)

cat("\n=== 03_visual_language_refinement.R ===\n")

# -----------------------------------------------------------------------------
# STEP 1 — Load data
# -----------------------------------------------------------------------------

cat("\n[1/5] Loading data...\n")

# Load terra object first, then workspace, then reload terra object.
# Reason: load() overwrites the dem_corrected name with a broken C++ pointer
# from the .RData file. The second rast() call restores the live object.
dem_corrected <- rast("output/01_checks/dem_corrected.tif")
load("output/01_checks/workspace.RData")
dem_corrected <- rast("output/01_checks/dem_corrected.tif")  # overwrite broken pointer

# Guards for workspace objects used downstream.
if (!exists("BIAS_CORRECTION")) {
  BIAS_CORRECTION <- -1.8
  cat("  WARNING: BIAS_CORRECTION not in workspace — using default:", BIAS_CORRECTION, "\n")
}
if (!exists("bbox_vals")) {
  bbox_vals <- as.vector(ext(dem_corrected))
  names(bbox_vals) <- c("xmin", "xmax", "ymin", "ymax")
  cat("  WARNING: bbox_vals not in workspace — derived from DEM extent\n")
  cat("  bbox:", paste(round(bbox_vals, 4), collapse = ", "), "\n")
}

slr_scenarios   <- c(0.0, 1.0, 1.5)
scenario_names  <- c("00", "10", "15")
scenario_labels <- c("0.0m", "1.0m", "1.5m")

# Render bbox: expand DEM extent by padding so the atoll appears
# zoomed out within the canvas. This prevents the bottom of the
# southern chain from being cropped in the browser sticky column.
# Adjust render_pad_lat to taste (larger = more ocean, smaller atoll).
render_pad_lat  <- 0.08   # degrees latitude padding top and bottom
render_pad_lon  <- 0.04   # degrees longitude padding left and right
bbox_render <- bbox_vals
bbox_render["ymin"] <- bbox_vals["ymin"] - render_pad_lat
bbox_render["ymax"] <- bbox_vals["ymax"] + render_pad_lat
bbox_render["xmin"] <- bbox_vals["xmin"] - render_pad_lon
bbox_render["xmax"] <- bbox_vals["xmax"] + render_pad_lon

cat("  DEM loaded:", nrow(dem_corrected), "x", ncol(dem_corrected), "pixels\n")
cat("  Bias correction applied:", BIAS_CORRECTION, "m\n")
cat("  Scenarios: 0.0m, 1.0m, 1.5m (three-act structure)\n")

# -----------------------------------------------------------------------------
# STEP 2 — Pacific Currents visual system
# -----------------------------------------------------------------------------

cat("\n[2/5] Loading Pacific Currents visual system...\n")

pal <- list(
  abyss  = "#07142F",   # page + map background
  tide   = "#102447",   # lagoon (interior water — slightly lighter than abyss)
  ocean  = "#0A1C3D",   # open ocean (between abyss and tide)
  reef   = "#4FE0CC",   # primary accent (teal) — axis text, minor labels
  coral  = "#FF7A59",   # flood / threshold — the emotional signal
  sun    = "#FFC857",   # milestone / highlight (reserved for annotation)
  sand   = "#F2EDE2",   # body text / land label
  mist   = "#6E83AB",   # muted text / caption
  land   = "#4A5E35",   # dry land (darker olive — reads on abyss)
  hair   = "#2A4A87"    # hairline borders / grid
)

# Display parameter — flood patch cleaning only
# render_flood_buffer removed in v4 (superseded by focal dilation)
min_flood_patch_pixels <- 2   # minimum contiguous flood pixels to retain

cat("  min_flood_patch_pixels:", min_flood_patch_pixels, "\n")
cat("  flood dilation: 1-cell focal expansion (SLR > 0 panels only)\n")

# Fonts — load from local files
font_dir <- here::here("fonts")

if (dir.exists(font_dir)) {
  font_add(
    family  = "big_shoulders",
    regular = file.path(font_dir, "BigShoulders-VariableFont_opsz,wght.ttf")
  )
  font_add(
    family  = "dm_sans",
    regular = file.path(font_dir, "DMSans-VariableFont_opsz,wght.ttf"),
    italic  = file.path(font_dir, "DMSans-Italic-VariableFont_opsz,wght.ttf")
  )
  font_add(
    family  = "jetbrains_mono",
    regular = file.path(font_dir, "JetBrainsMono-VariableFont_wght.ttf")
  )
  showtext_auto()
  showtext_opts(dpi = 320)
  fonts_loaded <- TRUE
  cat("  Fonts loaded from:", font_dir, "\n")
} else {
  cat("  Font directory not found:", font_dir, "\n")
  cat("  Proceeding with system fonts (brand test will be approximate)\n")
  fonts_loaded <- FALSE
}

title_font <- if (fonts_loaded) "big_shoulders" else "sans"
body_font  <- if (fonts_loaded) "dm_sans"        else "sans"
mono_font  <- if (fonts_loaded) "jetbrains_mono" else "mono"

# -----------------------------------------------------------------------------
# STEP 3 — Coastline acquisition
# Primary: osmextract (reproducible, no rate limits)
# Fallback: DEM-only render (no coastline overlay)
# -----------------------------------------------------------------------------

cat("\n[3/5] Acquiring coastline...\n")

coast_sf <- NULL

use_osmextract <- requireNamespace("osmextract", quietly = TRUE)

if (use_osmextract) {
  cat("  osmextract available. Attempting Tuvalu coastline download...\n")
  cat("  (First run downloads ~1MB PBF and caches locally)\n")
  
  coast_sf <- tryCatch({
    suppressMessages({
      tuvalu_lines <- osmextract::oe_get(
        "Tuvalu",
        layer              = "lines",
        query              = "SELECT * FROM lines WHERE natural = 'coastline'",
        quiet              = TRUE,
        download_directory = "data/osm_cache"
      )
    })
    
    if (!is.null(tuvalu_lines) && nrow(tuvalu_lines) > 0) {
      bbox_poly <- st_bbox(
        c(xmin = bbox_vals["xmin"], ymin = bbox_vals["ymin"],
          xmax = bbox_vals["xmax"], ymax = bbox_vals["ymax"]),
        crs = st_crs(4326)
      ) |> st_as_sfc()
      
      clipped <- st_intersection(tuvalu_lines, bbox_poly)
      
      cat("  osmextract: SUCCESS\n")
      cat("  Coastline features (clipped):", nrow(clipped), "\n")
      total_pts <- sum(sapply(st_geometry(clipped),
                              function(g) nrow(st_coordinates(g))))
      cat("  Total coordinate points:", total_pts, "\n")
      clipped
    } else {
      cat("  osmextract returned no features.\n")
      NULL
    }
  }, error = function(e) {
    cat("  osmextract FAILED:", conditionMessage(e), "\n")
    NULL
  })
} else {
  cat("  osmextract not installed.\n")
  cat("  Install with: install.packages('osmextract')\n")
}

if (is.null(coast_sf)) {
  cat("  Falling back to DEM-only render (no coastline overlay)\n")
}

osm_available <- !is.null(coast_sf)

# -----------------------------------------------------------------------------
# STEP 4 — Geometry cleaning
# Remove artifact patches: minimum area filter on land pixels
# Lightest touch — preserve narrow strips and micro-islets
# The fragility of geometry IS the story
#
# v4 change: min_pixels raised from 4 to 8
# Reason: the isolated western pixel cluster (~4-6 pixels) that appeared in
# open ocean in v2/v3 renders is too small to be real atoll geometry at 19m
# resolution. Raising to 8 removes it cleanly without touching any real motu
# (all visible islets are well above this threshold).
# -----------------------------------------------------------------------------

cat("\n[4/5] Cleaning geometry artifacts...\n")

# Pixel area in m² (approximate at Funafuti latitude)
pixel_res_m   <- mean(res(dem_corrected)) * 111000 * cos(-8.5 * pi / 180)
pixel_area_m2 <- pixel_res_m^2
cat("  Pixel size (approx):", round(pixel_res_m, 1), "m |",
    round(pixel_area_m2), "m²\n")

# Minimum patch: 8 pixels (~3000 m² at 19m resolution)
# Removes isolated noise clusters that survived the 4-pixel filter.
# Do NOT raise further without visual verification of motu strip retention.
min_pixels <- 8
cat("  Minimum land patch size:", min_pixels, "pixels (~",
    round(min_pixels * pixel_area_m2), "m²)\n")

land_mask_clean <- ifel(dem_corrected > 0, 1, NA)
land_clumps     <- patches(land_mask_clean, directions = 8)
clump_freq      <- freq(land_clumps)
keep_clumps     <- clump_freq$value[clump_freq$count >= min_pixels]
land_clean      <- ifel(land_clumps %in% keep_clumps, land_mask_clean, NA)

n_removed <- nrow(clump_freq) - length(keep_clumps)
cat("  Land patches removed (< ", min_pixels, " pixels):", n_removed, "\n")
cat("  Land patches retained:", length(keep_clumps), "\n")
cat("  (Verify: all visible motus and narrow strips should be retained)\n")

# Remove western open-ocean artifact outside the main atoll ring.
# The Funafuti atoll ring begins ~179.07°E; any land pixel west of this
# is open ocean noise that survived the patch filter because the cluster
# is large enough (≥ 8 pixels) to be real sub-islet geometry at this
# resolution, but sits far enough west to be outside the story frame.
# terra::init() produces a raster of x-coordinates (longitudes) matching
# land_clean extent and resolution — no coordinate extraction needed.
atoll_west_limit <- 179.07
x_coord    <- terra::init(land_clean, "x")
land_clean <- terra::ifel(x_coord < atoll_west_limit, NA, land_clean)
cat("  Western longitude mask applied: pixels west of",
    atoll_west_limit, "°E removed\n")

# Apply cleaned land mask to DEM
dem_clean <- ifel(!is.na(land_clean), dem_corrected, NA)

# -----------------------------------------------------------------------------
# STEP 5 — Render three branded maps
# -----------------------------------------------------------------------------

cat("\n[5/5] Rendering branded maps...\n")

theme_pacific_map <- function() {
  theme_void() +
    theme(
      plot.background  = element_rect(fill = pal$abyss, color = NA),
      panel.background = element_rect(fill = pal$abyss, color = NA),
      plot.title = element_text(
        family = title_font, face = "bold",
        size = 28, color = "white",
        margin = margin(t = 16, b = 4, l = 16)
      ),
      plot.subtitle = element_markdown(
        family = mono_font,
        size = 11, color = pal$reef,
        margin = margin(b = 8, l = 16)
      ),
      plot.caption = element_text(
        family = mono_font,
        size = 6, color = pal$mist,
        hjust = 0,
        margin = margin(t = 8, b = 12, l = 16, r = 32)
      ),
      legend.position = "none",
      plot.margin     = margin(8, 16, 8, 8)
    )
}

render_branded <- function(slr, name, label, dem_clean, coast_sf, bbox,
                           min_flood_pixels) {
  
  # --- Flood % for subtitle (exact methodological threshold — no dilation) ---
  # Computed before any display processing so the subtitle reflects the
  # actual SLR scenario, not the visual expansion.
  scenario_pct     <- ifel(is.na(dem_clean), 0,
                           ifel(dem_clean <= slr, 2, 1))
  df_pct           <- as.data.frame(scenario_pct, xy = FALSE)
  names(df_pct)[1] <- "type"
  n_land    <- sum(df_pct$type == 1, na.rm = TRUE)
  n_flooded <- sum(df_pct$type == 2, na.rm = TRUE)
  n_total   <- n_land + n_flooded
  pct       <- if (n_total > 0) round(n_flooded / n_total * 100, 1) else 0
  
  # --- Base scenario raster (exact threshold) --------------------------------
  # 0 = ocean/NA, 1 = dry land, 2 = flooded
  scenario_r <- ifel(is.na(dem_clean), 0,
                     ifel(dem_clean <= slr, 2,
                          1))
  
  # --- Flood dilation: expand flood pixels 1 cell outward into ocean ---------
  # Applied only when slr > 0 (baseline must show zero flooding).
  #
  # Why dilation rather than threshold expansion (v3 approach):
  #   The threshold buffer (slr + 0.15m) floods more interior land pixels,
  #   which on a narrow atoll just consumes the land interior — the coral
  #   band stays at the perimeter and still reads as a stroke.
  #   Dilation expands flood pixels outward into adjacent ocean cells,
  #   creating a visible wash on the seaward side. This reads as inundation
  #   approaching from the ocean, which is the physically correct narrative.
  #
  # focal(w=3, fun="max"): 3x3 kernel, any cell adjacent to flood → flood.
  # The result is painted onto ocean cells only (scenario_r == 0) so land
  # pixels are never overwritten — olive interior is preserved.
  if (slr > 0) {
    flood_only    <- ifel(scenario_r == 2, 1, NA)
    flood_dilated <- focal(flood_only, w = 3, fun = "max", na.rm = TRUE)
    # Expand into ocean (0) only — do not touch dry land (1)
    scenario_r    <- ifel(!is.na(flood_dilated) & scenario_r == 0,
                          2, scenario_r)
    cat("    Flood dilation applied (1-cell outward into ocean)\n")
  }
  
  # --- Remove isolated flood pixels -----------------------------------------
  # After dilation, some ocean-side cells may be isolated (e.g., the stray
  # western pixel acquires a single-cell dilated ring). Patch filter removes
  # these before they reach the renderer.
  # Demoted to ocean (0), not dry land (1) — these are ocean-side cells.
  if (slr > 0) {
    flood_mask  <- ifel(scenario_r == 2, 1, NA)
    flood_clump <- patches(flood_mask, directions = 8)
    flood_freq  <- freq(flood_clump)
    keep_flood  <- flood_freq$value[flood_freq$count >= min_flood_pixels]
    scenario_r  <- ifel(scenario_r == 2 & !(flood_clump %in% keep_flood),
                        0, scenario_r)   # demote to ocean, not land
    n_flood_removed <- nrow(flood_freq) - length(keep_flood)
    cat("    Isolated flood patches removed:", n_flood_removed, "\n")
  }
  
  # --- Build plot dataframe --------------------------------------------------
  df <- as.data.frame(scenario_r, xy = TRUE) |>
    rename(type = 3) |>
    mutate(type = factor(type,
                         levels = c(0, 1, 2),
                         labels = c("Ocean", "Dry land", "Flooded")))
  
  # --- Subtitle and caption --------------------------------------------------
  # Subtitle: two lines to prevent right-edge clipping.
  # Line 1: scenario label
  # Line 2: finding with percentage highlighted in coral via ggtext markdown
  # \n ignored by element_markdown — use <br> for line breaks
  subtitle_text <- if (pct == 0) {
    paste0("SLR +", label, "<br>Baseline \u2014 no additional inundation")
  } else {
    paste0(
      "SLR +", label, "<br>",
      if (slr <= 1.0) "The margins are failing \u2014 "
      else            "Fragmentation begins \u2014 ",
      '<span style="color:#FF7A59">', pct, '% of land now exposed</span>'
    )
  }
  
  # Caption split across two lines to prevent right-edge clipping.
  # Line 1: data source + model type
  # Line 2: disclaimer (+ dilation note on flooded panels)
  caption_base <- paste0(
    "GLO-30 DEM + ", BIAS_CORRECTION, "m canopy bias correction  |  Bathtub threshold model\n",
    "Not an official flood forecast"
  )
  caption_text <- if (slr > 0) {
    paste0(
      "GLO-30 DEM + ", BIAS_CORRECTION, "m canopy bias correction  |  Bathtub threshold model\n",
      "Not an official flood forecast  |  Flood extent dilated 1 cell for visual legibility"
    )
  } else {
    caption_base
  }
  
  # --- Plot ------------------------------------------------------------------
  # Render order: ocean → flood → land
  # Flood layer sits between ocean and land so dilation reads as a seaward
  # wash rather than a land-side fringe. Land painted last preserves the
  # olive interior on all motus.
  df_ocean <- df |> filter(type == "Ocean")
  df_flood <- df |> filter(type == "Flooded")
  df_land  <- df |> filter(type == "Dry land")
  
  p <- ggplot() +
    geom_raster(data = df_ocean, aes(x = x, y = y), fill = pal$ocean) +
    geom_raster(data = df_flood, aes(x = x, y = y), fill = pal$coral) +
    geom_raster(data = df_land,  aes(x = x, y = y), fill = pal$land)
  
  if (!is.null(coast_sf)) {
    p <- p + geom_sf(
      data        = coast_sf,
      color       = pal$reef,
      linewidth   = 0.25,
      inherit.aes = FALSE
    )
  }
  
  p <- p +
    coord_sf(
      xlim   = c(bbox["xmin"], bbox["xmax"]),
      ylim   = c(bbox["ymin"], bbox["ymax"]),
      expand = FALSE
    ) +
    labs(
      title    = "Funafuti Atoll",
      subtitle = subtitle_text,
      caption  = caption_text
    ) +
    theme_pacific_map()
  
  cat("  SLR", label,
      "| method:", slr, "m",
      "| display: 1-cell dilation",
      "|", pct, "% flooded\n")
  p
}

# Render and save all three scenarios
for (i in seq_along(slr_scenarios)) {
  slr   <- slr_scenarios[i]
  name  <- scenario_names[i]
  label <- scenario_labels[i]
  
  cat("  Rendering funafuti_branded_", name, ".png...\n", sep = "")
  
  p <- render_branded(
    slr              = slr,
    name             = name,
    label            = label,
    dem_clean        = dem_clean,
    coast_sf         = coast_sf,
    bbox             = bbox_render,
    min_flood_pixels = min_flood_patch_pixels
  )
  
  outfile <- file.path("output/03_branded",
                       paste0("funafuti_branded_", name, ".png"))
  ggsave(outfile, p, width = 7, height = 7, dpi = 320, bg = pal$abyss)
  cat("  Saved:", outfile, "\n")
}

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------

cat("\n=== VISUAL REVIEW CHECKLIST ===\n")
cat("\nOpen each PNG in output/03_branded/ and assess:\n\n")

cat("GEOMETRY:\n")
cat("  [ ] Ring structure legible on dark background?\n")
cat("  [ ] Narrow motu strips survive (olive interior preserved)?\n")
cat("  [ ] No stray coral pixels in open ocean?\n")
cat("  [ ] No stray olive pixels west of the atoll ring?\n")

cat("\nCOLOR / FLOOD:\n")
cat("  [ ] 0.0m baseline — zero coral visible anywhere?\n")
cat("  [ ] 1.0m — coral reads as seaward wash, not perimeter stroke?\n")
cat("  [ ] 1.5m — coral band visibly wider than 1.0m on all motus?\n")
cat("  [ ] Olive land interior survives on all motus (land on top)?\n")
cat("  [ ] Lagoon interior reads as distinct water zone?\n")

cat("\nNARRATIVE (three-act test):\n")
cat("  [ ] 0.0m: 'this is what exists'\n")
cat("  [ ] 1.0m: 'something is changing'\n")
cat("  [ ] 1.5m: 'something is failing'\n")
cat("  [ ] Progression emotionally distinct across all three?\n")

cat("\nTYPOGRAPHY:\n")
cat("  [ ] Caption not clipped on right edge?\n")
cat("  [ ] Dilation note legible in caption on flooded panels?\n")

cat("\n--- IF ISSUES REMAIN ---\n")
cat("Stray western pixel still present: raise min_pixels to 12\n")
cat("Motu strips lost (olive gone):     dilation too aggressive — reduce focal w to 1\n")
cat("                                   (w=1 means no dilation; try w=2 custom kernel)\n")
cat("Coral wash too faint:              dilation correct but color needs boost — try #FF6040\n")
cat("Coral wash too aggressive:         reduce min_flood_pixels from 2 to 1 to keep\n")
cat("                                   smaller patches, or check focal kernel size\n")

cat("\nIf all checks pass: proceed to 04_closeread_prototype.qmd\n")

cat("\n=== DONE ===\n\n")