# Funafuti — The Tuvalu Threshold

**Pacific Dataviz Challenge 2026 · Climate Change**

> *"For Tuvalu, the difference between 1°C and 1.5°C of warming is not a number — it is the island."*

---

## The story

Funafuti Atoll, home to most of Tuvalu's population, rises only a few meters above the Pacific Ocean. This scrollytelling piece shows what happens to that geography as sea levels rise — not as an abstract number, but as a visual argument about land that exists, land whose margins are dissolving, and land whose connectors between islands begin to fail.

Three scroll states. One place. One threshold.

---

## What this shows

| Scenario | Land at flood exposure |
|----------|----------------------|
| Baseline (0.0m SLR) | 0% |
| +1.0m sea-level rise | 4.5% |
| +1.5m sea-level rise | 8.5% |

The difference between the 1.0m and 1.5m scenarios is roughly comparable to the difference between 1°C and 1.5°C of global warming.

---

## Data

- **Elevation:** Copernicus GLO-30 Digital Elevation Model, accessed via `elevatr`
- **Bias correction:** −1.8m uniform canopy offset applied to all land pixels (radar DEMs overestimate elevation due to vegetation return)
- **Coastline:** OpenStreetMap via `osmextract`
- **Flood extents:** Bathtub threshold model — three scenarios (0.0m / 1.0m / 1.5m)
- **Display:** Flood pixels dilated one grid cell outward for visual legibility; subtitle percentages reflect the methodologically correct threshold

**Not an official flood forecast.** Official flood exposure data from the Pacific Community (SPC) may supersede this open pipeline when released (June 2026).

---

## Stack

| Tool | Role |
|------|------|
| R · terra · sf · elevatr | Spatial pipeline |
| ggplot2 · tidyterra | Map rendering |
| showtext | Typography |
| Quarto · Closeread v1.0.1 | Scrollytelling |
| CSS | Pacific Currents visual system |

---

## Reproduce

```bash
# 1. Clone the repo
git clone https://github.com/poncest/pacific-dataviz-2026.git
cd pacific-dataviz-2026

# 2. Run the spatial pipeline (in R, in order)
# scripts/01_funafuti_data_check.R
# scripts/01b_bias_correction.R
# scripts/02_threshold_derivation.R
# scripts/03_visual_language_refinement.R

# 3. Render the scrollytelling piece
quarto render 04_closeread_prototype.qmd
```

**Note:** Fonts load from Google Fonts — no local font files required.
**Note:** `_extensions/qmd-lab/closeread/` is included in the repo — no separate install needed.

---

## Visual system

**Pacific Currents** — a dark visual language built for this piece.

| Role | Color |
|------|-------|
| Page background | `#07142F` abyss |
| Dry land | `#4A5E35` dark olive |
| Flood exposure | `#FF7A59` coral |
| Accent / labels | `#4FE0CC` reef teal |
| Body text | `#F2EDE2` sand |

---

## Author

**Steven Ponce** · Data Analyst & R/Shiny Developer

[LinkedIn](https://www.linkedin.com/in/stevenponce/) ·
[Bluesky](https://bsky.app/profile/sponce1.bsky.social) ·
[GitHub](https://github.com/poncest) ·
[stevenponce.netlify.app](https://stevenponce.netlify.app)

---

*Pacific Dataviz Challenge 2026 · Submission in progress · Open pipeline*
