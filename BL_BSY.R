
# 1. LIBRARYS ----------------------------------------------------------------

# Function to automatically check, install, and load required R packages
# for the biodiversity loss modeling pipeline.
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}


packages <- c('tidyverse',#Core collection of packages for tidy data science (ggplot2, tibble, tidyr, readr, purrr, dplyr, stringr, forcats)
              'here',#Enables robust relative path management based on the project root
              'terra',#Modern, high-performance spatial raster and vector data processing
              'raster',#Legacy raster support (included for compatibility with specific spatial objects),
              'dtplyr',#Data.table backend for dplyr, optimising processing speed for large trade matrices
              'sf',#Support for simple features, standard for vector spatial analysis
              'sp',#Legacy spatial data class support (included for backward compatibility)
              'rnaturalearthdata',#Vector map data for international border visualisation
              'arrow',#High-performance interface for reading/writing Parquet files (efficient big data storage).
              'triangle',#Provides the triangular distribution, useful for uncertainty and sensitivity analyses.
              'openxlsx',#For reading and writing standard Excel files without external dependencies.
              'rlang'#Core language features and tidy evaluation support for custom functions.
)

ipak(packages)

# 2. DATA INPUT AND PATH CONFIGURATION -----------------------------------------

## 2.1 Definition of Relative Paths for Input Datasets ####
# The following list defines the relative file paths for all raw datasets, 
# including supply chain matrices, spatial vectors (shapefiles), environmental 
# rasters, and characterization factors (CFs).
#
# NOTE: All paths are relative to the project root directory. Do not use absolute 
# paths (e.g., 'C:/Users/...') to ensure reproducibility across different machines.

# Definición de rutas (así solo las cambias aquí una vez)
paths <- list(
  x1   = "input_data/trase_soy_supply_chain.xlsx",
  x2 = "input_data/nd2_nd3_spatial_units.xlsx",
  x3 = "input_data/soy_maize_double_cropping.xlsx",
  x4 ="input_data/brazil_municipal_exports_2025.csv",
  x5 = "input_data/destination_countries_id.xlsx",
  x6 = "input_data/brazil_crushing.xlsx",
  x7 = "input_data/soy_oil_and_meal_prices.xlsx",
  x8 = "input_data/shp/br_municipalities_2021/br_municipalities_2021.shp",
  x9 = "input_data/raster/eco_zones/ecological_zone_BR.tif",
  x10 = "input_data/raster/land_cover/land_cover_",
  x11 = "input_data/raster/soil_organic_carbon_soc/soc_",
  x12 = "input_data/raster/burned_area/burned_area_",
  x13 = "input_data/land_use_types.xlsx",
  x14 = "input_data/shp/eco_municipalities/eco_municipalities.shp",
  x15 = "input_data/cf_biodiversity_loss_luluc.xlsx",
  x16 = "input_data/lci_soy_production.xlsx",
  x17 = "input_data/on_field_emission_factors.xlsx",
  x18 = "input_data/n_and_c_content.xlsx",
  x19 = "input_data/domestic_distance.xlsx",
  x20 = "input_data/international_maritime_distance.xlsx",
  x21 = "input_data/international_overland_distance.xlsx",
  x22 = "input_data/cf_biodiversity_loss_emissions_luluc.xlsx",
  x23 = "input_data/ecoinvent_unit_processes.xlsx"
  )


# 3. TECHNICAL PARAMETERS & MODEL CONFIGURATION --------------------------------

## 3.1 Simulation and Spatial-Temporal Scope ####
v_yr <- 2019   # Target analysis year (Selectable range: 2004 to 2022)
mun  <- 5213756 # IBGE numerical ID for the target soy-producing municipality
nsim <- 1000   # Number of iterations for the Monte Carlo uncertainty analysis

## 3.2 Biomass Carbon Fractions & Stoichiometric Conversions ####
cf_bm   <- 0.47  # Carbon fraction of dry matter in biomass [ton C (t d.m.)^-1]
cf_lt   <- 0.37  # Carbon fraction of dry matter in litter [ton C (t d.m.)^-1]
cf_dom  <- 0.5   # Carbon fraction of dry matter in Dead Organic Matter (DOM) [ton C (t d.m.)^-1]
co2f    <- 44/12 # Stoichiometric conversion factor from Elemental Carbon (C) to CO2
tkgf    <- 1000  # Mass conversion factor from ton to kg
fsoy_occ <- 0.5  # Temporal allocation: Fraction of the year dedicated to the soy crop season

## 3.3 Co-Product Mass Allocation Factors ####
# Economic/Mass partitioning for primary soy derivatives
f_sh_meal_mass <- 0.81 # Mass fraction of soybean meal/cake per ton of raw soy
f_sh_oil_mass  <- 0.19 # Mass fraction of soybean oil per ton of raw soy

## 3.4 Hydrological and Land Surface Constants ####
# Global and continental reference baselines for water and land surface areas
c_fw <- 6.76e+11
g_fw <- 9.90e+12
c_sw <- 9.87e+13
g_sw <- 6.56e+16
c_sl <- 4.37e+11
g_sl <- 6.40e+12
fd   <- 365.25          # Temporal constant: Days per year accounting for leap years
f_tlu <- 3 # Define the time factor for land-use change associated with soybean cultivation.


# 4. TRASE SUPPLY CHAIN CALIBRATION & HIERARCHICAL IMPUTATION ------------------

## 4.1 Load Raw Supply Chain Data ####
df_trase <- read.xlsx(paths$x1)

# METHODOLOGICAL NOTE:
# TRASE supply chain networks contain missing identifiers (labeled as 'UNKNOWN') 
# at various nodes (Origin, Port of Export, Destination), representing a critical 
# source of data gaps. To resolve this without introducing bias, we implement a 
# hierarchical imputation algorithm. Missing entries are systematically assigned 
# identifiers based on the statistical representativeness and maximum volume 
# shares of existing known links for each specific node and year.


## 4.2 Node 1 Imputation: Origin (Municipality Level) ####
# Iterating through years (2004-2022) to resolve UNKNOWN municipal origins (Code: 9999999)

df_trase1 <- map_df(.x = 2004:2022,.f = function(yr){
  
  df1 <- df_trase %>% 
    filter(year == yr)
  
  # Step A: Imputation based on Exporter-Importer representative shares
  df2 <- df1 %>% 
    group_by(municipality_code,exporter_name,importer_name) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df2$soy_eq1 <- ifelse(df2$municipality_code == 9999999,0,df2$soy_eq)
  
  df2 <- df2 %>% 
    group_by(exporter_name,importer_name) %>% 
    mutate(max1 = ifelse(soy_eq1==max(soy_eq1),municipality_code,0))
  
  df2 <- df2 %>% 
    group_by(exporter_name,importer_name) %>% 
    mutate(municipality_code1 = ifelse(municipality_code == 9999999,max(max1),municipality_code))  
  
  df2 <- df2 %>% 
    dplyr::select(-(soy_eq:max1))
  
  # Step B: Imputation based on Destination Country representative shares
  df3 <- df1 %>% 
    group_by(municipality_code,import_country_name) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df3$soy_eq1 <- ifelse(df3$municipality_code == 9999999,0,df3$soy_eq)
  
  df3 <- df3 %>% 
    group_by(import_country_name) %>% 
    mutate(max1 = ifelse(soy_eq1==max(soy_eq1),municipality_code,0))
  
  df3 <- df3 %>% 
    group_by(import_country_name) %>% 
    mutate(municipality_code2 = ifelse(municipality_code == 9999999,max(max1),municipality_code))
  
  df3 <- df3 %>% 
    dplyr::select(-(soy_eq:max1))
  
  # Step C: Imputation based on Subregion representative shares
  df4 <- df1 %>% 
    group_by(municipality_code,subregion_mo) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df4$soy_eq1 <- ifelse(df4$municipality_code == 9999999,0,df4$soy_eq)
  
  df4 <- df4 %>% 
    group_by(subregion_mo) %>% 
    mutate(max1 = ifelse(soy_eq1==max(soy_eq1),municipality_code,0))
  
  df4 <- df4 %>% 
    group_by(subregion_mo) %>% 
    mutate(municipality_code3 = ifelse(municipality_code == 9999999,max(max1),municipality_code))
  
  df4 <- df4 %>% 
    dplyr::select(-(soy_eq:max1))
  
  df5 <- df1 %>% 
    group_by(municipality_code,economy_type) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df5$soy_eq1 <- ifelse(df5$municipality_code == 9999999,0,df5$soy_eq)
  
  # Step D: Imputation based on Economy Type representative shares
  df5 <- df5 %>% 
    group_by(economy_type) %>% 
    mutate(max1 = ifelse(soy_eq1==max(soy_eq1),municipality_code,0))
  
  df5 <- df5 %>% 
    group_by(economy_type) %>% 
    mutate(municipality_code4 = ifelse(municipality_code == 9999999,max(max1),municipality_code))
  
  df5 <- df5 %>% 
    dplyr::select(-(soy_eq:max1))
  
  df1 <- df1 %>% 
    left_join(df2)
  
  df1 <- df1 %>% 
    left_join(df3)
  
  df1 <- df1 %>% 
    left_join(df4)
  
  df1 <- df1 %>% 
    left_join(df5)
  
  return(df1)
})

# Constructing data quality metadata flag for traceability at Node 1
df_trase1$municipality_data_quality <- ifelse(df_trase1$municipality_code != 9999999,'non_imputed',
                             ifelse(df_trase1$municipality_code == 9999999 & df_trase1$municipality_code1 != 9999999,
                                    'trader_imputed',
                                    ifelse(df_trase1$municipality_code == 9999999 & df_trase1$municipality_code1 == 9999999 &
                                             df_trase1$municipality_code2 != 9999999,
                                           'import_country_imputed',
                                           ifelse(df_trase1$municipality_code == 9999999 & df_trase1$municipality_code1 == 9999999 &
                                                    df_trase1$municipality_code2 == 9999999 & df_trase1$municipality_code3 != 9999999,  
                                                  'import_region_imputed','economic_region_imputed'
                                           ))))

# Replacing missing origin codes with their hierarchical imputed targets
df_trase1$municipality_code <- ifelse(df_trase1$municipality_code != 9999999,df_trase1$municipality_code,
                           ifelse(df_trase1$municipality_code == 9999999 & df_trase1$municipality_code1 != 9999999,
                                  df_trase1$municipality_code1,
                                  ifelse(df_trase1$municipality_code == 9999999 & df_trase1$municipality_code1 == 9999999 &
                                           df_trase1$municipality_code2 != 9999999,
                                         df_trase1$municipality_code2,
                                         ifelse(df_trase1$municipality_code == 9999999 & df_trase1$municipality_code1 == 9999999 &
                                                  df_trase1$municipality_code2 == 9999999 & df_trase1$municipality_code3 != 9999999,  
                                                df_trase1$municipality_code3,df_trase1$municipality_code4
                                         ))))

# Cleaning up temporary metadata variables
df_trase1 <- df_trase1 %>% 
  dplyr::select(-(municipality_code1:municipality_code4))

# Updating metadata for unique identifiers at Node 1
nm_nd1 <- df_trase1 %>% 
  dplyr::select(biome:municipality_name) %>% 
  unique() %>% 
  filter(municipality_name != 'UNKNOWN')


df_trase1 <- df_trase1 %>% 
  dplyr::select(-(biome:state_name_trase),-(municipality_name_pt:municipality_name))

df_trase1 <- nm_nd1 %>% 
  right_join(df_trase1)


## 4.3 Node 2 Imputation: Intermediate Port of Export ####
df_trase1$export_port_code <- ifelse(df_trase1$subregion_mo == 'Domestic',27,df_trase1$export_port_code)
df_trase1$export_port_name <- ifelse(df_trase1$subregion_mo == 'Domestic','PROCESSED DOMESTICALLY',df_trase1$export_port_name)
df_trase1$export_port_name_mo <- ifelse(df_trase1$subregion_mo == 'Domestic','PROCESSED DOMESTICALLY',df_trase1$export_port_name_mo)
df_trase1$port_municipality_code <- ifelse(df_trase1$subregion_mo == 'Domestic',9999998,df_trase1$port_municipality_code)

# Iterating through years to resolve UNKNOWN export ports (Code: 99)
df_trase2 <- map_df(.x = 2004:2022,.f = function(yr){
  
  df1 <- df_trase1 %>% 
    filter(year == yr)
  
  # Step A: Imputation via Trader link
  df2 <- df1 %>% 
    group_by(export_port_code,exporter_name,importer_name) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df2$soy_eq1 <- ifelse(df2$export_port_code == 99|df2$export_port_code == 27,0,df2$soy_eq)
  
  df2 <- df2 %>% 
    group_by(exporter_name,importer_name) %>% 
    mutate(max1 = ifelse(soy_eq1==max(soy_eq1),export_port_code,0))
  
  df2 <- df2 %>% 
    group_by(exporter_name,importer_name) %>% 
    mutate(export_port_code1 = ifelse(export_port_code == 99,max(max1),export_port_code))  
  
  df2 <- df2 %>% 
    dplyr::select(-(soy_eq:max1))
  
  # Step B: Imputation via Municipal Origin link
  df3 <- df1 %>% 
    group_by(export_port_code,municipality_code) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df3$soy_eq1 <- ifelse(df3$export_port_code == 99|df3$export_port_code == 27,0,df3$soy_eq)
  
  df3 <- df3 %>% 
    group_by(municipality_code) %>% 
    mutate(max1 = ifelse(soy_eq1==max(soy_eq1),export_port_code,0))
  
  df3 <- df3 %>% 
    group_by(municipality_code) %>% 
    mutate(export_port_code2 = ifelse(export_port_code == 99,max(max1),export_port_code))  
  
  df3 <- df3 %>% 
    dplyr::select(-(soy_eq:max1))
  
  # Step C: Imputation via Importing Country link
  df4 <- df1 %>% 
    group_by(export_port_code,import_country_name) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df4$soy_eq1 <- ifelse(df4$export_port_code == 99|df4$export_port_code == 27,0,df4$soy_eq)
  
  df4 <- df4 %>% 
    group_by(import_country_name) %>% 
    mutate(max1 = ifelse(soy_eq1==max(soy_eq1),export_port_code,0))
  
  df4 <- df4 %>% 
    group_by(import_country_name) %>% 
    mutate(export_port_code3 = ifelse(export_port_code == 99,max(max1),export_port_code))  
  
  df4 <- df4 %>% 
    dplyr::select(-(soy_eq:max1))
  
  
  
  df1 <- df1 %>% 
    left_join(df2)
  
  df1 <- df1 %>% 
    left_join(df3)
  
  df1 <- df1 %>% 
    left_join(df4)
  
  return(df1)
})

# Constructing data quality metadata flag for Node 2
df_trase2$export_port_data_quality <- ifelse(df_trase2$export_port_code != 99,'Non_imputed',
                               ifelse(df_trase2$export_port_code == 99 & df_trase2$export_port_code1 != 99,
                                      'Trader_imputed',
                                      ifelse(df_trase2$export_port_code == 99 & df_trase2$export_port_code1 == 99 &
                                               df_trase2$export_port_code2 != 99,
                                             'Origin_imputed','Import_country_imputed'
                                      )))

