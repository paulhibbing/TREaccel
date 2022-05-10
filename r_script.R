## PURPOSE: This script is derived from the code chunks on the web page
## (paulhibbing.github.io/TREaccel) and vignette
## (https://github.com/paulhibbing/TREaccel/raw/main/Vignette.pdf).
## Users might find that this format is easier to use interactively, with the
## tradeoff that it doesn't have all the added commentary. This code could be
## directly adapted into the sorts of functions/loops referenced on the web page
## and in the vignette.

# Check that dependencies are installed -----------------------------------

  ## This code only needs to be run the first time you use this script

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


# Get set up --------------------------------------------------------------

  rm(list = ls())
  library(magrittr)


# Read/format a sample file -----------------------------------------------

  # This will retrieve the existing sample file from the read.gt3x package
  sample_file <- system.file(
    "extdata/TAS1H30182785_2019-09-17.gt3x",
    package = "read.gt3x"
  )

  # Your own file might look like this:
  # my_file <- "C:/users/myusername/Desktop/myfile.gt3x"

  # Read the raw acceleration data (30+ Hz) and make sure timestamps
  # are in UTC timezone -- Store this in an object called `AG`
  accel <-
    read.gt3x::read.gt3x(sample_file, FALSE, TRUE, TRUE) %>%
    dplyr::mutate(time = lubridate::force_tz(time, "UTC"))

  # Convert to activity counts (60-s epochs) and make sure timestamps
  # are in UTC timezone; store this in a separate object called `counts`
  # (The call to `slice` is needed because `calculate_counts` adds zeroes to the
  # end of the file based on when the monitor was downlodaed, whereas `read.gt3x`
  # does not)
  AG <-
    agcounts::calculate_counts(accel, 60, tz = "UTC") %>%
    dplyr::slice(which(time <= dplyr::last(accel$time))) %>%
    dplyr::mutate(filename = basename(sample_file)) %>%
    dplyr::relocate(filename)


# Get minute-by-minute energy expenditure ---------------------------------

  accel %<>%
    # Calculate ENMO, in milli-G
      dplyr::mutate(
        ENMO = {sqrt(X^2 + Y^2 + Z^2) - 1} %>% pmax(0) %>% {. * 1000}
      ) %>%
    # Average each second
      dplyr::group_by(time = lubridate::floor_date(time, "1 second")) %>%
      dplyr::summarise(dplyr::across(.fns = mean), .groups = "drop") %>%
    # Calculate VO2
      dplyr::mutate(VO2 = {ENMO ^ .534} %>% {0.901 * .} %>% pmax(3, .)) %>%
    # Average each minute
      dplyr::group_by(time = lubridate::floor_date(time, "1 minute")) %>%
      dplyr::summarise(dplyr::across(.fns = mean), .groups = "drop") %>%
    # Convert to kcal/kg/min
      dplyr::mutate(
        kcal_kg_min =
          (VO2 / 1000) *
          PAutilities::get_kcal_vo2_conversion(RER = 0.85, kcal_table = "Lusk")
      ) %>%
    # Retain only the relevant variables
      dplyr::select(time, kcal_kg_min)


# Get minute-by-minute non-wear and merge with energy expenditure data ----

  AG %<>%
    # Non-wear processing
      PhysicalActivity::wearingMarking(
        TS = "time", cts = "Axis1", perMinuteCts = 1, tz = "UTC"
      ) %>%
    # Formatting
      dplyr::mutate(is_nonwear = !wearing %in% "w") %>%
      dplyr::select(-c(wearing, weekday, days)) %>%
    # Merging
      merge(accel) %T>%
    {rm(accel, envir = globalenv())}


# Calculate daily totals --------------------------------------------------

  AG %<>%
    dplyr::group_by(filename, time = as.Date(time)) %>%
    dplyr::mutate(dplyr::across(
      !dplyr::all_of("is_nonwear"),
      .fns = ~ ifelse(is_nonwear | is.na(.x), 0, .x)
    )) %>%
    dplyr::summarise(
      dplyr::across(.fns = sum),
      total_mins = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::rename(nonwear_mins = is_nonwear, date = time, kcal_kg = kcal_kg_min) %>%
    dplyr::relocate(filename, date, total_mins, nonwear_mins)


# Apply compliance checks and filter out non-compliant data ---------------

  maximum_nonwear_mins <- 10
  minimum_days <- 1

  AG %<>%
    dplyr::group_by(filename) %>%
    dplyr::mutate(
      day_compliant = nonwear_mins < maximum_nonwear_mins,
      participant_compliant = sum(day_compliant) >= minimum_days
    ) %>%
    dplyr::filter(day_compliant & participant_compliant)


# Determine total daily energy expenditure --------------------------------

  ## Suppose demographic information is available in a data frame like this
    demo <- data.frame(
      filename = basename(sample_file), sex = "M",
      ht_m = 1.80, wt_kg = 75, age = 30
    )

  ## Then we can predict BMR like this:
    demo$basal_kcal_day <- PAutilities::get_ree(
      df = demo, method = "schofield_wt_ht", sex = "sex", age_yr = "age",
      wt_kg = "wt_kg", ht_m = "ht_m", output = "kcal_day", RER = 0.85,
      kcal_table = "Lusk"
    )

  ## Now we can pull all the pieces together into
  ## a final estimate of energy expenditure
    EE <-
      # Start by merging the demographic and accelerometer data
        merge(demo, AG) %>%
      # Then determine how many kcal to impute during non-wear minutes
      # (NB: The number of minutes in a full day is 24*60 = 1440)
        dplyr::mutate(
          basal_kcal_day = round(basal_kcal_day),
          nonwear_kcal = basal_kcal_day*(nonwear_mins / 1440),
          wear_kcal = kcal_kg * wt_kg,
          total_kcal = nonwear_kcal + wear_kcal,
          kcal_kg = NULL
        ) %>%
      # Remove the activity count totals for simplicity
        dplyr::select(!dplyr::matches("^[AV][xe]")) %>%
      # Reorder the variables
        dplyr::relocate(participant_compliant, day_compliant, .after = basal_kcal_day) %T>%
      # Remove obsolete sensor data object
        {rm(AG, envir = globalenv())}


# Calculate energy intake -------------------------------------------------

  # Suppose the energy storage (ES) data look like this
  # (reflecting a 100 kcal/day surplus):
    ES <- data.frame(filename = basename(sample_file), ES = 100)

  ## Then we can calculate energy intake (EI) like so:
    intake <-
      merge(EE, ES) %>%
      dplyr::rename(EE = total_kcal) %>%
      dplyr::mutate(
        ES = round(ES),
        EE = round(EE),
        EI = ES + EE
      ) %>%
      dplyr::select(
        dplyr::all_of(names(demo)),
        total_mins, nonwear_mins, ES, EE, EI
      )

    View(intake)

