A good first procedure is to assemble the minute-by-minute dataset.
We will do this using the string of commands below. They are interspersed
with comments to show what every couple of commands are doing.

```
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
```
