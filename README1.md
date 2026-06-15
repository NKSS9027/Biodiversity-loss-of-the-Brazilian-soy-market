# Biodiversity Loss Impacts of the Brazilian Soy Supply Chain

## Overview
<p align="justify">
This repository contains the R implementation and data architecture for estimating the biodiversity loss associated with the international trade of Brazilian soy. Utilising an **Attributional Life Cycle Assessment (LCA)** framework, the model couples supply chain activity data with spatially explicit layers of biophysical parameters and characterisation factors to quantify biodiversity degradation as a linear function of activities across the soy supply chain.
</p>

<p align="justify">
This repository serves as the comprehensive supplementary material for the associated scientific publication [xxxx]
</p>
---

## Data Availability and Reproducibility Framework
<div align="justify">
Due to the multi-terabyte size of the high-resolution geospatial and LCA datasets (spanning 2004–2022), the complete analytical infrastructure exceeds the standard storage limits of platforms like GitHub and Zenodo. To ensure open science, transparency, and computational reproducibility, we implemented a decoupled hybrid data-sharing architecture:

Code Repository (GitHub): Serves as the central platform for methodological transparency, hosting all version-controlled R scripts, custom functions, documentation, and the complete RStudio project structure (.Rproj).

Reproducibility Dataset (Zenodo): Functions as the core package for workflow validation. It provides an optimised, lightweight subset—including tabular databases, shapefiles, intermediate outputs, and specific raster layers—designed to fully execute and verify the pipeline for a default reference year (2019) and a single selected municipality.

Comprehensive Core Dataset: Datasets omitted from Zenodo due to storage limitations or restrictive licensing types, which are necessary to obtain the full comprehensive results of the study, are detailed further below. Specific instructions for accessing and obtaining these files are provided in the description section of each dataset.

To fully replicate the analysis or run the scripts, you must combine the R code with the data cores hosted on Zenodo. 
</div>
---

### Repository Structure
The project relies on strict relative paths. When fully assembled, the root directory must mirror the following structure:

```text
soy-biodiversity-loss-model/
│
├── soy-biodiversity-impact-model.Rproj  # RStudio Project core
├── main_analysis_model.R                # Primary computation script
├── README.md                            # This documentation file
│
├── input_data/                          # [Sourced from Zenodo Archive A]
│   ├── trase_soy_supply_chain.xlsx      # Supply chain matrices
│   ├── land_cover_masks.shp             # Geospatial vector layers
│   └── ... (other input layers)
│
└── output_data/                         # [Sourced from Zenodo Archive B]
    ├── trase_db_imputed_expanded.parquet
    ├── sLULUC_em.parquet                # Final emissions matrix
    └── ... (simulation outputs)
 ```   

### Data Architecture & Workflow


