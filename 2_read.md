To read an ActiGraph file, here is some code you can run:

```
  # Use the sample file that comes with `read.gt3x`
  sample_file <- system.file(
    "extdata/TAS1H30182785_2019-09-17.gt3x",
    package = "read.gt3x"
  )
  
  # Your own file might look like this:
  # my_file <- "C:/users/myusername/Desktop/myfile.gt3x"

  # Read the raw acceleration data (30+ Hz)
  AG <- read.gt3x::read.gt3x(sample_file, FALSE, TRUE, TRUE)
  
  # Convert to activity counts (60-s epochs)
  counts <- agcounts::get_counts(sample_file, attr(AG, "sample_rate"), 60)
```
