## Request from DS 6/16/22
## State prefixes (from vessels) 
## What countries are represented in the data

## Libraries 
library(RJDBC) 
library(plyr)
library(dplyr)
library(stringr) 
library(writexl) 
library(ggplot2)


## Notes 
# Pulling that state info from the first part of the registration? Like.. 
# PR1234XY would be Puerto Rico
# FL4321AB would be Florida
# And potentially pulling the country info from the addresses? 


# Pull the data 