```mermaid
graph LR
    %% Group 1: Core Trade & Supply Chain
    subgraph 1. Trade & Supply Chain Inputs
        x1[x1: Trase Raw Data]
        x2[x2: Spatial Units]
        x4[x4: Comex Municipal Exports]
        x5[x5: Destination Country IDs]
        x6[x6: Brazil Crushing Balance]
    end

    %% Group 2: Agricultural & Economic Variables
    subgraph 2. Farm & Econ Inputs
        x3[x3: Double Cropping Data]
        x7[x7: Oil & Meal Prices]
    end

    %% Group 3: Geo & Environmental
    subgraph 3. Spatial & Env. Inputs
        x8_14[x8 to x14: Geo Rasters & Shapefiles]
        x15_22[x15, x22: Biodiversity CFs]
    end

    %% Group 4: Life Cycle & Transport
    subgraph 4. LCI & Logistics
        x16_18[x16 to x18: Farming LCI]
        x19_21[x19 to x21: Transport Distances]
        x23[x23: Ecoinvent Processes]
    end

    %% Intermediate Nodes
    df_trase[df_trase: Consolidated Trade Matrix]
    df_LULUC[LULUC Area & Emission Matrices]
    df_bgp[df_bgp: Stochastic Characterization Factors]
    df_LCI[df_LCI: Farming Inventories]
    df_dis[df_dis1: Distance Logistics]
    df_pf1[df_pf1_pr: Crushing Energy/Water]

    %% Routing to Intermediates
    x1 & x2 & x4 & x5 & x6 --> df_trase
    x3 -->|Yield & Occupation| df_trase
    x7 -->|Economic Allocation| df_trase
    
    x8_14 --> df_LULUC
    x15_22 --> df_bgp
    x16_18 --> df_LCI
    x19_21 --> df_dis
    x23 --> df_pf1

    %% The Master Node
    df_sch1((df_sch1: Stochastic<br>Master Matrix))

    %% Assembly
    df_trase --> df_sch1
    df_LULUC --> df_sch1
    df_bgp --> df_sch1
    df_LCI --> df_sch1
    df_dis --> df_sch1
    df_pf1 --> df_sch1

    %% Final Output Split
    subgraph Final Impact Outputs
        df_sch1 -->|Aggregated Soy Equivalent| O1[df_sch_soy_eq]
        df_sch1 -->|Unprocessed Whole Grain| O2[df_soybean]
        df_sch1 -->|Direct Bean Meal| O3[df_meal]
        df_sch1 -->|Press-cake Meal + Econ Allocation| O4[df_cake]
        df_sch1 -->|Crude Soy Oil + Econ Allocation| O5[df_oil]
    end
    
    %% Styling
    style df_sch1 fill:#2C3E50,stroke:#F39C12,stroke-width:4px,color:#fff
    style O1 fill:#27AE60,stroke:#fff,color:#fff
    style O2 fill:#2980B9,stroke:#fff,color:#fff
    style O3 fill:#2980B9,stroke:#fff,color:#fff
    style O4 fill:#8E44AD,stroke:#fff,color:#fff
    style O5 fill:#8E44AD,stroke:#fff,color:#fff


```
## Data Dictionary: Input Files (`input_data/`)
[cite_start]*Note: All Excel (.xlsx) files contain embedded metadata sheets/legends detailing their specific contents[cite: 204]. For plain-text and spatial formats, descriptions are detailed below[cite: 205].*

| File Identifier | File Name / Path | Description & Source |
| :--- | :--- | :--- |
| **Input 1** | `trase_soy_supply_chain.xlsx` | Annual soy market volumes (2004–2022), origin municipalities, export ports, destination countries, FOB prices, and land use demand. Adapted from Trase [^1]. |
| **Input 2** | `nd2_nd3_spatial_units.xlsx` |Geographic coordinates of export and import ports[^2]. |
| **Input 3** | `soy_maize_double_cropping.xlsx` | Soy and maize harvest data by Brazilian municipality (2004–2022) to estimate double-cropping magnitude. Sourced from IBGE-SIDRA[^3]. |
| **Input 4** | `brazil_municipal_exports_2025.csv` | International trade data (1997–2025) for SH4 codes (2304, 1201, 1507, 1208) to allocate commodities to supply chains. Sourced from IBGE-COMEX [^4]. |
| **Input 5** | `destination_countries_id.xlsx` | Identification data for destination countries used for dataframe linkage [^5].|
| **Input 6** | `brazil_crushing.xlsx` | Monthly domestic soy commodity commercial balance per municipality (1998–2024). Sourced from ABIOVE [^6]. |
| **Input 7** | `soy_oil_and_meal_prices.xlsx` | Economic values and trade volumes for soy cake and oil (2022) used for economic allocation. Sourced from ABIOVE[^7]. |
| **Input 8** | `shp/br_municipalities_2021/br_municipalities_2021.shp` |Polygon vector layer of Brazilian municipalities for spatial identification [^8]. |
| **Input 9** | `raster/raster1/ecological_zone_BR.tif` | IUCN ecological zones raster clipped for Brazil, mapped to IPCC carbon/biomass stocks [^9]. |
| **Input 10** | `raster/land_cover/land_cover_` | MapBiomas Collection 8 land cover raster (30m). *Note: Due to storage constraints, only 2016 and 2019 are provided for code verification. The full series (2001–2022) is available at MapBiomas* [^10]. |
| **Input 11** | `raster/soil_organic_carbon_soc/soc_` | Soil Organic Carbon (SOC) raster (30cm depth, 30m resolution, Beta1). *Note: Years 2016 and 2019 provided; full series at MapBiomas* [^11]. |
| **Input 12** | `raster/burned_area/burned_area_` | Burned area event raster (30m) to estimate non-CO2 emissions from land clearing. *Note: Years 2016 and 2019 provided; full series at MapBiomas*[^12]. |
| **Input 13** | `land_use_types.xlsx` | IPCC parameters for calculating carbon stock changes across land-use types and ecological zones[^13]. |
| **Input 14** | `eco_municipalities.shp` | Spatial intersection vector layer mapping municipal boundaries against ecoregions to downscale biodiversity CFs[^3]. |
| **Input 15** | `cf_biodiversity_loss_luluc.xlsx` | Biodiversity loss Characterization Factors (CFs) for habitat transformation and occupation from Scherer et al. (2023)[^15]. |
| **Input 16** | `lci_soy_production.xlsx` | LCA foreground activity data for farming/processing stages compiled from 22 scientific articles (2011–2023)[^16]. |
| **Input 17** | `on_field_emission_factors.xlsx` | Emission factors for fertilizers/soil amendments (IPCC) and fossil fuel combustion (Sphera)[^17]. |
| **Input 18** | `n_and_c_content.xlsx` | Nitrogen and Carbon content in fertilizer products and soil amendments[^18]. |
| **Input 19** | `domestic_distance.xlsx` | Freight distances from origin to export port calculated via QGIS OpenRouteService (ORS)[^19]. |
| **Input 20** | `international_maritime_distance.xlsx`| Maritime shipping routes calculated via QGIS Least Cost Path algorithm with navigable constraints[^20]. |
| **Input 22** | `international_overland_distance.xlsx`| International overland trade transit distances calculated via QGIS ORS[^21]. |
| **Input 23** | `cf_biodiversity_loss_emissions_luluc.xlsx`| LC-Impact (v1.2) characterization factors for biodiversity loss linked to emissions[^22]. |
| **Input 24** | `ecoinvent_unit_processes.xlsx` | Ecoinvent v3.10 unit process indicators (SimaPro). *Values anonymized to `1` for licensing compliance*[^23]. |