# Executing code replacements based on hierarchical results
df_trase2$export_port_code <- ifelse(df_trase2$export_port_code != 99,df_trase2$export_port_code,
                             ifelse(df_trase2$export_port_code == 99 & df_trase2$export_port_code1 != 99,
                                    df_trase2$export_port_code1,
                                    ifelse(df_trase2$export_port_code == 99 & df_trase2$export_port_code1 == 99 &
                                             df_trase2$export_port_code2 != 99,
                                           df_trase2$export_port_code2,df_trase2$export_port_code3
                                    )))

df_trase2 <- df_trase2 %>% 
  dplyr::select(-(export_port_code1:export_port_code3))


# Re-aligning port metadata identifiers
nm_nd2 <- df_trase2 %>% 
  dplyr::select(export_port_code,export_port_name_mo:port_municipality_code) %>% 
  unique() %>% 
  filter(!is.na(export_port_name_mo),export_port_name_mo != 'UNKNOWN')

df_trase2 <- df_trase2 %>% 
  dplyr::select(-(export_port_name:port_municipality_code))

df_trase2 <- nm_nd2 %>% 
  right_join(df_trase2)

# Standardizing classifications
df_trase2$economic_region <- ifelse(df_trase2$export_port_code == 27,'Domestic',df_trase2$economic_region)
df_trase2$import_country_name <- ifelse(df_trase2$export_port_code == 27,'BRAZIL',df_trase2$import_country_name)
df_trase2$subregion_mo <- ifelse(df_trase2$export_port_code == 27,'Domestic',df_trase2$subregion_mo)
df_trase2$import_port_code <- ifelse(df_trase2$export_port_code == 27,15,df_trase2$import_port_code)



## 4.4 Node 3 Imputation: Destination Port ####
# Hierarchical processing for European and general global destination gaps (Codes: 998, 999)

df_trase3 <- map_df(.x = 2004:2022,.f = function(yr){
  
  df1 <- df_trase2 %>% 
    filter(year == yr)
  
  # Step A: Imputation via Trade Partner profiles (accounting for EU regional clusters)
  df2 <- df1 %>% 
    group_by(import_port_code,import_country_name,subregion_mo,exporter_name,importer_name) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df2$soy_eq1 <- ifelse(df2$import_port_code == 999|df2$import_port_code == 998,0,df2$soy_eq)
  df2$soy_eq2 <- ifelse(df2$subregion_mo == 'EU',df2$soy_eq1,0)
  
  df2 <- df2 %>% 
    group_by(exporter_name,importer_name) %>% 
    mutate(max1 = ifelse(subregion_mo == 'EU',
                         ifelse(soy_eq2==max(soy_eq2),import_port_code,0),
                         ifelse(soy_eq1==max(soy_eq1),import_port_code,0)))
  
  df2 <- df2 %>% 
    group_by(exporter_name,importer_name) %>% 
    mutate(import_port_code1 = ifelse(import_port_code == 999|import_port_code == 998,max(max1),import_port_code))  
  
  df2 <- df2 %>% 
    dplyr::select(-(soy_eq:max1))
  
  # Step B: Imputation via Exporting Port profiles
  df3 <- df1 %>% 
    group_by(import_port_code,subregion_mo,export_port_code) %>%
    summarise(soy_eq = sum(soy_eq))
  
  df3$soy_eq1 <- ifelse(df3$import_port_code == 999|df3$import_port_code == 998,0,df3$soy_eq)
  df3$soy_eq2 <- ifelse(df3$subregion_mo == 'EU',df3$soy_eq1,0)
  
  df3 <- df3 %>% 
    group_by(export_port_code) %>% 
    mutate(max1 = ifelse(subregion_mo == 'EU',
                         ifelse(soy_eq2==max(soy_eq2),import_port_code,0),
                         ifelse(soy_eq1==max(soy_eq1),import_port_code,0)))
  
  df3 <- df3 %>% 
    group_by(export_port_code) %>% 
    mutate(import_port_code2 = ifelse(import_port_code == 999|import_port_code == 998,max(max1),import_port_code))  
  
  df3 <- df3 %>% 
    dplyr::select(-(soy_eq:max1))
  
  
  df1 <- df1 %>% 
    left_join(df2)
  
  df1 <- df1 %>% 
    left_join(df3)
  
  
  return(df1)
})


# Constructing data quality metadata flag for Node 3
df_trase3$import_country_data_quality <- ifelse(df_trase3$import_port_code < 998,'Non_imputed',
                                  ifelse(df_trase3$import_port_code >= 998 & df_trase3$import_port_code1 < 998,
                                         'Trader_imputed','Port_export_imputed'))

# Synchronizing final Destination node metadata
df_trase3$import_port_code <- ifelse(df_trase3$import_port_code < 998,df_trase3$import_port_code,
                             ifelse(df_trase3$import_port_code >= 998 & df_trase3$import_port_code1 < 998,
                                    df_trase3$import_port_code1,df_trase3$import_port_code2))

df_trase3 <- df_trase3 %>% 
  dplyr::select(-(import_port_code1:import_port_code2))


nm_nd3 <- df_trase3 %>% 
  dplyr::select(import_port_code:economic_region,subregion:subregion_mo) %>% 
  unique() %>% 
  filter(economy_type != 'UNKNOWN')

df_trase3 <- df_trase3 %>% 
  dplyr::select(-(import_country_name:subregion_mo))

df_trase3 <- nm_nd3 %>% 
  right_join(df_trase3)


## 4.5 Land Use Data Imputation ####
# Resolving data gaps in land use attributes using proportional soy volumes

df_trase <- df_trase3 %>% 
  group_by(municipality_code,year,exporter_name,importer_name) %>%
  mutate(land_use1 = ifelse(is.na(land_use),soy_eq*mean(land_use,na.rm = T)/mean(soy_eq,na.rm = T),
                               land_use))

df_trase <- df_trase %>% 
  group_by(municipality_code,year) %>%
  mutate(land_use2 = ifelse(is.na(land_use1),soy_eq*mean(land_use1,na.rm = T)/mean(soy_eq,na.rm = T),
                               land_use1))

# Land allocation data quality flag
df_trase$land_use_quality_data <- ifelse(is.na(df_trase$land_use),
                                 ifelse(is.na(df_trase$land_use1),
                                        'Origin_node-Year imputed',
                                        'Origin_node-Year-Company imputed'),'Non_imputed')

df_trase$land_use <- ifelse(is.na(df_trase$land_use),
                               ifelse(is.na(df_trase$land_use1),
                                      df_trase$land_use2,
                                      df_trase$land_use1),df_trase$land_use)

df_trase$land_use2 <- NULL
df_trase$land_use1 <- NULL

# Merging complementary spatial metrics
tr_p <- read.xlsx(paths$x2)

df_trase <- df_trase %>% 
  left_join(tr_p)


# Dummy variable (dummy_uf_reg) to define state ('uf') vs regional ('reg') farming activity data

df_trase <- df_trase %>% 
  mutate(dummy_uf_reg = ifelse(state_code == 11|state_code == 15|
                         state_code == 21|state_code == 29|
                         state_code == 31|state_code == 35|
                         state_code == 41|state_code == 43|
                         state_code == 50|state_code == 51|
                         state_code == 52,'uf','reg'))

## 4.6 Double Cropping Practices Integration ####
# Load farming yields and double-cropping metrics (Soy + Maize systems)

df_ddp <- read.xlsx(paths$x3)%>% 
  dplyr::select(state_code,municipality_code,year,soy_yield,double_cropping_share) 

# Managing data gaps in multi-cropping allocation indices
df_ddp$double_cropping_quality <- ifelse(is.na(df_ddp$double_cropping_share),'imputed','estimated')

df_ddp$double_cropping_share <- ifelse(is.na(df_ddp$double_cropping_share),0,df_ddp$double_cropping_share)

df_ddp$soy_yield <- ifelse(df_ddp$soy_yield == 0,NA, df_ddp$soy_yield)

df_ddp$soy_yield_quality <- ifelse(is.na(df_ddp$soy_yield),'imputed based on municipality data','consulted')

# Multi-tier imputation for missing agricultural yields (Municipal -> State -> Historical levels)
df_ddp <- df_ddp %>% 
  group_by(municipality_code) %>% 
  mutate(soy_yield = mean(soy_yield,na.rm = T))

df_ddp$soy_yield_quality <- ifelse(is.na(df_ddp$soy_yield),'imputed based on state data in the concern year',
                             df_ddp$soy_yield_quality)
df_ddp <- df_ddp %>% 
  group_by(state_code,year) %>% 
  mutate(soy_yield = mean(soy_yield,na.rm = T))

df_ddp$soy_yield_quality <- ifelse(is.na(df_ddp$soy_yield),'imputed based on state data',
                             df_ddp$soy_yield_quality)

df_ddp <- df_ddp %>% 
  group_by(state_code) %>% 
  mutate(soy_yield = mean(soy_yield,na.rm = T))

df_trase <- df_trase %>% 
  left_join(df_ddp)

## 4.7 Disaggregated International Trade Integration (COMEX) ####
# Load and filter trade metrics for highly disaggregated soy commodities (HS Codes)

df_comex <- read.csv(paths$x4,sep = ';')

df_comex <- df_comex %>% 
  filter(SH4 == 2304|SH4 ==1201|SH4 == 1507|SH4 == 1208)

df_comex <- df_comex %>% 
  group_by(CO_ANO,CO_PAIS,SH4,CO_MUN) %>% 
  summarise(kg_export = sum(KG_LIQUIDO))

df_comex <- df_comex %>% 
  spread(key = 'SH4',value = 'kg_export')

df_comex[is.na(df_comex)] <- 0

names(df_comex) <- c('year','import_country_code','municipality_code','soybeans_a','meal_from_beans_a','oil_a','cake_a')

# Mapping ISO/country codes 
df_id_cd_cty <- read.xlsx(paths$x5)

df_trase <- df_trase %>% 
  left_join(dplyr::select(df_id_cd_cty,import_country_code,import_country_name))

df_trase <- df_trase %>% 
  left_join(df_comex)

## 4.8 Co-Product Mass and Economic Allocation Setup ####
# Separate domestic consumption (BRAZIL) from international routes
df_trasea <- df_trase %>% 
  filter(import_country_name == 'BRAZIL')

df_trasea$soybeans_a <- NULL
df_trasea$meal_from_beans_a <- NULL
df_trasea$oil_a <- NULL
df_trasea$cake_a <- NULL


# Load national processing inventory data to calibrate mass balance
df_vpd <- read.xlsx(paths$x6)#db_br_crus

df_vpd$product <- ifelse(df_vpd$product == '1. Grão','soybeans_a',
                         ifelse(df_vpd$product == '2. Farelo','cake_a','oil_a'))

df_vpd$entry  <- ifelse(df_vpd$entry == '2.3.5. - Consumo interno'|
                                 df_vpd$entry  == '2.2.5. - Consumo interno'|
                                 df_vpd$entry  == '2.1.4. - Sementes/Outros',
                               'domestic_c','other') 

df_vpd <- df_vpd %>% 
  filter(entry  == 'domestic_c') %>% 
  spread(key = product,value = value)

df_vpd$meal_from_beans_a <- 0

df_vpd <- df_vpd %>% 
  dplyr::select(year,soybeans_a,meal_from_beans_a,oil_a,cake_a)

df_trasea <- df_trasea %>% 
  left_join(df_vpd)

df_trasea$data_quality_soy_a <- 'original data'


# Multi-stage spatial allocation of missing trade flows for international nodes
df_traseb <- df_trase %>% 
  filter(import_country_name != 'BRAZIL')

df_traseb$data_quality_soy_a <- ifelse(is.na(df_traseb$soybeans_a),
                                 'Imputed based on average of origin-destination link',
                                 'original data')

df_traseb <- df_traseb %>% 
  group_by(municipality_code,import_country_name) %>% 
  mutate(across(soybeans_a:cake_a,~ifelse(is.na(.x),mean(.x,na.rm = T),.x)
  ))


df_traseb$data_quality_soy_a <- ifelse(is.na(df_traseb$soybeans_a),
                                 'Imputed based on average of destination country in the corresponding year',
                                 df_traseb$data_quality_soy_a)

df_traseb <- df_traseb %>% 
  group_by(import_country_name,year) %>% 
  mutate(across(soybeans_a:cake_a,~ifelse(is.na(.x),mean(.x,na.rm = T),.x)
  ))

df_traseb$data_quality_soy_a <- ifelse(is.na(df_traseb$soybeans_a),
                                 'Imputed based on average of origin municipality in the corresponding year',
                                 df_traseb$data_quality_soy_a)

df_traseb <- df_traseb %>% 
  group_by(municipality_code,year) %>% 
  mutate(across(soybeans_a:cake_a,~ifelse(is.na(.x),mean(.x,na.rm = T),.x)
  ))


df_traseb$data_quality_soy_a <- ifelse(is.na(df_traseb$soybeans_a),
                                 'Imputed based on average of destination country',
                                 df_traseb$data_quality_soy_a)

df_traseb <- df_traseb %>% 
  group_by(import_country_name) %>% 
  mutate(across(soybeans_a:cake_a,~ifelse(is.na(.x),mean(.x,na.rm = T),.x)
  ))

c1 <- df_traseb %>% 
  filter(is.na(oil_a)|is.na(cake_a)| is.na(soybeans_a)|is.na(meal_from_beans_a))

# Recombining datasets and reconverting raw bean equivalents (soy-eq) into soy commodities 
df_trase <- rbind(df_trasea,df_traseb)

f_seq_sb <- 1.031 # Technical factor: 1 kg soy-eq corresponds to 1.031 kg of raw soybean

df_trase$bean_for_meal <- f_seq_sb*df_trase$meal_from_beans_a
df_trase$bean_for_oil <- f_seq_sb*df_trase$oil_a/f_sh_oil_mass
df_trase$bean_for_cake <- f_seq_sb*df_trase$cake_a/f_sh_meal_mass

# Calculating shares and allocating embodied physical volumes
df_trase <- df_trase %>% 
  mutate(sh_bean = soybeans_a/(soybeans_a+bean_for_meal+bean_for_oil+bean_for_cake),
         sh_meal = bean_for_meal/(soybeans_a+bean_for_meal+bean_for_oil+bean_for_cake),
         sh_cake = bean_for_cake/(soybeans_a+bean_for_meal+bean_for_oil+bean_for_cake),
         sh_oil = bean_for_oil/(soybeans_a+bean_for_meal+bean_for_oil+bean_for_cake)
  )

df_trase <- df_trase %>% 
  mutate(soybean = soy_eq*sh_bean,
         bean_meal = soy_eq*sh_meal/f_seq_sb,
         cake = soy_eq*sh_cake*f_sh_meal_mass/f_seq_sb,
         oil = soy_eq*sh_oil*f_sh_oil_mass/f_seq_sb,
         sh_crusing_to = sh_meal+sh_oil+sh_cake)


## 4.9 Economic Allocation Market Prices Model ####
# Integrating price indices for economic allocation of environmental footprints
# between soy oil and cake
df_prices <- read.xlsx(paths$x7)

df_prices <- df_prices %>% 
  dplyr::select(-unit) %>% 
  spread(key = variable,value = value)

df_prices <- df_prices %>% 
  mutate(Cakemeal_dom_price = Cakemeal_dom_price*dom_meal_c,
         Oil_dom_price = Oil_dom_price*dom_oil_c,
         Cakemeal_for_price = Cakemeal_for_price*for_meal_c,
         Oil_for_price = Oil_for_price*for_oil_c)

df_prices <- df_prices %>% 
  group_by(year) %>% 
  summarise(across(dom_meal_c:Oil_for_price,sum))

