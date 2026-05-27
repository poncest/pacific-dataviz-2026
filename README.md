# Funafuti — The Tuvalu Threshold

<p align="left">
  <img src="img/logo-white-base.png" alt="Pacific Dataviz Challenge logo" height="44">
</p>

**Pacific Dataviz Challenge 2026 · Climate Change**

> *"For Tuvalu, the difference between 1°C and 1.5°C of warming is not a number — it is the island."*

**Status:** Submission in progress · Compliance pass complete (v0.7.1) · Awaiting June 1 official dataset list
**Live URL:** Coming soon — June 2026
**Repo:** [github.com/poncest/pacific-dataviz-2026](https://github.com/poncest/pacific-dataviz-2026)

> **Not an official flood forecast.** This piece is a reproducible exposure-threshold analysis for the Pacific Dataviz Challenge. It is not a flood prediction, and it is not affiliated with the Pacific Community (SPC) or any government agency.

---

## Preview

![Funafuti at +1.5m sea-level rise — 8.5% of land at flood exposure](output/03_branded/funafuti_branded_15.png)

*Funafuti Atoll at +1.5m sea-level rise. The connecting strips between motu begin to fragment; exposed land nearly doubles relative to the +1.0m scenario.*

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

The scenarios are illustrative thresholds, not precise projections for specific warming levels. The relationship between global mean temperature and sea-level rise is nonlinear and scenario-dependent; the 1.0m and 1.5m scenarios are used here as illustrative thresholds. See the [methodology](04_closeread_prototype.qmd) section of the piece for full disclosures.

---

## Data sources

- **Elevation:** Copernicus GLO-30 Digital Elevation Model (TanDEM-X derived), accessed via the `elevatr` R package and AWS Terrain Tiles
- **Coastline:** OpenStreetMap contributors, accessed via Geofabrik regional extracts through `osmextract`. Released under the Open Database License (ODbL)
- **Flood scenarios:** Derived in this work — bathtub inundation model applied to the bias-corrected DEM at three thresholds (0.0m, 1.0m, 1.5m SLR)
- **Bias correction:** −1.8m uniform canopy offset applied to all land pixels (radar DEMs overestimate elevation due to vegetation return; correction is uniform and approximate)
- **Display note:** Flood pixels dilated one grid cell outward for visual legibility; subtitle percentages reflect the methodologically correct threshold without this expansion

**Elevation references:**
- Yamano, H., Cabioch, G., Chevillon, C., & Join, J. L. (2007). *Late Holocene sea-level change and reef-island evolution in New Caledonia*. Geomorphology.
- Tuck, M. E., Kench, P. S., Ford, M. R., & Masselink, G. (2019). *Physical modelling of the response of reef islands to sea-level rise*. Geology.

### Pacific Dataviz Challenge — official dataset requirement

The challenge rules require that at least one dataset from the official Pacific Data Hub list (published June 1, 2026) be used in the submission. As of repo creation, the official 2026 list has not yet been published. Five candidate SPC datasets covering Tuvalu coastal flood scenarios have been identified for integration once the official list publishes:

- Coastal flood maps Tuvalu ARI100 SLR 0.0 / 1.0 / 1.5
- Building impact from coastal inundation on Tuvalu
- Annual Average Loss for Tuvalu

The current open pipeline (elevatr + OSM) is the development baseline. At least one official SPC dataset will be integrated before submission to meet the rules requirement.

---

## Stack

| Tool | Role |
|------|------|
| R · terra · sf · elevatr · osmextract | Spatial pipeline |
| ggplot2 · ggtext · tidyterra | Map rendering |
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
# scripts/05_supporting_chart.R

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

## Licence

This work — text, code, derived data, and visualisations — is released under the [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) licence. You are free to share and adapt the work with attribution to Steven Ponce.

The full licence text is in [`LICENSE`](LICENSE).

This licence is conformant with the [Open Definition](https://opendefinition.org/) as required by the Pacific Dataviz Challenge rules (§4h).

**Note on OpenStreetMap data:** OSM data used in the rendering pipeline is licensed under the Open Database License (ODbL) and remains so. The CC BY 4.0 licence above applies to the derived visualisations, code, and analysis — not to any republished OSM-derived geometry. No OSM-derived geometry is currently published as a derivative dataset in this repository.

---

## Author

**Steven Ponce** · Data Analyst & R/Shiny Developer

[LinkedIn](https://www.linkedin.com/in/stevenponce/) ·
[Bluesky](https://bsky.app/profile/sponce1.bsky.social) ·
[GitHub](https://github.com/poncest) ·
[stevenponce.netlify.app](https://stevenponce.netlify.app)

---

*Pacific Dataviz Challenge 2026 · Theme: Climate Change · Submission window: June 1 – August 31, 2026*
