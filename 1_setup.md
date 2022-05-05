## Getting Set Up

In order for the coding example to run, you need to have some R packages installed.
The code below will help you do that. It only needs to be run one time (i.e., the first
time you are trying to use the sample code).

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