df_prices <- df_prices %>% 
  mutate(Cakemeal_dom_price = Cakemeal_dom_price/dom_meal_c,
         Oil_dom_price = Oil_dom_price/dom_oil_c,
         Cakemeal_for_price = Cakemeal_for_price/for_meal_c,
         Oil_for_price = Oil_for_price/for_oil_c) %>% 
  dplyr::select(-(dom_meal_c:for_oil_c))

df_prices <- df_prices %>% 
  mutate(dom_kmeal_af = Cakemeal_dom_price*f_sh_meal_mass/((Cakemeal_dom_price*f_sh_meal_mass)+(Oil_dom_price*f_sh_oil_mass)),
         dom_oil_af = Oil_dom_price*f_sh_oil_mass/((Cakemeal_dom_price*f_sh_meal_mass)+(Oil_dom_price*f_sh_oil_mass)),
         for_kmeal_af = Cakemeal_for_price*f_sh_meal_mass/((Cakemeal_for_price*f_sh_meal_mass)+(Oil_for_price*f_sh_oil_mass)),
         for_oil_af = Oil_for_price*f_sh_oil_mass/((Cakemeal_for_price*f_sh_meal_mass)+(Oil_for_price*f_sh_oil_mass))
  ) %>% 
  dplyr::select(-(Cakemeal_dom_price:Oil_for_price))

df_trase <- df_trase %>% 
  left_join(df_prices)



# Standardising domestic final port keys
df_trase$export_port_code1 <- ifelse(df_trase$import_country_name == 'BRAZIL',df_trase$export_port_code,
                                     df_trase$export_port_code1)

df_trase$export_port_name_mo1 <- ifelse(df_trase$import_country_name == 'BRAZIL',df_trase$export_port_name_mo,
                                     df_trase$export_port_name_mo1)

df_trase$export_port_acronym_mo1 <- ifelse(df_trase$import_country_name == 'BRAZIL','BRDOM',
                                     df_trase$export_port_acronym_mo1)

## 4.10 Dataframe Reordering and Column Export Configuration ####
df_trase <- df_trase %>% 
  dplyr::select(year,biome:state_name,municipality_code,municipality_name,
                export_port_code,export_port_name_mo,export_port_code1:export_port_acronym_mo1,
                port_municipality_code,
                logistics_hub:importer_group,import_port_acronym,import_port_code,
                import_port_name,import_country_code,import_country_name:subregion,
                subregion_mo,world_region,economy_type,
                fob,land_use,soy_yield,soy_eq,soybean,bean_meal:oil,soybeans_a:cake_a,
                bean_for_meal,bean_for_cake,bean_for_oil,
                sh_bean:sh_oil,sh_crusing_to:for_oil_af,
                double_cropping_share,dummy_uf_reg,transport_type:export_port_longitude,
                import_port_latitude:dummy_uf_reg,municipality_data_quality:import_country_data_quality,
                land_use_quality_data,soy_yield_quality,double_cropping_quality,data_quality_soy_a)

# Save the fully imputed and harmonized global supply chain database
# [DISABLED BY DEFAULT] Uncomment the line below only if you need to 
# save/export the database to your local directory.
#write_parquet(df_trase,'output_data/trase_db_imputed_expanded.parquet')


# 5. SPATIAL DATA INGESTION & PREPROCESSING -----------------------

# Developing inventory data for land use and land use change ------------------------------------------------------------------

# Ingest municipal boundaries, align to WGS84 (EPSG:4326), and format identifiers
sf_1 <- st_read(paths$x8) %>% 
  mutate_at(vars(CD_MUN),as.double) %>% 
  st_transform(crs = 4326) %>% 
  rename(municipality_code = CD_MUN,municipality_name = NM_MUN)

# Isolate unique supply chain origin nodes from the TRASE dataset
df_mun <- tibble(municipality_code = df_trase$municipality_code) %>% 
  unique()

df_mun$id_row <- as.double(row.names(df_mun))


# Execution Control: Filter for high-relevance representative municipality 
# to facilitate algorithmic validation 

df_mun_i <- df_mun %>% 
  filter(municipality_code == mun)


## 5.1: CLIMATE ZONE SPATIAL OVERLAY & SURFICIAL QUANTIFICATION ---------

#Intersect municipal vectors with IPCC climate zone rasters to calculate baseline areas

df_bm1 <- map_df(.x = df_mun_i$municipality_code ,.f = function(mun){
  
  # Extract local spatial boundary
  sf0 <- sf_1 %>% 
    filter(municipality_code == mun)
  
  # Crop and mask the reference biogeographical raster layer
  r1 <- raster::crop(brick(here(paths$x9)),sf0)
  df1 <- as.data.frame(r1,xy = T, cells = T)
  colnames(df1) <- c('x','y','ipcc_code')
  
  # Compute geodesic cell areas to prevent projection-induced distortion
  df2 <- as.data.frame(terra::area(r1),xy = T, cells = T)
  colnames(df2) <- c('x','y','area')
  
  # Consolidate spatial attributes into a unified structural dataframe
  df3 <- df1 %>% 
    full_join(df2)
  
  df4 <- tibble(municipality_code = mun,
                df3)
  
  # Aggregate total area metrics partitioned by unique IUCN ecological zones
  df5 <- df4 %>% 
    group_by(municipality_code,ipcc_code) %>% 
    summarise(area_eco_zone = sum(area))#Area_BM
  
  return(df5)  
  
})


#linea para para guardar base df_bm1 para todo los municipios
# reporta información del area de cada municipio bajo cada tipo de zona ecologica segun la ICUN
#write.xlsx(df_bm1,'output_data/eco_zone_area_mun.parquet')

## 5.2: SPATIOTEMPORAL LUC MATRIX & CARBON POOL DYNAMICS ---

# Construct dynamic matrices Tracking Soybean Expansion, Wildfire Disturbance, 
# and Soil Organic Carbon (SOC) modifications under a 3-year temporal lag (t-3)
df_bm2 <- map_df(.x = df_mun_i$municipality_code,.f = function(mun){map_df(.x = v_yr,.f = function(yr){#yr1
  
  # Generate and export municipality-level spatial matrices as isolated files.
  # This chunking strategy mitigates RAM capacity constraints 
  # (preventing Out-Of-Memory errors) caused by the massive volume of 
  # high-resolution, multi-temporal raster datasets processed in this loop.
  
  # Isolate vector geometry for targeted spatial extraction
  df1 <- sf_1 %>% 
    filter(municipality_code == mun)
  
  # Extract contemporary land cover state (Year = t)  
  rc1 <- raster::crop(brick(here(paste0(paths$x10,yr,'.tif'))),df1)
  
 
  dfa <- as.data.frame(terra::area(rc1),xy = T, cells = T)
  
  colnames(dfa) <- c('x','y','area')
  
  # Extract historical baseline land cover state factoring in the temporal lag (t - f_tlu)
  rc2 <- raster::crop(brick(here(paste0(paths$x10,yr-f_tlu,'.tif'))),df1)
  
  dfc1 <- as.data.frame(rc1,xy = T, cells = T)
  dfc2 <- as.data.frame(rc2,xy = T, cells = T)
  
  dfc <- dfc1 %>% 
    full_join(dfc2) 
  
  colnames(dfc) <- c('x','y','cov1','cov0')
  
  # Filter for active soybean cultivation fields (MapBiomas Class Code 39)
    dfc <- dfc %>% 
    filter(cov1 == 39) %>% 
    left_join(dfa)
  
  # Ingest gridded Soil Organic Carbon (SOC) stock maps for the corresponding periods
  dfs1 <- raster::crop(brick(here(paste0(paths$x11,yr,'.tif'))),df1)
  dfs2 <- raster::crop(brick(here(paste0(paths$x11,yr-f_tlu,'.tif'))),df1)
  
  dfs1 <- as.data.frame(dfs1,xy = T, cells = T)
  colnames(dfs1) <- c('x','y','soc1')
  dfs2 <- as.data.frame(dfs2,xy = T, cells = T)
  colnames(dfs2) <- c('x','y','soc0')
  
  df2 <- dfc %>% 
    left_join(dfs1) %>% 
    left_join(dfs2)
  
  # Derive net delta changes in Soil Organic Carbon stocks (ΔSOC)
  df2$csoc <- df2$soc1-df2$soc0
  

  # Overlay historical wildfire disturbance raster masks
  df_b <- terra::crop(brick(here(paste0(paths$x12,yr-f_tlu,'.tif'))),df1)
  
  df_b <- as.data.frame(df_b,xy = T, cells = T)  
  
  colnames(df_b) <- c('x','y','burnt')
  
  df2 <- df2 %>% 
    left_join(df_b)
  
  # Compile pixel-level inventory frequencies and mean edaphic carbon shifts
  df2 <- df2 %>% 
    group_by(cov0,cov1,burnt) %>% 
    summarise(npixel = n(),
              csoc_md = mean(csoc,na.rm = T),
              area = sum(area)) %>% 
    mutate(municipality_code = mun,
           year = yr)
  
  return(df2)
  
  # Define a function to save one file per producing municipality.
  # Disable this step to speed up code verification.
  #write_parquet(df2,paste0('output_data/land_cover_area_mun/l_cover_area_',mun,'_',yr,'.parquet'))
  
})})

# Aggregate municipality-level results into a single file.
# Disable this section when running a demonstration with a single municipality.

##df1 <- NULL

##df_mb2 <- map_df(.x = id_mun$municipality_code,.f = function(mun){map_df(.x = yr1,.f = function(yr){

##  df0 <- read_parquet(paste0('output_data/land_cover_area/l_cover_area_',mun,'_',yr,'.parquet'))

##  df1 <-  rbind(df1,df0)

##  df1
##})})

##write_parquet(df_mb2,'output_data/l_cover_area_full.parquet')


#Ingest the comprehensive LULUC activity dataset.
#This dataset was pre-computed and exported by the above-mentioned disabled code block

df_mb2 <- read_parquet("output_data/l_cover_full.parquet")

# Merge environmental parameters with TRASE geographic descriptors
df_mun_bio <- df_trase %>% 
  dplyr::select(biome,municipality_code,state_code,year) %>% 
  unique()

df_mb3 <- df_mun_bio %>% 
  left_join(df_mb2)

# Identify municipalities in TRASE that reported no soybean cover during the analysed years in MapBiomas layers.


# Assign soybean class (code 39) to 1.35297% of previous cover observations with missing data.

## 5.3: DATA CLEANING, RECLASSIFICATION & IMPUTATION HIERARCHIES ----

# Address missing data structures: allocate baseline crop classes to unclassified pixels
df_mb3$cov0 <- ifelse(df_mb3$cov0 == 0|is.na(df_mb3$cov0), 39, df_mb3$cov0)

df_mb3 <- df_mb3%>% 
  rename(map_biomas_class_code = cov0)

# Standardize wildfire interaction matrices (Class 2: Unburnt baseline fallback)
df_mb3$burnt <- ifelse(is.na(df_mb3$burnt),2,df_mb3$burnt)
df_mb3$burnt1 <- ifelse(df_mb3$burnt == 1, ifelse(df_mb3$map_biomas_class_code == 3|
                                                    df_mb3$map_biomas_class_code == 4|
                                                    df_mb3$map_biomas_class_code == 12,
                                                  1,0),0) # si se considera o no las emisiones por quema


# Summarise the dataset based on previously applied adjustments.
# Execute spatial metrics conversion (Square Kilometers to Hectares)
df_mb3 <- df_mb3 %>% 
  group_by(biome,state_code,municipality_code,year,map_biomas_class_code,burnt,burnt1) %>% 
  summarise(area_ha = sum(area)*(1000000/10000),# Convert area units from km² to hectares using a factor of 1,000,000 / 100,000.
            csoc_md = mean(csoc_md,na.rm = T))

# Assign land demand categories between LU and LUC based on land cover at t-3.

# Categorize land demands into Land Use (LU) vs Land Use Change (LUC) pathways (ISO 14044 compliant)
df_mb3$luclu <- ifelse(df_mb3$map_biomas_class_code == 39|df_mb3$map_biomas_class_code == 20 |
                        df_mb3$map_biomas_class_code == 40|df_mb3$map_biomas_class_code == 41 |
                        df_mb3$map_biomas_class_code == 62,'LU','LUC')

# Compute summary statistics of mean SOC changes using MapBiomas grid data.
# Use these statistics to model parameter uncertainty in final estimates.
# Define triangular distributions using min, mean, and max values at different aggregation levels.

## 5.4: MULTI-TIERED SPATIAL AGGREGATION FOR BOUNDARY UNCERTAINTY ----

# Establish statistical boundary metrics (Min, Median, Max) across progressive 
# geographical scales to resolve spatial data gaps and parameterize stochastics
df_mb3 <- df_mb3%>% 
  group_by(municipality_code,year,luclu) %>% 
  mutate(csoc_me = median(csoc_md,na.rm = T),
         csoc_min = min(csoc_md,na.rm = T),
         csoc_max = max(csoc_md,na.rm = T))

df_mb3 <- df_mb3%>% 
  group_by(municipality_code,luclu) %>% 
  mutate(csoc_me1 = median(csoc_md,na.rm = T),
         csoc_min1 = min(csoc_md,na.rm = T),
         csoc_max1 = max(csoc_md,na.rm = T))

df_mb3 <-  df_mb3 %>% 
  group_by(state_code,year,luclu) %>% 
  mutate(csoc_me2 = median(csoc_md,na.rm = T),
         csoc_min2 = min(csoc_md,na.rm = T),
         csoc_max2 = max(csoc_md,na.rm = T))

df_mb3 <-  df_mb3 %>% 
  group_by(state_code,luclu) %>% 
  mutate(csoc_me3 = median(csoc_md,na.rm = T),
         csoc_min3 = min(csoc_md,na.rm = T),
         csoc_max3 = max(csoc_md,na.rm = T))

# Apply hierarchical imputation fallback logic to resolve structural missingness
df_mb3$csoc_me <- ifelse(is.na(df_mb3$csoc_me2),df_mb3$csoc_me3,
                         ifelse(is.na(df_mb3$csoc_me1)& !is.na(df_mb3$csoc_me2),
                                df_mb3$csoc_me2,
                                ifelse(is.na(df_mb3$csoc_me) & !is.na(df_mb3$csoc_me1),
                                       df_mb3$csoc_me1,df_mb3$csoc_me)
                         ))

df_mb3$csoc_min <- ifelse(is.infinite(df_mb3$csoc_min2),df_mb3$csoc_min3,
                          ifelse(is.infinite(df_mb3$csoc_min1)& is.finite(df_mb3$csoc_min2),
                                 df_mb3$csoc_min2,
                                 ifelse(is.infinite(df_mb3$csoc_min) & is.finite(df_mb3$csoc_min1),
                                        df_mb3$csoc_min1,df_mb3$csoc_min)
                          ))

df_mb3$csoc_max <- ifelse(is.infinite(df_mb3$csoc_max2),df_mb3$csoc_max3,
                          ifelse(is.infinite(df_mb3$csoc_max1)& is.finite(df_mb3$csoc_max2),
                                 df_mb3$csoc_max2,
                                 ifelse(is.infinite(df_mb3$csoc_max) & is.finite(df_mb3$csoc_max1),
                                        df_mb3$csoc_max1,df_mb3$csoc_max)
                          ))

df_mb3 <- df_mb3 %>% 
  dplyr::select(-(csoc_md),-(csoc_me1:csoc_max3))

df_mb3 <- df_mb3 %>% 
  group_by(municipality_code,year) %>% 
  mutate(p_area = area_ha/sum(area_ha))

