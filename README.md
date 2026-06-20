# Biodiversity Loss Footprint of the Brazilian Soy Supply Chain

**Nelson K. Sinisterra-Solís**<sup>1*</sup> [<img src="https://orcid.org/assets/vectors/orcid.logo.icon.svg" alt="ORCID iD" width="16" height="16">](https://orcid.org/0000-0002-8428-9205); **Neus Sanjuan**<sup>2</sup> [<img src="https://orcid.org/assets/vectors/orcid.logo.icon.svg" alt="ORCID iD" width="16" height="16">](https://orcid.org/0000-0001-9413-0268); **Neus Escobar**<sup>2,3</sup> [<img src="https://orcid.org/assets/vectors/orcid.logo.icon.svg" alt="ORCID iD" width="16" height="16">](https://orcid.org/0000-0001-7644-8790)

<details>
  <summary><b>► Click to expand the affiliations</b></summary>
  <br>
  <p><sup>1</sup> <i>Institute of Food Engineering FoodUPV, Universitat Politècnica de València (UPV), Camí de Vera s/n, 46022 València, Spain.</i></p>
  <p><sup>2</sup> <i>Basque Centre for Climate Change (BC3), Parque Científicio de UPV/EHU, 48940 Leioa, Spain.</i></p>
  <p><sup>3</sup> <i>Biodiversity and Natural Resources (BNR) Program, International Institute for Applied Systems Analysis (IIASA), Schlossplatz 1, 2361, Laxenburg, Austria.</i></p>
  <p><sup>*</sup> <i>Corresponding author: <a href="mailto:nelsiso@upv.edu.es">nelsiso@upv.edu.es</a></i></p>
</details>

## Overview
<p align="justify">
This repository contains the R implementation and data architecture for estimating the biodiversity loss associated with the international trade of Brazilian soy. Utilising an <b>attributional Life Cycle Assessment (LCA)</b> framework, the model couples supply chain activity data with spatially explicit layers of biophysical parameters and characterisation factors to quantify biodiversity degradation as a linear function of activities across the soy supply chain.
</p>

<p align="justify">
<b>This repository serves as the comprehensive supplementary material for the associated scientific publication [xxxx]</b>
</p>

## Data Availability and Reproducibility Framework
<div align="justify">
Due to the multi-terabyte size of the high-resolution geospatial LCA and the corresponding datasets (spanning 2004–2022), the complete analytical infrastructure exceeds the standard storage limits of platforms like GitHub and Zenodo. To ensure open science, transparency, and computational reproducibility, we implemented a decoupled hybrid data-sharing architecture consisting of:

Code Repository (GitHub): Serves as the central platform for methodological transparency, hosting all version-controlled R scripts, custom functions, documentation, and the complete RStudio project structure (.Rproj).

Reproducibility Dataset (Zenodo): Functions as the core package for workflow validation. It provides an optimised, lightweight subset—including tabular databases, shapefiles, intermediate outputs, and specific raster layers—designed to fully execute and verify the pipeline for a default reference year (2019) and a single selected municipality.

Comprehensive Core Dataset: Datasets omitted from Zenodo due to storage limitations or restrictive licensing types, which are necessary to obtain the full comprehensive results of the study, as detailed further below. Specific instructions for accessing and obtaining these files are provided in the description section of each dataset.

To fully replicate the analysis or run the scripts, users must combine the R code with the data cores hosted on Zenodo. 
</div>

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
*Note: All Excel files (.xlsx) contain embedded metadata sheets/legends detailing their specific contents. Description for plain-text and spatial formats are detailed below*

| File Identifier | File Name / Path | Description & Source |
| :--- | :--- | :--- |
| **Input 1** | `trase_soy_supply_chain.xlsx` | <div align="justify"> Annual soy market volumes (2004–2022), origin municipalities, export ports, destination countries, FOB prices, and land use demand. Adapted from Trase [^1].</div> |
| **Input 2** | `nd2_nd3_spatial_units.xlsx` |Geographic coordinates of export and import ports[^2].|
| **Input 3** | `soy_maize_double_cropping.xlsx` |<div align="justify">  Soy and maize harvest data by Brazilian municipality (2004–2022) to estimate the magnitude of double-cropping. Sourced from IBGE-SIDRA[^3]. </div>|
| **Input 4** | `brazil_municipal_exports_2025.csv` | <div align="justify"> International trade data (1997–2025) for SH4 codes (2304, 1201, 1507, 1208) to allocate commodities to supply chains. Sourced from IBGE-COMEX [^4].</div> |
| **Input 5** | `destination_countries_id.xlsx` | <div align="justify"> Identification data for destination countries used for dataframe linkage.</div>|
| **Input 6** | `brazil_crushing.xlsx` | <div align="justify"> Monthly commercial balance of domestic soy commodity per municipality (1998–2024). Sourced from ABIOVE [^5]. </div>|
| **Input 7** | `soy_oil_and_meal_prices.xlsx` | <div align="justify"> Economic values and trade volumes for soy cake and oil (2022) used for economic allocation. Sourced from ABIOVE[^5].</div> |
| **Input 8** | `shp/br_municipalities_2021/br_municipalities_2021.shp` |<div align="justify"> Polygon vector layer of Brazilian municipalities for spatial identification (https://www.ibge.gov.br/geociencias/downloads-geociencias.html). </div>|
| **Input 9** | `raster/raster1/ecological_zone_BR.tif` | <div align="justify"> IPCC Climate Zones raster clipped for Brazil, mapped to IPCC carbon/biomass stocks (https://philipaudebert.users.earthengine.app/view/ipcc-climate-zones).</div> |
| **Input 10** | `raster/land_cover/land_cover_` |<div align="justify">  MapBiomas Collection 8 land cover raster (30m). *Note: Due to storage constraints, only 2016 and 2019 are provided for code verification. The full series (2001–2022) is available at MapBiomas* [^6].</div>|
| **Input 11** | `raster/soil_organic_carbon_soc/soc_` | <div align="justify"> Soil Organic Carbon (SOC) raster (30cm depth, 30m resolution, Beta1). *Note: Years 2016 and 2019 provided; full series at MapBiomas* [^7].</div> |
| **Input 12** | `raster/burned_area/burned_area_` |<div align="justify">  Burned area event raster (30m) to estimate non-CO2 emissions from land clearing. *Note: Years 2016 and 2019 provided; full series at MapBiomas*[^8].</div> |
| **Input 13** |<div align="justify">  `land_use_types.xlsx` | IPCC parameters for calculating carbon stock changes across land-use types and ecological zones[^9][^10].</div> |
| **Input 14** |<div align="justify">  `eco_municipalities.shp` | Spatial intersection vector layer mapping municipal boundaries against ecoregions to downscale biodiversity CFs (https://www.ibge.gov.br/geociencias/downloads-geociencias.html) (https://www.worldwildlife.org/publications/).</div> |
| **Input 15** |<div align="justify">  `cf_biodiversity_loss_luluc.xlsx` | Biodiversity loss Characterization Factors (CFs) for habitat transformation and occupation from Scherer et al.[^11]. </div>|
| **Input 16** |<div align="justify">  `lci_soy_production.xlsx` | LCA foreground activity data for farming and processing stages compiled from 22 scientific articles (2011–2023)[^12][^13][^14][^15][^16][^17][^18][^19][^20][^21][^22][^23][^24][^25][^26][^27][^28][^29][^30][^31][^32][^33].</div> |
| **Input 17** |<div align="justify">  `on_field_emission_factors.xlsx` | Emission factors for fertilisers and soil amendments [^9][^10], and fossil fuel combustion (Sphera)[^34]. </div>|
| **Input 18** |<div align="justify">  `n_and_c_content.xlsx` | Nitrogen and carbon content in fertilisers and soil amendments. Similar sources than **Input 15**. </div>|
| **Input 19** |<div align="justify">  `domestic_distance.xlsx` | Freight distances from origin to export port calculated via QGIS (www.qgis.org) OpenRouteService (ORS)[^35]. </div>|
| **Input 20** |<div align="justify">  `international_maritime_distance.xlsx`| Maritime shipping routes calculated via QGIS (www.qgis.org) Least Cost Path algorithm with navigable constraints[^36].</div> |
| **Input 22** |<div align="justify">  `international_overland_distance.xlsx`| International overland trade transit distances calculated via QGIS ORS[^35]. </div>|
| **Input 23** |<div align="justify">  `cf_biodiversity_loss_emissions_luluc.xlsx`| LC-Impact (v1.2) characterisation factors for biodiversity loss linked to emissions[^37].</div> |
| **Input 24** |<div align="justify">  `ecoinvent_unit_processes.xlsx` | Univt process indicators from Ecoinvent v3.10, modelling by SimaPro (https://simapro.com/). *Values anonymised to `1` for licensing compliance*[^38].</div> |

---

## Data Dictionary: Output Files (`output_data/`)

### Output 1: `trase_db_imputed_expanded.parquet`
Imputed Trase database expanded with double-cropping practices and individualised breakdowns of soy commodity market.
* **Location/Routing:** `export_port_code`, `export_port_name_mo` (reassigned ports for logical transoceanic shipping) , `port_municipality_code`, `municipality_code`, `import_country_name`, `import_port_name`.
* **Socio-Economic & Logistics:** `fob`, `exporter_name`, `importer_name`, `transport_type`.
* **Agricultural Dynamics:** `soy_eq`, `land_use`, `soy_yield`, `double_cropping_share`.
* **Commodity Splits:** `soybeans_a`, `meal_a`, `oil_a`, `cake_a`, `sh_crusing_to`, domestic/international allocation factors (`dom_kmeal_af`, `for_oil_af`, etc.).
* **Data Quality Indicators:** `municipality_data_quality`, `export_port_data_quality`, `import_country_data_quality`, `land_use_quality_data`, `double_cropping_quality`.

### Output 2: `Eco_zone_area_mun.parquet`
Mapped municipal areas distributed by IPCC climate zone.
*`municipality_code`, `eco_zone`, `area_eco_zone`.

### Output 3: `l_cover_area_full.parquet` 
Changes in municipal land cover over a 3-year window prior to the year of analysis.
* `cov0` (Land cover 3 years prior), `cov1` (Current land cover), `burnt` (Binary wildfire event: 1=Yes, 0=No), `npixel`, `csoc_md` (Soil organic carbon delta), `area`, `municipality_code`, `year`.

### Output 4: `sLULUC_em.parquet`
Uncertainty simulation iterations for computing emissions derived from Land-Use Change.
* Emissions: `CO2e_soc` (from SOC changes), `CO2e_bmb` (above-ground biomass carbon changes), `CH4e`, `N2Oe`, `NOxe` (from biomass burning during clearing).

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
<p align="justify">
The pipeline relies on the following key libraries, each serving a specific role in our Big Data and geospatial framework:
</p>

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
<p align="justify">
The data pipeline includes cleaning, filtering, merging data frames, spatial cropping, and simulating parameter uncertainty. Missing data points within the source datasets were handled using strict imputation rules:
</p>
    
* **Continuous Numeric Variables:** Imputed using weighted mean values.
* **Discrete Variables / Factors:** Imputed using sectorized mode values.

### Memory Optimization & Staged Calculations
<p align="justify">
Due to computational RAM limitations during big-data spatial processing, calculations are executed in chronological stages. Intermediate files are cached and subsequently used as inputs to compile the final outputs.
</p>

### Code Verification Mode (Quick Run)
<p align="justify">
To facilitate rapid testing and code verification by external users, a built-in filter option models data for a single municipality and a specific calendar year. The fully processed dataset, however, is available within the `output_data/`.
</p>

### Proprietary Data Compliance (Ecoinvent)
<p align="justify">
* <b>Note on Input_File 24 (`ecoinvent_unit_processes.xlsx`):</b> Impact indicators derived from Ecoinvent v3.10 (modeled in SimaPro) are used in the unit processes. Because Ecoinvent is a proprietary, paid database, original values in this open-source file have been replaced with a placeholder value of `1`. Users sould refer to the original source to apply the exact values.
</p>

## Contact / Author
nelsiso@upv.edu.es

---
## License
This repository is licensed under the **MIT License** for the source code and software scripts, and the **Creative Commons Attribution 4.0 International (CC-BY 4.0)** for the datasets and metadata structures.

## References
[^1]: Lathuillière, M. J., Suavet, C., Biddle, H., Su, N., Prada Moro, Y., Carvalho, T., & Ribeiro, V. (2022). Brazil soy supply chain (2004-2022) (Version 2.6) [Data set]. Trase. https://doi.org/10.48650/DCE3-JJ97
[^2]: SEARATES platform. https://www.searates.com/es/maritime
[^3]: IBGE-SIDRA. Tabela 1612: Área plantada, área colhida, quantidade produzida, rendimento médio e valor da produção das lavouras temporárias. Sistema IBGE de Recuperação Automática. Instituto Brasileiro de Geografia e Estatística. https://sidra.ibge.gov.br/tabela/1612 (2024).
[^4]: MDIC-Comex Stat. Estatísticas de Comércio Exterior em Dados Abertos — Ministério do Desenvolvimento, Indústria, Comércio e Serviços. Exportação por Municípios do exportador/importador (e SH4). https://www.gov.br/mdic/pt-br/assuntos/comercio-exterior/estatisticas/base-de-dados-bruta (2024).
[^5]: ABIOVE, 2025. Brasil-Complexo Soja. Available at: https://abiove.org.br/estatisticas-cadeia-da-soja-mensal/
[^6]: MapBiomas. Collection [8] of the Annual Land Use Land Cover Maps of Brazil. Collection 8 land cover and use maps for all Brazil in GeoTiff format from 1985 to 2022 https://brasil.mapbiomas.org/en/colecoes-mapbiomas/ (2023).
[^7]: MapBiomas. MapBiomas Project - Collection [2 Beta] of Soil Carbon Stocks in Brazil. Beta Collection of Annual Maps of Soil Organic Carbon (SOD) Stocks in Brazil, Covering the Period 1985 to 2021 https://brasil.mapbiomas.org/en/dados-mapbiomas-solo/ (2024).
[^8]: MapBiomas. MapBiomas Project - Collection [3] of the Annual Fire Scars in Brazil. https://brasil.mapbiomas.org/en/metodo-mapbiomas-fogo/ (2025).
[^9]: IPCC. 2006. 2006 IPCC Guidelines for National Greenhouse  as Inventories. Volume 4 Agriculture, Forestry and Other Land Use. https://www.ipcc-nggip.iges.or.jp/public/2019rf/vol4.html (2006).
[^10]: IPCC. 2019 Refinement to the 2006 IPCC Guidelines for National Greenhouse  as Inventories. Volume 4 Agriculture, Forestry and Other Land Use. https://www.ipcc-nggip.iges.or.jp/public/2019rf/vol4.html (2019).
[^11]: Scherer, L. et al. Biodiversity Impact Assessment Considering Land Use Intensities and Fragmentation. Environ. Sci. Technol. 57, 19612–19623 (2023).
[^12]: Giusti, G., Galo, N. R., Tóffano Pereira, R. P., Lopes Silva, D. A. & Filimonau, V. Assessing the impact of drought on carbon footprint of soybean production from the life cycle perspective. J. Clean. Prod. 425, 138843 (2023).
[^13]: Ricardo, K. et al. Environmental performance of phytosanitary control techniques on soybean crop estimated by life cycle assessment (LCA). Environmental Science and Pollution Research 2023 30:20 30, 58315–58329 (2023).
[^14]: Capaz, R. S. et al. Environmental trade-offs of renewable jet fuels in Brazil: Beyond the carbon footprint. Science of The Total Environment 714, 136696 (2020).
[^15]: Brito, T. et al. Life Cycle Assessment for Soybean Supply Chain: A Case Study of State of Pará, Brazil. Agronomy 2023, Vol. 13, 13, (2023).
[^16]: Knoope, M. M. J., Balzer, C. H. & Worrell, E. Analysing the water and greenhouse gas effects of soya bean-based biodiesel in five different regions. GCB Bioenergy 11, 381–399 (2019).
[^17]: Lehuger, S., Gabrielle, B. & Gagnaire, N. Environmental impact of the substitution of imported soybean meal with locally-produced rapeseed meal in dairy cow feed. J. Clean. Prod. 17, 616–624 (2009).
[^18]: Cavalett, O. & Ortega, E. Emergy, nutrients balance, and economic assessment of soybean production and industrialization in Brazil. J. Clean. Prod. 17, 762–771 (2009).
[^19]: Cavalett, O. & Ortega, E. Integrated environmental assessment of biodiesel production from soybean in Brazil. J. Clean. Prod. 18, 55–70 (2010).
[^20]: Prudêncio da Silva, V., van der Werf, H. M. G., Spies, A. & Soares, S. R. Variability in environmental impacts of Brazilian soybean according to crop production and transport scenarios. J. Environ. Manage. 91, 1831–1839 (2010).
[^21]: Mourad, A. L. & Walter, A. The energy balance of soybean biodiesel in Brazil: A case study. Biofuels, Bioproducts and Biorefining 5, 185–197 (2011).
[^22]: Alvarenga, R. A. F. De, Da Silva Júnior, V. P. & Soares, S. R. Comparison of the ecological footprint and a life cycle impact assessment method for a case study on Brazilian broiler feed production. J. Clean. Prod. 28, 25–32 (2012).
[^23]: Romanelli, T. L., Nardi, H. D. S. & Saad, F. A. Material embodiment and energy flows as efficiency indicators of soybean (Glycine max) production in Brazil. Engenharia Agrícola 32, 261–270 (2012).
[^24]: Castanheira, É. G. & Freire, F. Greenhouse gas assessment of soybean production: implications of land use change and different cultivation systems. J. Clean. Prod. 54, 49–60 (2013).
[^25]: Castanheira, É. G., Grisoli, R., Coelho, S., Anderi Da Silva, G. & Freire, F. Life-cycle assessment of soybean-based biodiesel in Europe: comparing grain, oil and biodiesel import from Brazil. J. Clean. Prod. 102, 188–201 (2015).
[^26]: Maciel, V. G. et al. Life Cycle Inventory for the agricultural stages of soybean production in the state of Rio Grande do Sul, Brazil. J. Clean. Prod. 93, 65–74 (2015).
[^27]: Raucci, G. S. et al. Greenhouse gas assessment of Brazilian soybean production: a case study of Mato Grosso State. J. Clean. Prod. 96, 418–425 (2015).
[^28]: Alejos Altamirano, C. A., Yokoyama, L., de Medeiros, J. L. & de Queiroz Fernandes Araújo, O. Ethylic or methylic route to soybean biodiesel? Tracking environmental answers through life cycle assessment. Appl. Energy 184, 1246–1263 (2016).
[^29]: Matsuura, M. I. S. F. et al. Life-cycle assessment of the soybean-sunflower production system in the Brazilian Cerrado. The International Journal of Life Cycle Assessment 2016 22:4 22, 492–501 (2016).
[^30]: Pashaei Kamali, F. et al. Evaluation of the environmental, economic, and social performance of soybean farming systems in southern Brazil. J. Clean. Prod. 142, 385–394 (2017).
[^31]: Cerri, C. E. P. et al. Assessing the greenhouse gas emissions of Brazilian soybean biodiesel production. PLoS One 12, e0176948 (2017).
[^32]: Esteves, E. M. M., Esteves, V. P. P., Bungenstab, D. J., Araújo, O. de Q. F. & Morgado, C. do R. V. Greenhouse gas emissions related to biodiesel from traditional soybean farming compared to integrated crop-livestock systems. J. Clean. Prod. 179, 81–92 (2018).
[^33]: Esteves, V. P. P. et al. Land use change (LUC) analysis and life cycle assessment (LCA) of Brazilian soybean biodiesel. Clean Technologies and Environmental Policy 2016 18:6 18, 1655–1673 (2016).
[^34]: SPHERA. GaBi Databases. GaBi Databases & Modelling Principles 2022 Preprint at https://gabi.sphera.com/international/databases/gabi-databases/ (2022).
[^35]: HeiGIT, H. I. for G. T. Openroute service, ORS Tools QGIS Plugin v1.10.0. Preprint at https://openrouteservice.org/ (2025).
[^36]: QGIS.org. Plugins by FlowMap Group@SESS-PKU - QGIS Python Plugins Repository. Preprint at https://plugins.qgis.org/plugins/author/FlowMap%2520Group%2540SESS-PKU/ (2022).
[^37]: Verones, F. et al. LC-IMPACT: A regionalized life cycle damage assessment method. J. Ind. Ecol. 24, 1201–1219 (2020).
[^38]: Wernet, G. et al. The ecoinvent database version 3 (part I): overview and methodology. International Journal of Life Cycle Assessment 21, 1218–1230 (2016).