---

## Data Dictionary: Output Files (`output_data/`)

### Output 1: `trase_db_imputed_expanded.parquet` [cite: 101]
Imputed Trase database expanded with double-cropping practices and individualized soy commodity market splits[cite: 102, 103].
* [cite_start]**Location/Routing:** `export_port_code` [cite: 112][cite_start], `export_port_name_mo` (reassigned ports for logical transoceanic shipping) [cite: 113, 114, 115][cite_start], `port_municipality_code` [cite: 116][cite_start], `municipality_code` [cite: 123][cite_start], `import_country_name` [cite: 105][cite_start], `import_port_name`[cite: 147].
* [cite_start]**Socio-Economic & Logistics:** `fob` [cite: 133][cite_start], `exporter_name` [cite: 128][cite_start], `importer_name` [cite: 130][cite_start], `transport_type`[cite: 144].
* [cite_start]**Agricultural Dynamics:** `soy_eq` [cite: 132][cite_start], `land_use` [cite: 134][cite_start], `soy_yield` [cite: 152][cite_start], `double_cropping_share`[cite: 153].
* [cite_start]**Commodity Splits:** `soybeans_a`, `meal_a`, `oil_a`, `cake_a` [cite: 157, 158, 159, 160][cite_start], `sh_crusing_to` [cite: 173][cite_start], domestic/international allocation factors (`dom_kmeal_af`, `for_oil_af`, etc.)[cite: 174, 175, 176, 177].
* [cite_start]**Data Quality Indicators:** `municipality_data_quality` [cite: 135][cite_start], `export_port_data_quality` [cite: 136][cite_start], `import_country_data_quality` [cite: 137][cite_start], `land_use_quality_data` [cite: 140][cite_start], `double_cropping_quality`[cite: 154].

### [cite_start]Output 2: `Eco_zone_area_mun.parquet` [cite: 178]
[cite_start]Mapped municipal areas distributed by IUCN ecological zone type[cite: 179].
* [cite_start]`municipality_code` [cite: 180][cite_start], `eco_zone` [cite: 181][cite_start], `area_eco_zone`[cite: 182].

### [cite_start]Output 3: `l_cover_area_full.parquet` [cite: 183]
[cite_start]Municipal land cover shifts over a 3-year prior window relative to the analysis year[cite: 184].
* [cite_start]`cov0` (Land cover 3 years prior) [cite: 186][cite_start], `cov1` (Current land cover) [cite: 187][cite_start], `burnt` (Binary wildfire event: 1=Yes, 0=No) [cite: 188][cite_start], `npixel` [cite: 189][cite_start], `csoc_md` (Soil organic carbon delta) [cite: 190][cite_start], `area` [cite: 191][cite_start], `municipality_code` [cite: 192][cite_start], `year`[cite: 193].