# Adjust biomass values for Amazonian forests based on IPCC guidelines,
# considering their significant differences compared to other Brazilian biomes 


df_mb3$map_biomas_class_code <- ifelse(df_mb3$biome == 'AMAZONIA'& df_mb3$map_biomas_class_code == 9,10,
                                       df_mb3$map_biomas_class_code)


# Develop the CSOC dataset based on the BM1 dataset.
set.seed(2025)
df_s1 <- df_mb3 %>% 
  rowwise() %>%
  mutate(
    Id_sample = list(1:nsim),
    scsoc = list(rtriangle(n = nsim,
                           a = csoc_min,
                           b = csoc_max,
                           c = csoc_me
    ))) %>% 
  dplyr::select(-(csoc_me:csoc_max))


# Load the full dataset of soil types in Brazil according to IUCN classification.
df_bm1 <- read_parquet('output_data/climate_zone_area_mun.parquet')%>%
  filter(!is.na(ipcc_code))


###

df_bio1 <- tibble(biome = df_mb3$biome,
                  municipality_code = df_mb3$municipality_code) %>%
  unique()

df_bm1 <- df_bio1 %>% 
  left_join(df_bm1)%>% 
  filter(!is.na(biome))

# Reclassify IPCC climate zone categories based on biome.

df_bm1 <- df_bm1 %>% 
  mutate(ipcc_code = case_when(
    ipcc_code == 201|ipcc_code ==202 ~ 2012,
    ipcc_code > 400 & ipcc_code < 408 ~ 400,
    ipcc_code == 100 & biome == 'AMAZONIA' ~ 1001,
    ipcc_code == 100 & (biome == 'CERRADO'|biome == 'CAATINGA'|biome == 'MATA ATLANTICA') ~ 1002,
    ipcc_code == 100 & (biome == 'PANTANAL'|biome == 'PAMPA') ~ 1003,
    ipcc_code == 105 & (biome == 'AMAZONIA'|biome == 'CERRADO'|biome == 'CAATINGA'|
                        biome == 'PANTANAL') ~ 1051,
    ipcc_code == 105 & (biome == 'MATA ATLANTICA'|biome == 'PAMPA') ~ 1052,
    ipcc_code == 106 & (biome == 'AMAZONIA'|biome == 'CERRADO'|biome == 'CAATINGA'|
                        biome == 'PANTANAL') ~ 1061,
    ipcc_code == 106 & (biome == 'MATA ATLANTICA'|biome == 'PAMPA') ~ 1062,
    .default = ipcc_code
  ))


df_lu1 <- read.xlsx(paths$x13)
df_lu1[is.na(df_lu1)] <- 0

# Simulate carbon content data by land cover, accounting for uncertainty.
# Triangular distributions are considered to model uncertainty.
set.seed(2025) # seed for simulation
df_lu1_s <- df_lu1 %>% 
  rowwise() %>%
  mutate(
    Id_sample = list(1:nsim),
    sbiomass = list(rtriangle(n = nsim,
                              a = agbm_ll,
                              b = agbm_ul,
                              c = agbm_value)),
    sLitter_bio =list(rtriangle(n = nsim,
                                a = Litter_min,
                                b = Litter_max,
                                c = Litter_value)),
    sDOM = list(rtriangle(n = nsim,
                          a = DOM_min,
                          b = DOM_max,
                          c = DOM_value)),
    sGef_CO2 = list(rtriangle(n = nsim,
                              a =  Gef_CO2/(sd_CO2*1.96),
                              b = Gef_CO2+(sd_CO2*1.96),
                              c = Gef_CO2)/1000),
    sGef_CO = list(rtriangle(n = nsim,
                             a =  Gef_CO/(sd_CO*1.96),
                             b = Gef_CO+(sd_CO*1.96),
                             c = Gef_CO)/1000),
    sGef_CH4 =list(rtriangle(n = nsim,
                             a =  Gef_CH4/(sd_CH4*1.96),
                             b = Gef_CH4+(sd_CH4*1.96),
                             c = Gef_CH4)/1000),
    sGef_N2O = list(rtriangle(n = nsim,
                              a =  Gef_N2O/(sd_N2O*1.96),
                              b = Gef_N2O+(sd_N2O*1.96),
                              c = Gef_N2O)/1000),
    sGef_NOx =list( rtriangle(n = nsim,
                              a =  Gef_NOx/(sd_NOx*1.96),
                              b = Gef_NOx+(sd_NOx*1.96),
                              c = Gef_NOx)/1000),
    sCf = list(rtriangle(n = nsim,
                         a = Cf_value/(Cf_sd*1.96),
                         b = Cf_value+(Cf_sd*1.96),
                         c = Cf_value)/1000)
  ) %>% 
  dplyr::select(type_land_area:ipcc_code,dummy_c,Id_sample:sCf)


df_lusoc <- df_s1 %>% 
  left_join(df_lu1_s)

head(df_lusoc)

# Create consolidated dataframe (df_c1).
df_c1 <- map_df(.x = df_mun_i$municipality_code,.f = function(mun){

  df1 <- df_bm1 %>% 
    filter(municipality_code == mun) %>% 
    collect() 


  # Merge SOC change simulations with IPCC-based biomass carbon inventory data.

  df2 <- df1 %>% 
    left_join(df_lusoc)
  
  df2$isna <- ifelse(is.na(df2$area_bm),1,0)
  
  df2$area_bm <- ifelse(is.na(df2$area_bm), ifelse(df2$map_biomas_class_code == 3,
                                                   0,1),df2$area_bm)
  
  df3 <- df2 %>% 
    group_by(year,map_biomas_class_code,burnt) %>% 
    mutate(p_area_bm = area_bm/sum(area_bm)) %>% 
    unnest(c(Id_sample,scsoc,sbiomass:sCf))
  
  
  df3[is.na(df3)] <- 0
  
  
  df3 <- df3 %>%
    mutate(CO2e_soc = ifelse(luclu == 'LU',scsoc/3,scsoc)*tkgf,
           CO2e_bmb = ifelse(burnt1 == 0,((sbiomass*cf_bm)+(sLitter_bio*cf_lt)+(sDOM*cf_dom)-
                                            ifelse(luclu == 'LUC',10*cf_bm,0))*co2f*tkgf,
                             (sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0))*sCf*sGef_CO2)*area_ha*p_area_bm,
           COe = ifelse(burnt1 == 0|(sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0)) < 0, 0,
                        (sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0))*sCf*sGef_CO)*area_ha*p_area_bm,
           CH4e = ifelse(burnt1 == 0|(sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0)) < 0, 0,
                         (sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0))*sCf*sGef_CH4)*area_ha*p_area_bm,
           N2Oe = ifelse(burnt1 == 0|(sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0)) < 0, 0,
                         (sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0))*sCf*sGef_N2O)*area_ha*p_area_bm,
           NOxe = ifelse(burnt1 == 0|(sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0)) < 0, 0,
                         (sbiomass+sLitter_bio+sDOM-ifelse(luclu == 'LUC',10,0))*sCf*sGef_NOx)*area_ha*p_area_bm
           
    )
  
  
  df4 <- df3  %>% 
    group_by(Id_sample,municipality_code,year,map_biomas_class_code,luclu,map_biomas_class,burnt,burnt1,area_ha) %>% 
    summarise(CO2e_soc = mean(CO2e_soc),
              CO2e_bmb = sum(CO2e_bmb), 
              CH4e = sum(CH4e),
              N2Oe = sum(N2Oe),
              NOxe = sum(NOxe))
  
  df4 <- df4 %>% 
    group_by(Id_sample,municipality_code,year,luclu,burnt1) %>% 
    mutate(CO2e_soc = CO2e_soc*area_ha/sum(area_ha))# Help to compute weighted average CO2 emissions from SOC per hectare.
  
  df5 <- df4 %>% 
    group_by(Id_sample,municipality_code,year,luclu,burnt1) %>% 
    summarise(area_ha = sum(area_ha),
              CO2e_soc = sum(CO2e_soc),
              CO2e_bmb = sum(CO2e_bmb),
              CH4e = sum(CH4e),
              N2Oe = sum(N2Oe),
              NOxe = sum(NOxe)
    )
  
  # Results reflect CO2 emissions derived from SOC changes in kg CO2/ha, 
  # while emissions related to aboveground biomass extraction and burning 
  # are expressed in kg GHG/soy-cultivated area. 
  
  return(df5)
  
})

# [DISABLED BY DEFAULT] Base condensed LULUC emissions from natural compartment stocks
# write_parquet(df_c1,'output_data/sLULUC_em.parquet')

# Normalize SOC emissions from a per-hectare to a per-cultivated-area 
# basis to ensure metric consistency across all impact categories.
df_c1$CO2e_soc <- df_c1$CO2e_soc*df_c1$area_ha 
df_c1 <- df_c1 %>%
   group_by(Id_sample,municipality_code,year) %>% 
  summarise(across(area_ha:NOxe, ~sum(.x)))


# Consolidated database of emissions derived from changes in carbon stocks within natural pools.

# Export aggregated LULUC emission estimates across all municipalities to Parquet format.
# write_parquet(df_c1, 'output_data/sLULUC_em.parquet')


# Integration of emission data by municipality, cross-referencing MapBiomas soy-cultivation layers with Trase datasets.
# Imputation is applied to address data gaps where MapBiomas records were unavailable for specific Trase entries.
# The full emission database is loaded here, as the active processing pipeline is constrained to a single municipality.

df_c1 <- open_dataset('output_data/sLULUC_em.parquet')%>% 
  collect() 

# Emissions reported on a per-hectare basis.
df_c1 <- df_c1 %>% 
  mutate(across(CO2e_soc:NOxe, ~.x/area_ha))

df_trase_mun <- df_trase %>%
  group_by(region_code,region_name,state_code,state_name,municipality_code,municipality_name,year) %>% 
  summarise(soy_eq = sum(soy_eq),
            land_use = sum(land_use))


# Link LULUC emission estimated to TRASE soybean origin points.

df_trase_mun_s <- df_trase_mun %>%
  rowwise() %>% 
  mutate(Id_sample = list(1:nsim)) %>% 
  unnest(Id_sample)

# Perform iterative imputation for municipalities present in TRASE but missing in MapBiomas.
df_mun_luc <- df_trase_mun_s %>% 
  left_join(df_c1)

df_x1 <- df_mun_luc %>% 
  filter(is.na(area_ha)) # Identify TRASE configurations without corresponding MapBiomas data.

df_mun_luc$data_quality_luc_emissions <- ifelse(is.na(df_mun_luc$area_ha),'imputed based on average of the municipality','estimated')

df_mun_luc <- df_mun_luc %>% 
  group_by(Id_sample,municipality_code) %>% 
  mutate(across(area_ha:NOxe,~ifelse(is.na(.x),mean(.x,na.rm = T),.x)))

df_x1 <- df_mun_luc %>% 
  filter(is.na(area_ha)) # Missing data that could not be imputed using municipal averages.

df_mun_luc$data_quality_luc_emissions  <- ifelse(is.na(df_mun_luc$area_ha),'imputed based on average of the state in each year',
                                   df_mun_luc$data_quality_luc_emissions )

df_mun_luc <- df_mun_luc %>% 
  group_by(Id_sample,state_code,year) %>% 
  mutate(across(area_ha:NOxe,~ifelse(is.na(.x),mean(.x,na.rm = T),.x)))

df_x1 <- df_mun_luc %>% 
  filter(is.na(area_ha))

df_mun_luc$data_quality_luc_emissions <- ifelse(is.na(df_mun_luc$area_ha),'imputed based on average of the state',
                                   df_mun_luc$data_quality_luc_emissions)

df_mun_luc <- df_mun_luc %>% 
  group_by(Id_sample,state_code) %>% 
  mutate(across(area_ha:NOxe,~ifelse(is.na(.x),mean(.x,na.rm = T),.x)))

df_x1 <- df_mun_luc %>% 
  filter(is.na(area_ha))

df_mun_luc$data_quality_luc_emissions  <- ifelse(is.na(df_mun_luc$area_ha),'imputed based on average of the region each year',
                                   df_mun_luc$data_quality_luc_emissions)

df_mun_luc <- df_mun_luc %>% 
  group_by(Id_sample,region_code,year) %>% 
  mutate(across(area_ha:NOxe,~ifelse(is.na(.x),mean(.x,na.rm = T),.x)))

df_x1 <- df_mun_luc %>% 
  filter(is.na(area_ha))

# End iterative imputation process.

# Prepare dataset for integration with CFs and unit processes for impact estimation.


df_mun_luc_long <- df_mun_luc %>%
  filter(municipality_code == mun, year == v_yr) %>% 
  gather(key = 'emission',value = 'value_emission',CO2e_soc:NOxe)

df_mun_luc_long <- df_mun_luc_long %>% 
  left_join(tibble(emission = c('CO2e_soc','CO2e_bmb','CH4e','N2Oe','NOxe'),
                   substance_ac = c('CO2','CO2','CH4','N2O','NOx'),# Define key variable for linking with emission-to-impact conversion factors.
                   subc1 = c('iSOC','ibmb','ibmb','ibmb','ibmb')) # Assign subcategories to each emission.
  )


# 6. DIRECT BIODIVERSITY LOSS & CHARACTERIZATION FACTORS -------------------------

# Characterization Factors (CFs) for direct biodiversity loss, adjusted for specific land-use and land-use change (LULUC) practices.

df_munyr <- df_trase %>% 
  dplyr::select(region_name,state_code,municipality_code,year,double_cropping_share,soy_yield) %>% 
  unique()

sf_ecorg <- st_read(paths$x14) %>% 
  dplyr::select(CD_MUN,REALM,ECO_ID,eco_code,inter_km2)%>% 
  unique() %>% 
    rename(municipality_code = CD_MUN)

sf_ecorg <- sf_ecorg %>% 
  group_by(municipality_code) %>% 
  mutate(a_mun = sum(inter_km2))

sf_ecorg$pt_int_amun <- sf_ecorg$inter_km2/sf_ecorg$a_mun

sf_ecorg <- sf_ecorg %>% 
  rename(realm = REALM,
         eco_id = ECO_ID)

sf_ecorg$geometry <- NULL

sf_ecorg <- sf_ecorg%>% 
  mutate_at(vars(municipality_code),as.double)

df_s2 <- df_s1 %>% 
  group_by(state_code,municipality_code,year,map_biomas_class_code) %>% 
  summarise(area_lup = sum(area_ha),
            p_area_lup = sum(p_area))

df_ld <- df_munyr %>% 
  left_join(df_s2)

df_lut <- df_lu1 %>%
  dplyr::select(type_land_area,map_biomas_class,map_biomas_class_code) %>% 
  unique()

df_ld <- df_ld %>% 
  left_join(df_lut)

df_ld$id_land <- ifelse(df_ld$type_land_area == 'Natural_forest','trans','occ')

df_ld <- df_ld%>% 
  group_by(region_name,state_code,municipality_code,year,id_land,double_cropping_share,soy_yield) %>% 
  summarise(area_lup = sum(area_lup))

df_ld <- df_ld %>% 
  spread(key = id_land,value = area_lup)

df_ld$occ <- ifelse(is.na(df_ld$occ) & !is.na(df_ld$trans),0,df_ld$occ)

df_ld$trans <- ifelse(!is.na(df_ld$occ) & is.na(df_ld$trans),0,df_ld$trans)


