# Biodiversity Loss Impacts of the Brazilian Soy Supply Chain

## Overview
This repository contains the official R implementation and data architecture for estimating the biodiversity loss impacts associated with the international trade of Brazilian soy. Utilizing an **Attributional Life Cycle Assessment (LCA)** framework, the model couples supply chain activity data with spatially explicit characterization factors to quantify biodiversity degradation as a linear function of localized land-use activities.

Due to the massive scale of the geospatial layers and Monte Carlo simulations, the complete project infrastructure encompasses **34.9 GB of data**. To ensure computational transparency and compliance with open science principles, this project follows a decoupled architecture:
* **GitHub Repository (This site):** Hosts the complete core R code, project logical structures (`.Rproj`), and technical documentation.
* **Zenodo Repository (Data Core):** Hosts the heavy structural datasets, including raw input layers, intermediate checkpoints, and final simulation outputs.

---

## Data Availability & Big Data Workflow

To fully replicate the analysis or run the scripts, you must combine the code repository with the heavy data cores hosted on Zenodo. 

### 1. Repository Structure
The project relies on strict relative paths managed via the `here` package. When fully assembled, the root directory must mirror the following structure:

```text
soy-biodiversity-impact-model/
│
├── soy-biodiversity-impact-model.Rproj  # RStudio Project core
├── main_analysis_model.R                # Primary computation script
├── README.md                            # This documentation file
│
├── input_data/                          # Input data folder (from Zenodo)
│   ├── trase_soy_supply_chain.xlsx      # Supply chain matrices
│   ├── land_cover_masks.shp             # Geospatial vector layers
│   └── ... (other input layers)
│
└── output_data/                         # Output data folder (from Zenodo)
    ├── trase_db_imputed_expanded.parquet
    ├── sLULUC_em.parquet                # Final emissions matrix
    └── ... (simulation outputs)
```

### 2. Assembly Instructions
1. **Clone/Download** this GitHub repository to your local machine.
2. Download the data files **`input_data.zip`** and **`output_data.zip`** from our official Zenodo data repository.
3. Extract both zip archives directly into the root directory (`soy-biodiversity-impact-model/`). The extraction will automatically populate the `input_data/` and `output_data/` directories required by the scripts.

---

## Technical Specifications & Environment

### Hardware Requirements
Executing the full computational model involves processing high-resolution raster layers and large-scale data arrays. The local environment **must** meet or exceed the following hardware specs:
* **RAM:** Minimum 32 GB (64 GB recommended for unthrottled parallel processing).
* **Storage:** 50 GB of free solid-state drive (SSD) space.
* **Processor:** Intel i7/i9 or AMD Ryzen 7/9 (Multi-core architecture heavily utilized).

### Software & Core Dependencies
The scripts were built and validated under **R Version 4.x**. The pipeline relies on the following key libraries, each serving a specific role in our Big Data and geospatial framework:

* **`here`**: Manages robust, anchor-based relative file paths. It eliminates the need for absolute hardcoded paths (e.g., `C:/User/...`), ensuring the code runs seamlessly across different machines and operating systems.
* **`tidyverse`**: An opinionated collection of data science packages (including `dplyr`, `tidyr`, and `ggplot2`) used for elegant data manipulation, functional programming pipelines, and structural reshaping of supply chain matrices.
* **`arrow`**: Exposes the C++ Apache Arrow interface to R, enabling ultra-fast reading, writing, and memory-efficient partitioning of multi-gigabyte files in `.parquet` format.
* **`sf` (Simple Features)**: Provides a high-performance framework for handling vector-based geospatial data (such as `.shp` files), allowing spatial intersections and geometric operations on regional boundaries.
* **`terra`**: Designed for advanced raster and vector geospatial analysis. It provides highly optimized C++ methods to read, crop, and compute large-scale satellite imagery grids (like MapBiomas layers) without exhausting RAM.
* **`readxl`**: Allows smooth extraction of data tables directly from Excel files (`.xlsx`), used for importing supplementary supply chain assets and descriptive reference legends.

