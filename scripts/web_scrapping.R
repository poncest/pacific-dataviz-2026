
# pacific_datahub_saved_pages_with_descriptions.R

library(rvest)
library(tidyverse)
library(glue)

files <- sprintf("page-%02d.html", 1:11)

missing_files <- files[!file.exists(files)]

if (length(missing_files) > 0) {
  stop(
    "These files are missing:\n",
    paste(missing_files, collapse = "\n")
  )
}

extract_datasets <- function(file) {
  
  message("Reading ", file)
  
  html <- read_html(file)
  
  items <- html |>
    html_elements("li.dataset-item")
  
  tibble(
    source_file = file,
    title = items |>
      html_element(".dataset-heading a") |>
      html_text2(),
    href = items |>
      html_element(".dataset-heading a") |>
      html_attr("href"),
    description = items |>
      html_element(".dataset-content > div") |>
      html_text2()
  ) |>
    mutate(
      title = str_squish(title),
      description = str_squish(description),
      url = if_else(
        str_starts(href, "http"),
        href,
        paste0("https://pacificdata.org", href)
      )
    ) |>
    filter(
      !is.na(title),
      title != "",
      !is.na(url)
    ) |>
    select(source_file, title, description, url)
}

datasets <- map_dfr(files, extract_datasets) |>
  distinct(title, url, .keep_all = TRUE) |>
  arrange(title)

message("Datasets found: ", nrow(datasets))

print(datasets, n = 50)

write_csv(datasets, "pacific_climate_datasets_with_descriptions.csv")

datasets |> 
  count(
    category = case_when(
      str_detect(description, regex("fisher|ocean|marine", TRUE)) ~ "Marine/Fisheries",
      str_detect(description, regex("agric|crop|food", TRUE)) ~ "Agriculture/Food",
      str_detect(description, regex("road|bridge|building|infrastructure", TRUE)) ~ "Infrastructure",
      str_detect(description, regex("flood|cyclone|hazard|risk", TRUE)) ~ "Disaster Risk",
      str_detect(description, regex("climate|temperature|rainfall", TRUE)) ~ "Climate",
      TRUE ~ "Other"
    )
  )

datasets |> 
  mutate(
    category = case_when(
      
      str_detect(
        description,
        regex("fisher|ocean|marine|coral|reef|coast|bathymetry", TRUE)
      ) ~ "Marine/Fisheries",
      
      str_detect(
        description,
        regex("agric|crop|food|forest|vegetation|soil", TRUE)
      ) ~ "Agriculture/Environment",
      
      str_detect(
        description,
        regex("road|bridge|building|fuel|infrastructure|transport|airport|port", TRUE)
      ) ~ "Infrastructure",
      
      str_detect(
        description,
        regex("flood|cyclone|hazard|risk|disaster|exposure|vulnerability", TRUE)
      ) ~ "Disaster Risk",
      
      str_detect(
        description,
        regex("climate|temperature|rainfall|precipitation|weather|drought", TRUE)
      ) ~ "Climate",
      
      str_detect(
        description,
        regex("population|settlement|household|community|demographic", TRUE)
      ) ~ "Population/Society",
      
      str_detect(
        description,
        regex("elevation|terrain|topography|land cover|gis|satellite", TRUE)
      ) ~ "Spatial/Environmental",
      
      TRUE ~ "Other"
    )
  ) |>
  count(category, sort = TRUE)

datasets |> 
  mutate(
    text = str_to_lower(
      paste(title, description)
    ),
    
    category = case_when(
      
      str_detect(
        text,
        "fisher|ocean|marine|reef|coral|coast|bathymetry"
      ) ~ "Marine/Fisheries",
      
      str_detect(
        text,
        "agric|crop|food|forest|vegetation|soil"
      ) ~ "Agriculture/Environment",
      
      str_detect(
        text,
        "road|bridge|building|fuel|infrastructure|transport|airport|port"
      ) ~ "Infrastructure",
      
      str_detect(
        text,
        "flood|cyclone|hazard|risk|disaster|exposure|vulnerability"
      ) ~ "Disaster Risk",
      
      str_detect(
        text,
        "climate|temperature|rainfall|precipitation|weather|drought"
      ) ~ "Climate",
      
      str_detect(
        text,
        "population|settlement|household|community|demographic"
      ) ~ "Population/Society",
      
      str_detect(
        text,
        "elevation|terrain|topography|land cover|gis|satellite"
      ) ~ "Spatial/Environmental",
      
      TRUE ~ "Other"
    )
  ) |>
  count(category, sort = TRUE)