# Iterative imputation of occupied and transformed land areas to address coverage gaps between Trase and MapBiomas datasets. 
# This methodology is analogous to the imputation protocol implemented for soil carbon stock change (SOC) emissions.

df_ld$tdata_lcrop <- ifelse(is.na(df_ld$occ),'imputed base on average dato of the municipality',
                            'estimated')

df_ld <- df_ld%>% 
  group_by(municipality_code) %>% 
  mutate(across(occ:trans,~ifelse(is.na(.x),mean(.x,na.rm =T),.x)))

df_x2 <- df_ld %>% 
  filter(is.na(occ))

df_ld$tdata_lcrop <- ifelse(is.na(df_ld$occ),'imputed base on average of the state in each year',
                            df_ld$tdata_lcrop)

df_ld <- df_ld %>% 
  group_by(state_code,year) %>% 
  mutate(across(occ:trans,~ifelse(is.na(.x),mean(.x,na.rm =T),.x)))

df_x2 <- df_ld %>% 
  filter(is.na(occ))

df_ld$tdata_lcrop <- ifelse(is.na(df_ld$occ),'imputed base on average of the state',
                            df_ld$tdata_lcrop)

df_ld <- df_ld %>% 
  group_by(state_code) %>% 
  mutate(across(occ:trans,~ifelse(is.na(.x),mean(.x,na.rm =T),.x)))


df_x2 <- df_ld %>% 
  filter(is.na(occ))


df_ld$tdata_lcrop <- ifelse(is.na(df_ld$occ),'imputed base on average of the region in each year',
                            df_ld$tdata_lcrop)

df_ld <- df_ld %>% 
  group_by(region_name,year) %>% 
  mutate(across(occ:trans,~ifelse(is.na(.x),mean(.x,na.rm =T),.x)))


df_x2 <- df_ld %>% 
  filter(is.na(occ))

# Occupation and transformation Characterization Factors are derived 
# based on agricultural intensity levels. Soil productivity is used as a proxy for intensity, 
# classified via yield quantiles: Low (< 25th percentile), Medium (25th–75th percentile), 
# and High (> 75th percentile).

v_yield <- summary(df_ld$soy_yield)


# Apply temporal and spatial filters (analysis period and municipality level) 
# to facilitate rapid workflow validation.
df_ld_r <- df_ld%>% 
  filter(municipality_code == mun, year == v_yr) 

# Assign intensity levels based on relative yield due to lack of direct data.
df_ld_r$habitat_id <- ifelse(df_ld_r$soy_yield < v_yield[[2]],4,
                             ifelse(df_ld_r$soy_yield < v_yield[[5]],2,3))

df_ld_r <- df_ld_r %>% 
  left_join(sf_ecorg)


# Load CF database related to land stress.
df_cf_ld <- read.xlsx(paths$x15) %>% 
  filter(habitat_id == 2|habitat_id == 3|habitat_id == 4)# 2 = Cropland_Intense, 3 = Cropland_Light, 4 = Cropland_Minimal


# Simulate CF values within ecoregion-specific ranges using triangular distributions,
# based on minimum, maximum, and recommended values.
# Compute summary statistics of CF variability by species group.
# Link municipality-level LULUC data with CFs.

tab_cf_ld <- df_cf_ld %>%
  group_by(realm,biome,eco_id,eco_name,habitat_id,habitat) %>% 
  summarise(cf_occ_glo_md = mean(cf_occ_avg_glo),
            cf_occ_glo_min = min(cf_occ_avg_glo),
            cf_occ_glo_max = max(cf_occ_avg_glo),
            cf_tra_glo_md = mean(cf_tra_avg_glo),
            cf_tra_glo_min = min(cf_tra_avg_glo),
            cf_tra_glo_max = max(cf_tra_avg_glo)
            )

df_cf_ld_bl_s <- map_df(.x = 1:nrow(tab_cf_ld),.f = function(x){
  
  set.seed(2025)
  
  df1 <- tibble(
    Id_sample = c(1:nsim),
    eco_id = tab_cf_ld$eco_id[x],
    habitat_id = tab_cf_ld$habitat_id[x],
    habitat = tab_cf_ld$habitat[x],
    cf_occ_glo = rtriangle(n = nsim,a = tab_cf_ld$cf_occ_glo_min[x],b = tab_cf_ld$cf_occ_glo_max[x],
                           c = tab_cf_ld$cf_occ_glo_md[x]),
    
    cf_tra_glo = rtriangle(n = nsim,a = tab_cf_ld$cf_tra_glo_min[x],b = tab_cf_ld$cf_tra_glo_max[x],
                           c = tab_cf_ld$cf_tra_glo_md[x])
  )
  
  return(df1)
  
})

# Link municipal LULUC emission datasets with the corresponding Characterization Factors (CFs).
df_ld_r <- df_ld_r %>% 
  left_join(df_cf_ld_bl_s)


df_ld_r <- df_ld_r %>% 
  mutate(cf_occ_glo = cf_occ_glo*pt_int_amun*v_sy_occ_factor,
         cf_tra_glo = cf_tra_glo*pt_int_amun) %>% 
  group_by(Id_sample,region_name,state_code,municipality_code,year,occ,trans,double_cropping_share) %>% 
  summarise(cf_occ_glo = sum(cf_occ_glo),
            cf_tra_glo = sum(cf_tra_glo))# CFs are expressed in PDF/m².

df_ld_r <- df_ld_r %>% 
  mutate(cf_occ_glo = cf_occ_glo*(occ/(occ+trans))*10000,
         cf_tra_glo = cf_tra_glo*(trans/(occ+trans))*10000) # Adjust theoretical CFs to observed land stress dynamics at the municipality level.

df_ld_r$cf_tra_glo_dc <- (df_ld_r$cf_tra_glo*df_ld_r$double_cropping_share*v_sy_occ_factor)+
  df_ld_r$cf_tra_glo*(1-df_ld_r$double_cropping_share)# Adjust transformation CFs based on double cropping activity.


# 7. LIFE CYCLE INVENTORY (LCI) & PROCESSING -----------------------------------


# Load LCI data from literature sources.
df_LCI_lt <- read.xlsx(paths$x16)


# 7.1 On-field emissions factors  ---------------------------------


# On-field emissions associated to farming and processing


# Data frame with emission factors associated with fertiliser use, soil amendments, and fossil fuel use
df_oef <- read.xlsx(xlsxFile = paths$x17)#fer_emi

# Latent uncertainty in fertiliser emission factors is modeled
set.seed(2025)
df_oef_fer <- tibble(Id_sample = 1:nsim,#ef_fer
                    N2Oi_ef = rtriangle(nsim,a = df_oef$lower_limit[1],
                                        b = df_oef$upper_limit[1],
                                        c= df_oef$recommended_value[1]),
                    N2Od_ef = rtriangle(nsim,a = df_oef$lower_limit[7],
                                        b = df_oef$upper_limit[7],
                                        c= df_oef$recommended_value[7]),
                    NH3_ef = rtriangle(nsim,a = df_oef$lower_limit[13],# Apply a 50% uncertainty factor in accordance with the 2019 European Environment Agency (EEA) guidelines.
                                       b = df_oef$upper_limit[13],
                                       c= df_oef$recommended_value[13]),
                    NOx_ef = rtriangle(nsim,a = df_oef$lower_limit[14],
                                       b = df_oef$upper_limit[14],
                                       c= df_oef$recommended_value[14]),
                    C_ef = rtriangle(nsim,a = df_oef$recommended_value[11],
                                     b = df_oef$recommended_value[12],
                                     c= (df_oef$recommended_value[12]+df_oef$recommended_value[11])/2))


# Load nitrogen and carbon content datasets for fertilisers and soil amendments.
df_nc_cont <- read.xlsx('input_data/n_and_c_content.xlsx')


# 7.2 LCI for farming  -------------------------------------------------------

# Allocate LCI data to municipalities using a top-down approach.
# Source data are available at state or regional level, while municipalities
# are the reference spatial unit (foreground system).
# Agricultural LCI includes yield, seed inputs, fertilisers, soil amendments,
# pesticides, and fuel use. Processing LCI includes electricity and solvent use (e.g., hexane).
# Assign state-level data when available; otherwise use regional-level proxies.
# Model processing stage using national averages due to higher process standardisation.
# Address variability and uncertainty as follows:
# - Apply stochastic selection when multiple studies are available (inter-study variability)
# - Perform Monte Carlo simulation when uncertainty distributions are reported
# - Use deterministic point values when only a single estimate is available


# Farming LCIs with state-level representativeness.


df_LCI_fm_uf <- df_LCI_lt %>%
  filter(stage == 'Farming',!is.na(state_code)) %>%  
  group_by(state_code,type_activity_data3,key_sim,lca) %>% 
  summarise(recommended_value = sum(recommended_value,na.rm = T),
            lower_limit = sum(lower_limit,na.rm = T),
            upper_limit = sum(upper_limit,na.rm = T),
            sd = sum(sd,na.rm = T))

df_LCI_fm_uf$lower_limit <- ifelse(df_LCI_fm_uf$lower_limit == 0, NA,df_LCI_fm_uf$lower_limit)

df_LCI_fm_uf$upper_limit <- ifelse(df_LCI_fm_uf$upper_limit == 0, NA,df_LCI_fm_uf$upper_limit)

df_LCI_fm_uf$sd <- ifelse(df_LCI_fm_uf$sd == 0, NA,df_LCI_fm_uf$sd)


df_LCI_fm_uf <- df_LCI_fm_uf %>% 
  unite('id_sim',state_code,type_activity_data3,key_sim,sep = '-',remove = F)

df_LCI_fm_uf <- df_LCI_fm_uf %>% 
  unite('id_sim1',state_code,type_activity_data3,sep = '-',remove = F)


df_id_fm_uf <- tibble(id_sim1 =df_LCI_fm_uf$id_sim1,
                      lca = df_LCI_fm_uf$lca) %>% 
  unique()


# Count the number of LCI sources per inventory flow and state.

df_id_fm_uf1 <- df_id_fm_uf %>% 
  group_by(id_sim1) %>% 
  summarise(n = n())

df_LCI_fm_uf <- df_LCI_fm_uf %>% 
  left_join(df_id_fm_uf1)

# Classify inventory flows based on data availability and uncertainty information:
# - presence in multiple studies
# - availability of uncertainty data


df_LCI_fm_uf$titem <- case_when((!is.na(df_LCI_fm_uf$lower_limit)|!is.na(df_LCI_fm_uf$sd))& df_LCI_fm_uf$n > 1 ~ 4,
                                # Titem = 4: Inventory flows reported in multiple studies within each state,
                                # with uncertainty information available in each study.
                                (!is.na(df_LCI_fm_uf$lower_limit)|!is.na(df_LCI_fm_uf$sd)) & df_LCI_fm_uf$n == 1 ~ 3,
                                # Titem = 3: Inventory flows reported in a single study,
                                # with uncertainty information available.
                                (is.na(df_LCI_fm_uf$lower_limit) & is.na(df_LCI_fm_uf$sd))& df_LCI_fm_uf$n > 1 ~ 2,
                                # Titem = 2: Inventory flows reported in multiple studies,
                                # without uncertainty information in the individual studies.
                                (is.na(df_LCI_fm_uf$lower_limit) & is.na(df_LCI_fm_uf$sd))& df_LCI_fm_uf$n == 1 ~ 1 
                                # Titem = 1: Inventory flows reported in a single study,
                                # without uncertainty information.
)


# Select inventory flows with multiple sources for stochastic resampling.

df_id_fm_uf2 <- df_id_fm_uf1 %>% 
  filter(n>1)

set.seed(2025)
df_lci_fm_uf_s <- map_df(.x = 1:nrow(df_id_fm_uf2),.f = function(x){
  
  df1 <- df_id_fm_uf %>% 
    filter(id_sim1 == df_id_fm_uf2$id_sim1[x])
  
  df2 <- tibble(Id_sample = 1:nsim,
                id_sim1 = df_id_fm_uf2$id_sim1[x],
                rd = sample(x = 1:nrow(df1),size = nsim,replace = T),
                lca = df1$lca[rd])
  
  return(df2)
  
})

# Identify inventory flows with a single deterministic value.
df_tmp_fm_uf <- df_id_fm_uf1 %>% 
  filter(n == 1) %>% 
  left_join(df_id_fm_uf)

df_tmp_fm_uf$Id_sample <- 1

df_tmp_fm_uf <- df_tmp_fm_uf %>% 
  dplyr::select(Id_sample,id_sim1,lca)

df_lci_fm_uf_s <- df_lci_fm_uf_s %>% 
  dplyr::select(-(rd))

df_lci_fm_uf_s1 <- rbind(df_lci_fm_uf_s,df_tmp_fm_uf)

df_lci_fm_uf_s1 <- df_lci_fm_uf_s1  %>% 
  left_join(df_LCI_fm_uf)

# Select resampled flows with explicit uncertainty for further stochastic modelling.
df_lci_fm_uf_s1a <- df_lci_fm_uf_s1  %>% 
  filter(titem == 4)

# Simulate LCI flows with reported uncertainty.

df_LCI_ifm_uf1 <- df_LCI_fm_uf %>%
  filter(!is.na(lower_limit)|!is.na(sd))

df_LCI_ifm_uf2 <- df_LCI_fm_uf %>%
  filter(is.na(lower_limit)&is.na(sd))

df_LCI_ifm_uf1$lower_limit <- ifelse(is.na(df_LCI_ifm_uf1$lower_limit),df_LCI_ifm_uf1$recommended_value*10000/(df_LCI_ifm_uf1$sd*1.96*10000),df_LCI_ifm_uf1$lower_limit*10000)/10000

df_LCI_ifm_uf1$upper_limit <- ifelse(is.na(df_LCI_ifm_uf1$upper_limit),df_LCI_ifm_uf1$recommended_value+(df_LCI_ifm_uf1$sd*1.96),df_LCI_ifm_uf1$upper_limit)


# Run internal Monte Carlo simulations.
set.seed(2025)
df_LCI_ifm_uf_s <- map_df(.x = 1:nrow(df_LCI_ifm_uf1),.f = function(x){
  
  df1 <- tibble(
    Id_sample = c(1:nsim),
    id_sim1 = df_LCI_ifm_uf1$id_sim1[x],
    id_sim = df_LCI_ifm_uf1$id_sim[x],
    lca = df_LCI_ifm_uf1$lca[x],
    key_sim = df_LCI_ifm_uf1$key_sim[x],
    n = df_LCI_ifm_uf1$n[x],
    titem = df_LCI_ifm_uf1$titem[x],
    recommended_value = rtriangle(n = nsim,
                      a = df_LCI_ifm_uf1$lower_limit[x],
                      b = df_LCI_ifm_uf1$upper_limit[x],
                      c = df_LCI_ifm_uf1$recommended_value[x])
  )
  
  return(df1)
  
})

# Retain flows with both inter-study and intra-study variability.
df_lci_fm_uf_s1_4 <- df_lci_fm_uf_s1 %>%
  filter(titem == 4) %>% 
  dplyr::select(Id_sample,id_sim1,id_sim,lca,key_sim)

df_LCI_ifm_uf_s_4 <- (filter(df_LCI_ifm_uf_s,titem == 4))

df_lci_fm_uf_s1_4 <- df_lci_fm_uf_s1_4 %>% 
  left_join(df_LCI_ifm_uf_s_4)


# Aggregate remaining inventory flows.

df_LCI_ifm_uf_s_3 <- df_LCI_ifm_uf_s %>% 
  filter(titem == 3)