### Output 4: `sLULUC_em.parquet` [cite: 194]
Uncertainty simulation iterations computing Land-Use Change derived emissions[cite: 195, 196, 197, 198].
* [cite_start]Emissions: `CO2e_soc` (from SOC changes) [cite: 199][cite_start], `CO2e_bmb` (above-ground biomass carbon changes) [cite: 200][cite_start], `CH4e`, `N2Oe`, `NOxe` (from biomass burning during clearing)[cite: 201, 202, 203].

---
## Computational Environment & Dependencies
<p align="justify">
To ensure exact computational reproducibility, the analytical pipeline was executed under the following specifications:
</p>

### Hardware Architecture
* **Processor:** Intel(R) Core(TM) i9-10900K CPU @ 3.70GHz
* **Installed RAM:** 32.0 GB (31.8 GB usable)
* **System Type:** 64-bit Operating System, x64-based processor

### Software & Core Dependencies
* **R Version:** 4.6.0 (2026-04-24 ucrt)
* **RStudio Version:** 2026.05.0+218

The pipeline relies on the following key libraries, each serving a specific role in our Big Data and geospatial framework:

### Required R Packages
| Package | Version | 
| :--- | :--- | 
| `openxlsx` | 4.2.8.1 | 
| `dtplyr` |1.3.3 |
| `triangle` |1.1.0 |
| `raster` | 3.6-32 |
| `arrow` |23.0.1.2 |
`sp` |2.2-1 |
| `rnaturalearthdata` | 1.0.0 |
| `terra` | 1.9-11 |
| `sf` | 1.1-0 |
|`here` |1.0.2 |
| `tidyverse` | 2.0.0  | | |

---

## Methodological & Implementation Notes

### Data Processing and Imputation Rules
The data pipeline includes cleaning, filtering, data frame merging, spatial cropping, and uncertainty parameter simulation[cite: 9]. [cite_start]Missing data points within the source datasets were handled using strict imputation rules:
* **Continuous Numeric Variables:** Imputed using weighted mean values.
* **Discrete Variables / Factors:** Imputed using sectorized mode values.

### Memory Optimization & Staged Calculations
Due to computational RAM limitations during big-data spatial processing, calculations are executed in chronological stages[cite: 22]. [cite_start]Intermediate files are cached and subsequently used as inputs to compile the final outputs.

### Code Verification Mode (Quick Run)
[cite_start]To facilitate rapid testing and code verification by external users, a built-in filter option models data for a single municipality and a specific calendar year[cite: 23]. [cite_start]The fully processed dataset, however, is available within the `output_data/` folder[cite: 24].

### Proprietary Data Compliance (Ecoinvent)
* [cite_start]**Note on Input_File 24 (`ecoinvent_unit_processes.xlsx`):** Indicators derived from Ecoinvent v3.10 (modeled in SimaPro) are used in the unit processes[cite: 98]. [cite_start]Because Ecoinvent is a proprietary, paid database, original values in this open-source file have been replaced with a placeholder value of `1`[cite: 99]. [cite_start]Users must consult the original source to apply the exact values[cite: 99].

---
## Supplementary Data Tables (Stored in Zenodo)
[cite_start]*Note: Any additional Excel files uploaded to the main Zenodo repository alongside this project code are supplementary to the manuscript text[cite: 2]. [cite_start]Every supplementary Excel file includes a dedicated internal sheet detailing variable definitions, units, and methodological context[cite: 204].*

## Contact / Author
nelsiso@upv.edu.es

---
## License
This repository is licensed under the **MIT License** for the source code and software scripts, and the **Creative Commons Attribution 4.0 International (CC-BY 4.0)** for the datasets and metadata structures.

## References
[^1]: Lathuillière, M. J., Suavet, C., Biddle, H., Su, N., Prada Moro, Y., Carvalho, T., & Ribeiro, V. (2022). Brazil soy supply chain (2004-2022) (Version 2.6) [Data set]. Trase. https://doi.org/10.48650/DCE3-JJ97
[^2]: SEARATES platform. https://www.searates.com/es/maritime
[^3]: IBGE-SIDRA. Tabela 1612: Área plantada, área colhida, quantidade produzida, rendimento médio e valor da produção das lavouras temporárias. Sistema IBGE de Recuperação Automática. Instituto Brasileiro de Geografia e Estatística. https://sidra.ibge.gov.br/tabela/1612 (2024).
