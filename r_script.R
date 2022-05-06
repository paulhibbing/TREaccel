rm(list = ls())

# setup.md ----------------------------------------------------------------

  dependencies <- c(
    "magrittr", "dplyr", "remotes", "Rcpp", "R.utils",
    "tools", "lubridate", "PAutilities", "data.table",
    "gsignal", "zoo"
  )
  
  sapply(
    dependencies,
    function(x) if (!x %in% installed.packages()) install.packages(x)
  )
  
  if (!"read.gt3x" %in% installed.packages()) remotes::install_github(
    "THLfi/read.gt3x", dependencies = FALSE
  )

  if (!"agcounts" %in% installed.packages()) remotes::install_github(
    "paulhibbing/agcounts", dependencies = FALSE
  )
  
# read.md -----------------------------------------------------------------

  library(magrittr)

  # Use the sample file that comes with `read.gt3x`
  sample_file <- system.file(
    "extdata/TAS1H30182785_2019-09-17.gt3x",
    package = "read.gt3x"
  )
  
  # Your own file might look like this:
  # my_file <- "C:/users/myusername/Desktop/myfile.gt3x"

  # Read the raw acceleration data (30+ Hz) and make sure
  # timestamps are in UTC timezone
  AG <-
    read.gt3x::read.gt3x(sample_file, FALSE, TRUE, TRUE) %>%
    mutate(time = lubridate::force_tz(time, "UTC"))
  
  # Convert to activity counts (60-s epochs) and make sure
  # timestamps are in UTC timezone
  counts <-
    agcounts::get_counts(sample_file, attr(AG, "sample_rate"), 60) %>%
    mutate(time = lubridate::force_tz(time, "UTC"))

# collapse.md -------------------------------------------------------------

  library(magrittr)
  library(dplyr)
  
  ## This is one big string of successive commands, but they're
  ## interspersed with comments to show what each command is doing
  
  ee_data_minute <-
    
    # Start with the data we loaded before
    AG %>%
      
    # Calculate ENMO and second-by-second averages
    group_by(time = lubridate::floor_date(time)) %>%
    mutate(ENMO = pmax(0, sqrt(X^2+Y^2+Z^2)-1)) %>%
    summarise(across(everything(), mean)) %>%
      
    # Calculate VO2 and minute-by-minute averages
    mutate(
      VO2_mlkgmin = pmax(3, 0.901*(ENMO^0.534)),
      kcal_kgmin = (VO2_mlkgmin/1000)*PAutilities::get_kcal_vo2_conversion(0.85, "Lusk")
    ) %>%
    group_by(time = lubridate::floor_date(time, "minutes")) %>%
    summarise(
      across(everything(), mean),
      n = n()
    ) %>%
    
    # Remove partial minutes
    filter(n == 60) %>%
    select(-n) %>%
    
    # Combine with the activity count data that is already in 60-s epochs
    merge(counts, .)
  