df_LCI_ifm_uf_s_43 <- rbind(df_lci_fm_uf_s1_4,df_LCI_ifm_uf_s_3)

df_lci_fm_uf_s12 <- df_lci_fm_uf_s1 %>% 
  filter(titem < 3) %>% 
  dplyr::select(Id_sample,id_sim1,id_sim,lca,key_sim,n,titem,recommended_value)


df_lci_fm_uf_full <- rbind(df_LCI_ifm_uf_s_43,df_lci_fm_uf_s12)#


v_id_lci_fm_uf_item <- unique(df_lci_fm_uf_full$id_sim1)

df_lci_fm_uf_item_s <- map_df(.x = 1:nsim,.f = function(x){
  
  df1 <- tibble(Id_sample = x,
                id_sim1 = v_id_lci_fm_uf_item)
  
  return(df1)
})


df_lci_fm_uf_full_1 <- df_lci_fm_uf_full %>% 
  filter(titem == 1)

df_lci_fm_uf_full_1$Id_sample <- NULL

df_lci_fm_uf_item_s <- df_lci_fm_uf_item_s %>%
  left_join(df_lci_fm_uf_full_1) %>% 
  filter(!is.na(id_sim))


# Compile the full LCI dataset for agricultural stage at state level.
df_lci_fm_uf_item_s <- rbind(df_lci_fm_uf_item_s,filter(df_lci_fm_uf_full, titem != 1))


# On-field emissions in agricultural systems at the state level

df_lci_fm_uf_full <- df_lci_fm_uf_item_s%>% 
  separate(col = id_sim,into = c('state_code','type_activity_data2','activity_data1'),sep = '-',remove = T)

df_lci_fm_uf_full$id_sim1 <-NULL

df_lci_fm_uf_full1 <- df_lci_fm_uf_full %>% 
  filter(type_activity_data2 == 'fertiliser'|type_activity_data2 == 'soil_correctors'|type_activity_data2 == 'machinery')

df_lci_fm_uf_full1 <- df_lci_fm_uf_full1 %>% 
  left_join(df_oef_fer)

df_lci_fm_uf_full1 <- df_lci_fm_uf_full1 %>% 
  left_join(df_nc_cont)

df_lci_fm_uf_full1$N_content <- ifelse(is.na(df_lci_fm_uf_full1$N_content),0,df_lci_fm_uf_full1$N_content)
df_lci_fm_uf_full1$C_content <- ifelse(is.na(df_lci_fm_uf_full1$C_content),0,df_lci_fm_uf_full1$C_content)


df_lci_fm_uf_full1 <- df_lci_fm_uf_full1 %>% 
  mutate(NH3 = recommended_value*N_content*NH3_ef*17/14,
         N2O = ((recommended_value*N_content*(1-NH3_ef+NOx_ef)*N2Od_ef)+(recommended_value*N_content*(NH3_ef+NOx_ef)*N2Oi_ef))*44/28
  )

df_lci_fm_uf_full1$NOx <- ifelse(df_lci_fm_uf_full1$activity_data1 == 'Diesel',df_lci_fm_uf_full1$recommended_value*df_oef$recommeded_value[20],
                                 df_lci_fm_uf_full1$recommended_value*df_lci_fm_uf_full1$N_content*df_lci_fm_uf_full1$NOx_ef*46/14)

df_lci_fm_uf_full1$CO2 <- ifelse(df_lci_fm_uf_full1$activity_data1 == 'Diesel',df_lci_fm_uf_full1$recommended_value*df_oef$recommended_value[16],
                                 df_lci_fm_uf_full1$recommended_value*df_lci_fm_uf_full1$C_content*df_lci_fm_uf_full1$C_ef*44/12)

df_lci_fm_uf_full1$CO2_b <- ifelse(df_lci_fm_uf_full1$activity_data1 == 'Diesel',df_lci_fm_uf_full1$recommended_value*df_oef$recommended_value[17],0)
df_lci_fm_uf_full1$CO <- ifelse(df_lci_fm_uf_full1$activity_data1 == 'Diesel',df_lci_fm_uf_full1$recommended_value*df_oef$recommended_value[18],0)

df_lci_fm_uf_full1$SO2 <- ifelse(df_lci_fm_uf_full1$activity_data1 == 'Diesel',df_lci_fm_uf_full1$recommended_value*df_oef$recommended_value[22],0)

df_lci_fm_uf_full1$NMVOC <- ifelse(df_lci_fm_uf_full1$activity_data1 == 'Diesel',df_lci_fm_uf_full1$recommended_value*df_oef$recommended_value[21],0)
df_lci_fm_uf_full1$PM2.5 <- ifelse(df_lci_fm_uf_full1$activity_data1 == 'Diesel',df_lci_fm_uf_full1$recommended_value*df_oef$recommended_value[19],0)


df_lci_fm_uf_full1 <- df_lci_fm_uf_full1 %>% 
  dplyr::select(-(recommended_value:C_content))



# On_field impacts per UF

# Impacts from farming on-field emissions at the state level
# Farming on-field emissions at the state level

#df_lci_fm_uf_full1 <- read_parquet('R2025/LCI_onfield_em_farm_UF.parquet')#df21

df_lci_fm_uf_full1_c <-df_lci_fm_uf_full1 %>% #df21_c
  group_by(Id_sample,state_code,type_activity_data2) %>%
  summarise(N2O = sum(N2O),
            NOx = sum(NOx),
            NH3 = sum(NH3),
            CO2 = sum(CO2),
            CO2_b = sum(CO2_b),
            CO = sum(CO),
            #SO2 = sum(SO2),
            NMVOC = sum(NMVOC),
            PM2.5 = sum(PM2.5))


df_lci_fm_uf_full1_c <- df_lci_fm_uf_full1_c %>% 
  gather(key = 'substance_ac',value = 'value_emission',N2O:PM2.5)



# Farming LCA per region --------------------------------------------------

# Apply the same procedure at the regional level to cover municipalities
# that cannot be assigned state-level data.
# Compute summary statistics for each simulation ID (Id_sim) within each LCA.

df_LCI_fm_rg <- df_LCI_lt %>%
  filter(stage == 'Farming') %>%  
  group_by(region_name,type_activity_data3,key_sim,lca) %>% 
  summarise(recommended_value = sum(recommended_value,na.rm = T),
            lower_limit = sum(lower_limit,na.rm = T),
            upper_limit = sum(upper_limit,na.rm = T),
            sd = sum(sd,na.rm = T))

df_LCI_fm_rg$lower_limit <- ifelse(df_LCI_fm_rg$lower_limit == 0, NA,df_LCI_fm_rg$lower_limit)

df_LCI_fm_rg$upper_limit <- ifelse(df_LCI_fm_rg$upper_limit == 0, NA,df_LCI_fm_rg$upper_limit)

df_LCI_fm_rg$sd <- ifelse(df_LCI_fm_rg$sd == 0, NA,df_LCI_fm_rg$sd)


df_LCI_fm_rg <- df_LCI_fm_rg %>% 
  unite('id_sim',region_name,type_activity_data3,key_sim,sep = '-',remove = F)

df_LCI_fm_rg <- df_LCI_fm_rg %>% 
  unite('id_sim1',region_name,type_activity_data3,sep = '-',remove = F)


df_id_fm_rg <- tibble(id_sim1 =df_LCI_fm_rg$id_sim1,
                      lca = df_LCI_fm_rg$lca) %>% 
  unique()

df_id_fm_rg1 <- df_id_fm_rg %>% 
  group_by(id_sim1) %>% 
  summarise(n = n())

df_LCI_fm_rg <- df_LCI_fm_rg %>% 
  left_join(df_id_fm_rg1)


df_LCI_fm_rg$titem <- case_when((!is.na(df_LCI_fm_rg$lower_limit)|!is.na(df_LCI_fm_rg$sd))& df_LCI_fm_rg$n > 1 ~ 4,
                                (!is.na(df_LCI_fm_rg$lower_limit)|!is.na(df_LCI_fm_rg$sd)) & df_LCI_fm_rg$n == 1 ~ 3,
                                (is.na(df_LCI_fm_rg$lower_limit) & is.na(df_LCI_fm_rg$sd))& df_LCI_fm_rg$n > 1 ~ 2,
                                (is.na(df_LCI_fm_rg$lower_limit) & is.na(df_LCI_fm_rg$sd))& df_LCI_fm_rg$n == 1 ~ 1
)


# Select inventory flows with multiple sources for stochastic resampling.
df_id_fm_rg2 <- df_id_fm_rg1 %>% 
  filter(n>1)

set.seed(2025)
df_lci_fm_rg_s <- map_df(.x = 1:nrow(df_id_fm_rg2),.f = function(x){
  
  df1 <- df_id_fm_rg %>% 
    filter(id_sim1 == df_id_fm_rg2$id_sim1[x])
  

  df2 <- tibble(Id_sample = 1:nsim,
                id_sim1 = df_id_fm_rg2$id_sim1[x],
                rd = sample(x = 1:nrow(df1),size = nsim,replace = T),
                lca = df1$lca[rd])
  
  return(df2)
  
})

df_lci_fm_rg_s <- df_lci_fm_rg_s %>% 
  dplyr::select(-(rd))

df_lci_fm_rg_s <- df_lci_fm_rg_s %>% 
  left_join(df_LCI_fm_rg)


# Simulate LCI flows with reported uncertainty.

df_LCI_ifm_rg1 <- df_LCI_fm_rg %>%
  filter(!is.na(lower_limit)| !is.na(sd))

df_LCI_ifm_rg2 <- df_LCI_fm_rg %>%
  filter(is.na(lower_limit)&is.na(sd))

df_LCI_ifm_rg1$lower_limit <- ifelse(is.na(df_LCI_ifm_rg1$lower_limit),df_LCI_ifm_rg1$recommended_value*10000/(df_LCI_ifm_rg1$sd*1.96*10000),df_LCI_ifm_rg1$lower_limit*10000)/10000

df_LCI_ifm_rg1$upper_limit <- ifelse(is.na(df_LCI_ifm_rg1$upper_limit),df_LCI_ifm_rg1$recommended_value+(df_LCI_ifm_rg1$sd*1.96),df_LCI_ifm_rg1$upper_limit)


# Run internal Monte Carlo simulations.

set.seed(2025)
df_LCI_ifm_rg_s <- map_df(.x = 1:nrow(df_LCI_ifm_rg1),.f = function(x){
  
  df1 <- tibble(
    Id_sample = c(1:nsim),
    id_sim1 = df_LCI_ifm_rg1$id_sim1[x],
    id_sim = df_LCI_ifm_rg1$id_sim[x],
    #CD_UF = LCI_sim1$CD_UF[x],
    #Type_input2 = LCI_sim1$Type_input2[x],
    lca = df_LCI_ifm_rg1$lca[x],
    key_sim = df_LCI_ifm_rg1$key_sim[x],
    n = df_LCI_ifm_rg1$n[x],
    titem = df_LCI_ifm_rg1$titem[x],
    recommended_value = rtriangle(n = nsim,
                      a = df_LCI_ifm_rg1$lower_limit[x],
                      b = df_LCI_ifm_rg1$upper_limit[x],
                      c = df_LCI_ifm_rg1$recommended_value[x])
  )
  
  return(df1)
  
})


# Retain flows with both inter-study and intra-study variability.

df_lci_fm_rg_s1_4  <- df_lci_fm_rg_s %>%
  filter(titem == 4) %>% 
  dplyr::select(Id_sample,id_sim1,id_sim,lca,key_sim)


df_LCI_ifm_uf_s_4  <- (filter(df_LCI_ifm_rg_s,titem == 4))

df_lci_fm_rg_s1_4 <- df_lci_fm_rg_s1_4 %>% 
  left_join(df_LCI_ifm_uf_s_4)


# Aggregate remaining inventory flows.

df_lci_fm_rg_s1_2 <- df_lci_fm_rg_s %>%
  filter(titem < 3) %>% 
  dplyr::select(Id_sample,id_sim1,id_sim,lca,key_sim,n,titem,recommended_value)

df_lci_fm_rg_full <- rbind(df_lci_fm_rg_s1_4,df_lci_fm_rg_s1_2)

# On-field emissions in agricultural systems at the regional level

df_lci_fm_rg_full <- df_lci_fm_rg_full %>% 
  separate(col = id_sim,into = c('region_name','type_activity_data2','activity_data1'),sep = '-',remove = T)

df_lci_fm_rg_full$id_sim1 <- NULL

df_lci_fm_rg_full1 <- df_lci_fm_rg_full %>%
  filter(type_activity_data2 == 'fertiliser'|type_activity_data2 == 'soil_correctors'|type_activity_data2 == 'machinery')

df_lci_fm_rg_full1 <- df_lci_fm_rg_full1 %>% 
  left_join(df_oef_fer)


df_lci_fm_rg_full1 <- df_lci_fm_rg_full1 %>% 
  left_join(df_nc_cont)

df_lci_fm_rg_full1$N_content <- ifelse(is.na(df_lci_fm_rg_full1$N_content),0,df_lci_fm_rg_full1$N_content)
df_lci_fm_rg_full1$C_content <- ifelse(is.na(df_lci_fm_rg_full1$C_content),0,df_lci_fm_rg_full1$C_content)


df_lci_fm_rg_full1 <- df_lci_fm_rg_full1 %>% 
  mutate(NH3 = recommended_value*N_content*NH3_ef*17/14,
         N2O = ((recommended_value*N_content*(1-NH3_ef+NOx_ef)*N2Od_ef)+(recommended_value*N_content*(NH3_ef+NOx_ef)*N2Oi_ef))*44/28
  )

df_lci_fm_rg_full1$NOx <- ifelse(df_lci_fm_rg_full1$activity_data1 == 'Diesel',df_lci_fm_rg_full1$recommended_value*df_oef$recommended_value[20],
                                 df_lci_fm_rg_full1$recommended_value*df_lci_fm_rg_full1$N_content*df_lci_fm_rg_full1$NOx_ef*46/14)

df_lci_fm_rg_full1$CO2 <- ifelse(df_lci_fm_rg_full1$activity_data1 == 'Diesel',df_lci_fm_rg_full1$recommended_value*df_oef$recommended_value[16],
                                 df_lci_fm_rg_full1$recommended_value*df_lci_fm_rg_full1$C_content*df_lci_fm_rg_full1$C_ef*44/12)

df_lci_fm_rg_full1$CO2_b <- ifelse(df_lci_fm_rg_full1$activity_data1 == 'Diesel',df_lci_fm_rg_full1$recommended_value*df_oef$recommended_value[17],
                                   0)

df_lci_fm_rg_full1$CO <- ifelse(df_lci_fm_rg_full1$activity_data1 == 'Diesel',df_lci_fm_rg_full1$recommended_value*df_oef$recommended_value[18],0)

df_lci_fm_rg_full1$SO2 <- ifelse(df_lci_fm_rg_full1$activity_data1 == 'Diesel',df_lci_fm_rg_full1$recommended_value*df_oef$recommended_value[22],0)


df_lci_fm_rg_full1$NMVOC <- ifelse(df_lci_fm_rg_full1$activity_data1 == 'Diesel',df_lci_fm_rg_full1$recommended_value*df_oef$recommended_value[21],0)
df_lci_fm_rg_full1$PM2.5 <- ifelse(df_lci_fm_rg_full1$activity_data1 == 'Diesel',df_lci_fm_rg_full1$recommended_value*df_oef$recommended_value[19],0)

