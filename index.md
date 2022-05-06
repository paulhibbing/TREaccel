## TREaccel

Thanks for your interest in sample R code for running our accelerometer method for time restricted eating trials. We recognize that coding can be hard no matter your experience level, and that it's especially intimidating if you're just getting started. We want this resource to make it easier. If it's not working for you, please let us know by [filing an issue](https://github.com/paulhibbing/TREaccel/issues/new/choose). This is a convenient way for us to discuss what's not working and find a way to fix it, while doing so in a visible way that will also help others who have the same questions.

[Click here if you want to view all of this code in a single R script format.](https://raw.githubusercontent.com/paulhibbing/TREaccel/main/r_script.R)

Otherwise, we'll walk you through things below.

## Prerequisites

Before moving forward with any other code, you need to (once only) check the following boxes to get set up:

1. [Install R](https://www.r-project.org/) (required) and [RStudio](https://www.rstudio.com/products/rstudio/download/) (optional)
2. Make sure you have the necessary R packages installed. To do that, open up R, paste the following code, and hit `enter` to execute:

```
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
```

## Reading in your data

Next, you'll need to read some data.

```
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
  agcounts::get_counts(sample_file, 60) %>%
  mutate(time = lubridate::force_tz(time, "UTC"))
```