You can install all dependencies at once by running:
```R
install.packages(c("here", "tidyverse", "arrow", "sf", "terra", "readxl"))
```

---

## Methodological Transparency & Imputation Rules

To combat "black box" modeling concerns and ensure absolute transparency during peer review, the following data curation mechanics are explicitly detailed:

1. **Missing Data Imputation:** Where continuous activity data or regional metrics were missing, values were imputed using robust **weighted averages** conditioned on surrounding geographic strata. For categorical data or factor missingness, **sectorized statistical modes** were deployed to avoid variance distortion.
2. **Third-Party Intellectual Property Handling (e.g., Ecoinvent):** Due to strict proprietary end-user licensing agreements regarding background life cycle inventory data, commercial unit process coefficients could not be distributed openly. To maintain pipeline testability, proprietary metrics within the public datasets have been replaced with a standardized proxy marker (`1`). Users with institutional licenses can swap these proxies back to their raw values within the `input_data/` matrices.

---

## Data Dictionary

### Key Intermediate Attributes
Processed within the geospatial and simulation matrix workflows:
* `municipality_code`: Standardized IBGE jurisdictional code for Brazilian municipalities.
* `year`: Temporal marker for the specific analysis cycle.
* `cov0`: Land cover type categorized exactly 3 years prior to the target study year.
* `cov1`: Land cover type detected during the specific year of analysis.
* `burnt`: Dichotomous indicator evaluating fire incidence (`1` = active burn event, `0` = no fire recorded).
* `npixel`: Total pixel count representing the exact spatial extent inside each cross-category.
* `area`: Aggregated land surface area calculated within each categorical intersection [$km^2$].
* `csoc_md`: Net dynamic change of Soil Organic Carbon (SOC) content tracked between the analysis year and the 3-year baseline.

### Final Emissions Schema (`output_data/sLULUC_em.parquet`)
The primary final output file storing the multi-scenario impacts contains the following attributes:
| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `Id_sample` | Integer | Unique identifier for individual Monte Carlo/simulation iterations. |
| `municipality_code` | Character | IBGE jurisdictional code mapping the spatial origin. |
| `year` | Integer | Year of analysis. |
| `Area_ha` | Numeric | Surface area unit representation [$ha$]. |
| `CO2e_soc` | Numeric | Greenhouse gas emissions originating from changes in Soil Organic Carbon [$kg\ CO_2e$]. |
| `CO2e_bmb` | Numeric | Net $CO_2$ emissions induced by carbon pool shifts in above-ground biomass. |
| `CH4e` | Numeric | $CH_4$ emissions resulting from above-ground biomass combustion during forest clearing events. |
| `N2Oe` | Numeric | $N2O$ emissions resulting from biomass combustion during land clearing. |
| `NOxe` | Numeric | $NOx$ trace gas emissions driven by biomass combustion processes. |

---

## How to Run the Code

### Verification Mode (Quick Run)
Because a full-scale execution requires extensive computational hours and 32 GB of RAM, a **Quick Run / Verification Mode** is hardcoded inside the script. 
1. Open `soy-biodiversity-impact-model.Rproj` in RStudio.
2. Open `main_analysis_model.R`.
3. Locate the `RUN_MODE` flag at the top of the script and ensure it is set to `"QUICK_TEST"`.
4. Run the script. This mode filters the entire dataset down to a **single municipality** and a **single calendar year**, allowing reviewers to verify the math, log logic, and execution pipelines within less than 2 minutes without exhausting hardware resources.

### Full Scale Execution
To reproduce the full multi-gigabyte paper results, switch the flag to `RUN_MODE <- "FULL_SCALE"`. *Warning: Ensure your machine has 32 GB of RAM fully unallocated before running.*

---

## License & Citation
* **Code License:** MIT License
* **Data License:** Creative Commons Attribution 4.0 International (CC-BY-4.0)

**Citation Link:** Please cite this repository and its connected data arrays using the following permanent object identifier: https://doi.org/10.5281/zenodo.TU_DOI_DE_ZENODO