df_lci_fm_rg_full1 <- df_lci_fm_rg_full1 %>% 
  dplyr::select(-(recommended_value:C_content))


# Farming on-field emissions at the regional level

df_lci_fm_rg_full1_c <- df_lci_fm_rg_full1 %>% 
  group_by(Id_sample,region_name,type_activity_data2) %>% 
  summarise(N2O = sum(N2O),
            NOx = sum(NOx),
            NH3 = sum(NH3),
            CO2 = sum(CO2),
            CO2_b = sum(CO2_b),
            CO = sum(CO),
            SO2 = sum(SO2),
            NMVOC = sum(NMVOC),
            PM2.5 = sum(PM2.5))

df_lci_fm_rg_full1_c <- df_lci_fm_rg_full1_c %>% 
  gather(key = 'substance_ac',value = 'value_emission',N2O:PM2.5)


# 7.3 LCI for Processing  -------------------------------------------------------


# Apply the same procedure as in the farming stage,
# but assume inventory data to be representative at the national level.

df_LCI_pr <- df_LCI_lt %>%
  filter(type_activity_data2 == 'crushing') %>%  
  group_by(type_activity_data2,key_sim,lca) %>% 
  summarise(recommended_value = sum(recommended_value,na.rm = T),
            lower_limit = sum(lower_limit,na.rm = T),
            upper_limit = sum(upper_limit,na.rm = T),
            sd = sum(sd,na.rm = T))

df_LCI_pr$lower_limit <- ifelse(df_LCI_pr$lower_limit == 0, NA,df_LCI_pr$lower_limit)

df_LCI_pr$upper_limit <- ifelse(df_LCI_pr$upper_limit == 0, NA,df_LCI_pr$upper_limit)

df_LCI_pr$sd <- ifelse(df_LCI_pr$sd == 0, NA,df_LCI_pr$sd)

df_LCI_pr <- df_LCI_pr %>% 
  unite('id_sim',type_activity_data2,key_sim,sep = '-',remove = F)


df_id_pr <- tibble(type_activity_data2 =df_LCI_pr$type_activity_data2,
                   lca = df_LCI_pr$lca) %>% 
  unique()

df_id_pr1 <- df_id_pr %>% 
  group_by(type_activity_data2) %>% 
  summarise(n = n())

df_LCI_pr <- df_LCI_pr %>% 
  left_join(df_id_pr1)


df_LCI_pr$titem <- case_when((!is.na(df_LCI_pr$lower_limit)|!is.na(df_LCI_pr$sd))& df_LCI_pr$n > 1 ~ 4,
                             (!is.na(df_LCI_pr$lower_limit)|!is.na(df_LCI_pr$sd)) & df_LCI_pr$n == 1 ~ 3,
                             (is.na(df_LCI_pr$lower_limit) & is.na(df_LCI_pr$sd))& df_LCI_pr$n > 1 ~ 2,
                             (is.na(df_LCI_pr$lower_limit) & is.na(df_LCI_pr$sd))& df_LCI_pr$n == 1 ~ 1
)


# Select inventory flows with multiple sources for stochastic resampling. 
set.seed(2025)
df_lci_pr_s <- map_df(.x = 1:nrow(df_id_pr1),.f = function(x){
  
  df1 <- df_id_pr %>% 
    filter(type_activity_data2 == df_id_pr1$type_activity_data2[x])
  
  df2 <- tibble(Id_sample = 1:nsim,
                type_activity_data2 = df_id_pr1$type_activity_data2[x],
                rd = sample(x = 1:nrow(df1),size = nsim,replace = T),
                lca = df1$lca[rd])
  
  return(df2)
  
})

df_lci_pr_s <- df_lci_pr_s %>%
  dplyr::select(-(rd))


df_lci_pr_s <- df_lci_pr_s %>% 
  left_join(df_LCI_pr)


# Simulate LCI flows with reported uncertainty.

df_LCI_pr1 <- df_LCI_pr %>%
  filter(!is.na(lower_limit)| !is.na(sd))

df_LCI_pr1$lower_limit <- ifelse(is.na(df_LCI_pr1$lower_limit),df_LCI_pr1$recommended_value*10000/(df_LCI_pr1$sd*1.96*10000),df_LCI_pr1$lower_limit*10000)/10000

df_LCI_pr1$upper_limit <- ifelse(is.na(df_LCI_pr1$upper_limit),df_LCI_pr1$recommended_value+(df_LCI_pr1$sd*1.96),df_LCI_pr1$upper_limit)


# Run internal Monte Carlo simulations.
set.seed(2025)
df_LCI_ipr_s <- map_df(.x = 1:nrow(df_LCI_pr1),.f = function(x){
  
  df1 <- tibble(
    Id_sample = c(1:nsim),
    id_sim = df_LCI_pr1$id_sim[x],
    lca = df_LCI_pr1$lca[x],
    key_sim = df_LCI_pr1$key_sim[x],
    n = df_LCI_pr1$n[x],
    titem = df_LCI_pr1$titem[x],
    recommended_value = rtriangle(n = nsim,
                      a = df_LCI_pr1$lower_limit[x],
                      b = df_LCI_pr1$upper_limit[x],
                      c = df_LCI_pr1$recommended_value[x])
  )
  
  return(df1)
  
})


# Retain flows with both inter-study and intra-study variability.

df_lci_pr_s_4 <- df_lci_pr_s %>%
  filter(titem == 4) %>% 
  dplyr::select(Id_sample,id_sim,lca,key_sim)


df_LCI_ipr_s <- (filter(df_LCI_ipr_s,titem == 4))

df_lci_pr_s_4 <- df_lci_pr_s_4 %>% 
  left_join(df_LCI_ipr_s)


# Aggregate remaining inventory flows.

df_lci_pr_s_2 <- df_lci_pr_s %>% 
  filter(titem < 4) %>% 
  dplyr::select(Id_sample,id_sim,lca,key_sim,n,titem,recommended_value)

df_lci_pr_full <- rbind(df_lci_pr_s_4,df_lci_pr_s_2)

df_lci_pr_full$key_spread <- df_lci_pr_full$key_sim

# LCI data sourced from ecoinvent 3.11:
# 'soybean, feed production - RoW - soybean, feed',
# representing soy meal production directly from soybean grain.

v_twater_m <- 0.056 #kg tap water/ kg soy meal
v_electricity_m <- 0.025 # KwH/ kg soy meal
v_natural_gas_m <- 0.095/(10*4.184) # Convert energy data from MJ to m³ of gas per kg of soy meal.

df_pf1_pr <- tibble(id_sim = c('crushing-Electricity',
                               'crushing-Natural_Gas_High_Pressure',
                               'crushing-Tap_water'),
                    lca = 'Ecoinvent 3.11',
                    key_sim = c('Electricity',
                                'Natural_Gas_High_Pressure',
                                'Tap_water'),
                    n = 1,
                    titem = 1,
                    recommended_value = c(v_electricity_m,v_natural_gas_m,v_twater_m),
                    key_spread = c('Electricity_m',
                                   'Natural_Gas_High_Pressure_m',
                                   'Tap_water_m'))


df_pf1_pr <- df_pf1_pr %>% 
  rowwise() %>% 
  mutate(Id_sample = list(1:1000)) %>% 
  unnest(Id_sample)

df_pf1_pr <- df_pf1_pr %>% 
  dplyr::select(Id_sample,id_sim:key_spread)


df_lci_pr_full <- rbind(df_lci_pr_full,df_pf1_pr)


# Emissions in processing

df_lci_pr_full1 <- df_lci_pr_full %>% 
  filter(key_sim == 'Diesel')

df_lci_pr_full1$NOx <- df_lci_pr_full1$recommended_value*df_oef$recommended_value[20]
df_lci_pr_full1$CO2 <- df_lci_pr_full1$recommended_value*df_oef$recommended_value[16]
df_lci_pr_full1$CO2_b <- df_lci_pr_full1$recommended_value*df_oef$recommended_value[17]
df_lci_pr_full1$SO2 <- df_lci_pr_full1$recommended_value*df_oef$recommended_value[22]

df_lci_pr_full1$NMVOC <- df_lci_pr_full1$recommended_value*df_oef$recommended_value[21]
df_lci_pr_full1$PM2.5 <- df_lci_pr_full1$recommended_value*df_oef$recommended_value[19]

df_lci_pr_full1$recommended_value <- NULL


df_lci_pr_full1_c <- df_lci_pr_full1 %>% 
  group_by(Id_sample) %>% 
  summarise(NOx = sum(NOx),
            CO2 = sum(CO2),
            CO2_b = sum(CO2_b),
            SO2 = sum(SO2),
            NMVOC = sum(NMVOC),
            PM2.5 = sum(PM2.5))

df_lci_pr_full1_c <- df_lci_pr_full1_c %>% 
  gather(key = 'substance_ac',value = 'value_emission',NOx:PM2.5)


# 7.4 TRANSPORT DISTANCES  -------------------------------------------------------

# Domestic and international transport activity data (distances) were derived via 
# QGIS-based spatial analysis and are stored in an external file to be 
# integrated during the biodiversity impact assessment phase.

df_id_sch <- df_trase %>% 
  collect() %>% 
  group_by(region_code,region_name,state_code,state_name,municipality_code,municipality_name,export_port_code1,
           export_port_name_mo1,import_port_code,import_country_name,transport_type,year) %>% 
  summarise(soy_eq = sum(soy_eq),
            land_use = sum(land_use))


df_dom_dis <- read.xlsx(paths$x19) %>%
  dplyr::select(-(time_h)) %>% 
  rename(municipality_code = from_id,
         export_port_code1 = to_id,
         domestic_distance = distance_km)

df_dom_dis <- df_id_sch %>% 
  left_join(df_dom_dis) 


df_for_dis1 <- read.xlsx(paths$x20) %>% 
  dplyr::select(-c(port_imp,import_port_acronym))


df_for_dis2 <- read.xlsx(paths$x21)%>% 
  dplyr::select(-(time_h)) %>% 
  rename(export_port_code1 = from_id,
         import_country_name = to_id)

df_for_dis <- rbind(df_for_dis1,df_for_dis2)

df_for_dis <- df_for_dis %>% 
  rename(international_distance = distance_km) 


df_dis <- df_dom_dis %>% 
  left_join(df_for_dis)


# 8 IMPACT ASSESSMENT -----------------------------------------------------------------

df_cf_of_em <- read.xlsx(paths$x22)%>%
  filter(approach == 'All_effects_100yr')


df_bgp <- read.xlsx(paths$x23)%>% 
  filter(approach == 'All_effects_100yr') %>% 
  mutate(damage = ifelse(is.na(damage),impact_category,damage),
         impact = ifelse(impact_category == 'Ecotoxicity, terrestrial, average' & unit_impact == 'PDF.m3.d',
                         impact/(g_sl*fd),
                         ifelse(impact_category == 'Ecotoxicity, freshwater, average' & unit_impact == 'PDF.m3.d',
                                impact/(g_fw*fd),
                                ifelse(impact_category == 'Ecotoxicity, marine, average' & unit_impact == 'PDF.m3.d',
                                       impact/(g_sw*fd),impact))))


df_bgp$unit_impact <- ifelse(df_bgp$unit_impact == 'PDF.m3.d','PDF.year',df_bgp$unit_impact)

df_bgp <- df_bgp %>% 
  group_by(method,unit_impact,impact_category,damage,key_sim) %>% 
  summarise(impact = sum(impact))


id_cat <- tibble(method = df_bgp$method,
                 damage = df_bgp$damage) %>% 
  unique()

id_cat$id <- row_number(id_cat)

id_imp <- df_bgp %>% 
  dplyr::select(damage,impact_category,unit_impact) %>% 
  unique()


df_sch <- df_trase %>% 
  filter(municipality_code == mun,year == v_yr) %>% 
  dplyr::group_by(region_code,region_name,state_code,state_name,municipality_code,municipality_name,
                  export_port_name_mo1,export_port_code1,import_country_name,import_port_code,import_port_acronym,
                  economic_region,import_country_code,transport_type,year,dummy_uf_reg)%>% 
  summarise(soy_yield = mean(soy_yield),
            soy_eq = sum(soy_eq),
            soybean = sum(soybean),
            bean_meal = sum(bean_meal),
            cake = sum(cake),
            oil = sum(oil),
            land_use = sum(land_use),
            fob = sum(fob),
            sh_bean = mean(sh_bean),
            sh_meal = mean(sh_meal),
            sh_cake = mean(sh_cake),
            sh_oil = mean(sh_oil),
            sh_dcp = mean(double_cropping_share),
            dom_kmeal_af = mean(dom_kmeal_af),
            dom_oil_af = mean(dom_oil_af),
            for_kmeal_af = mean(for_kmeal_af),
            for_oil_af = mean(for_oil_af)
  ) 


id_imp$municipality_code <- mun

df_sch <- df_sch %>% 
  left_join(id_imp)


df_sch <- df_sch %>% 
  rowwise() %>% 
  mutate(Id_sample = list(1:nsim)) %>% 
  unnest(Id_sample)

# LULUC-related impacts

df_ld_r <- df_ld_r %>% 
  mutate(damage = 'Terrestrial ecosystems',
         impact_category = 'Land stress, TE, average'
         ) # Impacts reported on a per-hectare basis.

df_ld_r$occ <- NULL
df_ld_r$trans <- NULL
  

df_sch1 <- df_sch %>% 
  left_join(dplyr::select(df_ld_r,Id_sample:year,cf_occ_glo,cf_tra_glo_dc:impact_category)) %>% 
  rename(i_land_occupation = cf_occ_glo, 
         i_land_transformation = cf_tra_glo_dc)


# Impacts associated with carbon stock changes.

df_cst <- df_mun_luc_long %>% 
  left_join(df_cf_of_em) %>%
  mutate(imp = value_emission*value)%>%
  group_by(Id_sample,municipality_code,year,damage,impact_category,unit_impact,subc1) %>% 
  summarise(imp = sum(imp)) %>% 
  spread(key = subc1,value = imp) %>% 
  rename(i_luclu_above_biomass = ibmb,
         i_luclu_soc = iSOC)


df_sch1 <- df_sch1 %>% 
  left_join(df_cst)

df_sch1[is.na(df_sch1)] <- 0

# Impacts associated with farming and processing stages.
t1 <- tibble(type_activity_data2 = c('fertiliser','pesticide','soil_correctors',
                            'sowing','machinery'),
             type_activity_data0 = c('i_f_Fertilisation_pd','i_f_Pestcontrol_pd','i_f_Amendment_pd',
                             'i_f_Sowing_pd','i_f_Machinery_pd'))

df_ibg_fm_uf <- df_lci_fm_uf_full %>% 
  dplyr::select(Id_sample,state_code,type_activity_data2,key_sim,recommended_value) %>% 
  left_join(df_bgp)

df_ibg_fm_uf$impact <- df_ibg_fm_uf$impact*df_ibg_fm_uf$recommended_value

df_ibg_fm_uf <- df_ibg_fm_uf %>% 
  group_by(Id_sample,state_code,type_activity_data2,method,impact_category,unit_impact,damage) %>% 
  summarise(i_frm = sum(impact)) %>% 
  filter(!is.na(i_frm))


df_ibg_fm_uf <- df_ibg_fm_uf %>% 
  left_join(t1)


df_iof_fm_uf <- df_lci_fm_uf_full1_c %>% 
  left_join(df_cf_of_em) 


df_iof_fm_uf$impact <- df_iof_fm_uf$value_emission*df_iof_fm_uf$value

df_iof_fm_uf <- df_iof_fm_uf %>% 
  group_by(Id_sample,state_code,type_activity_data2,method,impact_category,unit_impact,damage) %>% 
  summarise(i_frm = sum(impact))

t2 <- tibble(type_activity_data2 = c('fertiliser','pesticide','soil_correctors',
                            'sowing','machinery'),
             type_activity_data0 = c('i_f_Fertilisation_of','i_f_Pestcontrol_of','i_f_Amendment_of',
                             'i_f_Sowing_of','i_f_Machinery_of'))

df_iof_fm_uf <-  df_iof_fm_uf %>% 
  left_join(t2)


df_ifm_uf <- rbind(df_ibg_fm_uf,df_iof_fm_uf)

df_ifm_uf$type_activity_data2 <- NULL

df_ifm_uf <- df_ifm_uf %>% 
  spread(key = type_activity_data0,value = i_frm) %>% 
  mutate(dummy_uf_reg = 'uf') %>% 
  mutate_at(vars(state_code),as.double)

df_ifm_uf <- df_ifm_uf %>% 
  filter(!is.na(method))

df_ifm_uf[is.na(df_ifm_uf)] <- 0


df_ibg_fm_rg <- df_lci_fm_rg_full %>%
  dplyr::select(Id_sample,region_name,type_activity_data2,key_sim,recommended_value) %>% 
  left_join(df_bgp)

df_ibg_fm_rg$impact <- df_ibg_fm_rg$impact*df_ibg_fm_rg$recommended_value

df_ibg_fm_rg <- df_ibg_fm_rg %>% 
  group_by(Id_sample,region_name,type_activity_data2,method,impact_category,unit_impact,damage) %>% 
  summarise(i_frm = sum(impact)) %>% 
  filter(!is.na(i_frm))

df_ibg_fm_rg <- df_ibg_fm_rg %>% 
  left_join(t1)

# Regional emissions

df_iof_fm_rg <- df_lci_fm_rg_full1_c %>% 
  left_join(df_cf_of_em)

df_iof_fm_rg$impact <- df_iof_fm_rg$value_emission*df_iof_fm_rg$value

df_iof_fm_rg <- df_iof_fm_rg %>% 
  group_by(Id_sample,region_name,type_activity_data2,method,impact_category,unit_impact,damage) %>% 
  summarise(i_frm_of = sum(impact)) %>% 
  filter(!is.na(i_frm_of))


df_iof_fm_rg <-  df_iof_fm_rg %>% 
  left_join(t2)


df_ifm_rg <- rbind(df_ibg_fm_rg,df_iof_fm_rg)

df_ifm_rg$type_activity_data2 <- NULL

df_ifm_rg <- df_ifm_rg %>% 
  spread(key = type_activity_data0,value = i_frm) %>% 
  mutate(dummy_uf_reg = 'rg')


df_ifm_rg[is.na(df_ifm_rg)] <- 0



if(any(df_sch1$dummy_uf_reg == 'uf')){
  
  df_sch1 <- df_sch1 %>%
    left_join(df_ifm_uf)
}else{
  df_sch1 <- df_sch1 %>% 
    left_join(df_ifm_rg)
}

# Processing


# From Processing back ground processes


t2 <- tibble(type_activity_data2 = c('Hexane','Tap_water','Diesel',
                            'Natural_Gas_High_Pressure','Hardwood_Chips_From_Forest',
                            'Natural_Gas_High_Pressure_m','Tap_water_m'),
             type_activity_data0 = c('i_p_Hexane_pd','i_p_Tapwater_pd','i_p_diesel_pd',
                             'i_p_Naturalgas_pd','i_p_heat_from_wood_pd','i_p_Naturalgas_m_pd',
                             'i_p_Tapwater_m_pd'))


df_ibg_pr1 <- df_lci_pr_full %>%
  filter(key_sim != 'Electricity') %>% 
  left_join(df_bgp)

df_ibg_pr1$i_pr_netr <- df_ibg_pr1$impact*df_ibg_pr1$recommended_value

df_ibg_pr1 <- df_ibg_pr1%>%
  dplyr::select(Id_sample,key_spread,method,impact_category,unit_impact,i_pr_netr,damage) %>% 
  rename(type_activity_data2 = key_spread)


df_ibg_pr1 <- df_ibg_pr1 %>% 
  left_join(t2)

df_ibg_pr1$type_activity_data2 <- NULL

df_ibg_pr1 <- df_ibg_pr1 %>% 
  spread(key = type_activity_data0,value = i_pr_netr)

df_ibg_pr1[is.na(df_ibg_pr1)] <- 0



df_bgp_elet <- df_bgp %>% 
  filter(grepl('Electricity_Low_Voltage_voltage',key_sim,ignore.case = T))

df_bgp_elet$key_sim1 <- 'Electricity'

df_ibg_pr2 <- df_lci_pr_full %>%
  filter(key_sim == 'Electricity') %>%
  rename(key_sim1 = key_sim) %>% 
  left_join(df_bgp_elet)

df_ibg_pr2$region_name <- ifelse(df_ibg_pr2$key_sim == 'Electricity_Low_Voltage_voltage_BR_Mid_western','Mid_western',
                            ifelse(df_ibg_pr2$key_sim == 'Electricity_Low_Voltage_voltage_BR_Northern','Northern',
                                   ifelse(df_ibg_pr2$key_sim == 'Electricity_Low_Voltage_voltage_BR_North_eastern','North_eastern',
                                          ifelse(df_ibg_pr2$key_sim == 'Electricity_Low_Voltage_voltage_BR_South_eastern','South_eastern',
                                                 'Southern'))))


df_ibg_pr2$impact <- df_ibg_pr2$impact*df_ibg_pr2$recommended_value

df_ibg_pr2 <- df_ibg_pr2 %>%
  rename(type_activity_data2 = key_spread) %>% 
  group_by(Id_sample,region_name,type_activity_data2,method,impact_category,unit_impact,damage) %>% 
  summarise(i_pr_etr = sum(impact))

df_ibg_pr2 <- df_ibg_pr2 %>% 
  spread(key = type_activity_data2,value = i_pr_etr)

df_ibg_pr2 <- df_ibg_pr2 %>% 
  rename(i_p_electricity_pd = Electricity,
         i_p_electricity_m_pd = Electricity_m)


# on-field emissions

df_lci_pr_full1_c <- df_lci_pr_full1_c %>% 
  left_join(df_cf_of_em)

df_lci_pr_full1_c$impact <- df_lci_pr_full1_c$value_emission*df_lci_pr_full1_c$value

df_lci_pr_full1_c <- df_lci_pr_full1_c %>% 
  group_by(Id_sample,method,impact_category,unit_impact,damage) %>% 
  summarise(i_p_fuel_combustion_of = sum(impact)) %>% 
  filter(!is.na(i_p_fuel_combustion_of))


df_sch1 <- df_sch1 %>% 
  left_join(df_ibg_pr1) %>% 
  left_join(df_ibg_pr2) %>% 
  left_join(df_lci_pr_full1_c)


# Transportation

df_dis <- df_dis %>% 
  filter(municipality_code == mun)

df_dis1 <- df_dis %>% 
  gather(key = 'stage',value = 'value',domestic_distance:international_distance)

df_dis1$key_sim <- ifelse(df_dis1$stage == 'domestic_distance','Transport_Freight_Lorry_32_EURO5',
                         'Transport_Freight_Sea')

df_dis1 <- df_dis1 %>% 
  left_join(df_bgp)

df_dis1 <- df_dis1 %>% 
  mutate(impact = impact*value) %>% 
  dplyr::select(region_code:year,stage,method:damage,impact)

df_dis1 <- df_dis1 %>% 
  spread(key = stage,value = impact)# El impacto de la distancia está dado solo por la distancia recorrida


df_dis1[is.na(df_dis1)] <- 0


df_dis1 <- df_dis1 %>% 
  rename(i_domestic_transport = domestic_distance,
         i_international_transport = international_distance)

df_sch1 <- df_sch1 %>% 
  left_join(df_dis1)


df_sch1[is.na(df_sch1)] <- 0

df_sch1 <- df_sch1 %>% 
  dplyr::select(Id_sample,region_code:unit_impact,i_land_occupation:i_p_Hexane_pd,
                i_p_Naturalgas_pd,i_p_Tapwater_pd,i_p_electricity_pd,
                i_p_fuel_combustion_of,i_p_Naturalgas_m_pd,i_p_Tapwater_m_pd,
                i_p_electricity_m_pd,i_domestic_transport,i_international_transport)


# Reference units applied: transport (per tonne of product), farming and processing 
# (per kg of generic soybean), and land use (per hectare).

# Methodological note: Carbon stock change and limestone impacts currently exclude 
# double-cropping adjustments, whereas land transformation impacts include them.

# Data processing: soy_eq results require subsequent adjustment for crushing factors.


df_sch1 <- df_sch1 %>% 
  mutate(across(i_f_Amendment_of:i_p_electricity_m_pd,~tkgf*.x))


# Accounting for double-cropping practices.
df_sch1 <- df_sch1 %>% 
  mutate(across(c(i_f_Amendment_of,i_f_Amendment_pd,i_luclu_above_biomass,i_luclu_soc),~.x-(.x*sh_dcp*fsoy_occ)))

# Normalise LULUC, land transformation, and land occupation results to impact per tonne of generic soybean.
df_sch1 <- df_sch1 %>% 
  mutate(across(i_land_occupation:i_luclu_soc,~.x*land_use/soy_eq))


# Impacts quantified for the traded soy-eq volume.

df_sch_soy_eq <- df_sch1 %>% 
  mutate(across(c(i_p_diesel_pd:i_p_fuel_combustion_of),~.x*(sh_cake+sh_oil))) %>% 
  filter(soy_eq != 0)

df_sch_soy_eq <- df_sch_soy_eq %>% 
  mutate(across(c(i_p_Naturalgas_m_pd:i_p_electricity_m_pd),~.x*sh_meal))


df_sch_soy_eq <- df_sch_soy_eq %>% 
  mutate(i_p_electricity_pd = i_p_electricity_pd+i_p_electricity_m_pd,
         i_p_Tapwater_pd = i_p_Tapwater_pd+i_p_Tapwater_m_pd,
         i_p_Naturalgas_pd = i_p_Naturalgas_pd+i_p_Naturalgas_m_pd) %>% 
  dplyr::select(-c(soybean:oil,sh_bean:sh_oil,dom_kmeal_af:for_oil_af,i_p_Naturalgas_m_pd,i_p_electricity_m_pd,i_p_Tapwater_m_pd))

df_sch_soy_eq <- df_sch_soy_eq %>% 
  mutate(across(i_land_occupation:i_international_transport,~.x*soy_eq))

t1_n <- colnames(df_sch_soy_eq)

cs_t1 <- t1_n[which(t1_n == "i_land_occupation") : which(t1_n == "i_international_transport")]


cs_t1e <- paste(cs_t1, collapse = " + ")

df_sch_soy_eq <- df_sch_soy_eq %>% 
  mutate(impact = !!parse_expr(cs_t1e),
         impact_ton = impact/soy_eq)

# Impacts quantified for the traded soybeans volume.

df_sch_soybeans <- df_sch1 %>% 
  dplyr::select(-c(soy_eq,bean_meal:oil,sh_meal:sh_oil,dom_kmeal_af:for_oil_af,i_p_diesel_pd:i_p_electricity_m_pd)) %>% 
  filter(soybean != 0)

df_sch_soybeans <- df_sch_soybeans %>% 
  mutate(across(i_land_occupation:i_international_transport,~.x*soybean))

t2_n <- colnames(df_sch_soybeans)

cs_t2 <- t2_n[which(t2_n == "i_land_occupation") : which(t2_n == "i_international_transport")]


cs_t2e <- paste(cs_t2, collapse = " + ")

df_sch_soybeans <- df_sch_soybeans %>% 
  mutate(impact = !!parse_expr(cs_t2e),
         impact_ton = impact/soybean)

# Impacts quantified for the traded meal from beans volume.

df_sch_symeal_beans <- df_sch1 %>% 
  dplyr::select(-c(soy_eq,soybean,cake,oil,sh_bean:sh_oil,dom_kmeal_af:for_oil_af,
                   i_p_diesel_pd:i_p_fuel_combustion_of)) %>% 
  filter(bean_meal != 0)

df_sch_symeal_beans <- df_sch_symeal_beans %>% 
  mutate(across(i_land_occupation:i_international_transport,~.x*bean_meal))

t3_n <- colnames(df_sch_symeal_beans)

cs_t3 <- t3_n[which(t3_n == "i_land_occupation") : which(t3_n == "i_international_transport")]

cs_t3e <- paste(cs_t3, collapse = " + ")

df_sch_symeal_beans <- df_sch_symeal_beans %>% 
  mutate(impact = !!parse_expr(cs_t3e),
         impact_ton = impact/bean_meal)
  

# Impacts quantified for the traded so cake volume.
df_sch_soy_cake <- df_sch1 %>% 
  dplyr::select(-c(soy_eq:bean_meal,oil:sh_meal,sh_oil,dom_oil_af,for_oil_af,
                   i_p_Naturalgas_m_pd,i_p_Tapwater_m_pd,i_p_electricity_m_pd)) %>% 
  filter(cake != 0)

df_sch_soy_cake <- df_sch_soy_cake %>% 
  mutate(across(i_land_occupation:i_international_transport,~(ifelse(import_country_name == 'BRAZIL',dom_kmeal_af,for_kmeal_af)*.x/f_sh_meal_mass)*cake))

t4_n <- colnames(df_sch_soy_cake)

cs_t4 <- t4_n[which(t4_n == "i_land_occupation") : which(t4_n == "i_international_transport")]


cs_t4e <- paste(cs_t4, collapse = " + ")

df_sch_soy_cake <- df_sch_soy_cake %>% 
  mutate(impact = !!parse_expr(cs_t4e),
         impact_ton = impact/cake)

# Impacts quantified for the traded soy oil volume.

df_oil <- df_sch1 %>% 
  dplyr::select(-c(soy_eq:cake,sh_bean:sh_meal,dom_kmeal_af,for_kmeal_af,
                   i_p_Naturalgas_m_pd,i_p_Tapwater_m_pd,i_p_electricity_m_pd)) %>% 
  filter(oil != 0)

df_oil <- df_oil %>% 
  mutate(across(i_land_occupation:i_international_transport,~(ifelse(import_country_name == 'BRAZIL',dom_oil_af,for_oil_af)*.x/f_sh_oil_mass)*oil))

t5_n <- colnames(df_oil)

cs_t5 <- t5_n[which(t5_n == "i_land_occupation") : which(t5_n == "i_international_transport")]

cs_t5e <- paste(cs_t5, collapse = " + ")

df_oil <- df_oil %>% 
  mutate(impact = !!parse_expr(cs_t5e),
         impact_ton = impact/oil)

# Export estimated impacts.

#write_parquet(db_sh1,paste0('R2025/imp1/syeq_',mun,'.parquet'))
#write_parquet(db_sh2,paste0('R2025/imp1/sygr_',mun,'.parquet'))
#write_parquet(db_sh3,paste0('R2025/imp1/symgr_',mun,'.parquet'))
#write_parquet(db_sh4,paste0('R2025/imp1/symck_',mun,'.parquet'))
#write_parquet(db_sh5,paste0('R2025/imp1/syol_',mun,'.parquet'))



# #End of the code --------------------------------------------------------


