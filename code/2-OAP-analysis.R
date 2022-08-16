
# Header ------------------------------------------------------------------
## Request from DS 6/16/22
## State prefixes (from vessels) 
## What countries are represented in the data
## BD 8/15/2022


##

# Libraries ---------------------------------------------------------------
library(plyr)
library(dplyr)
library(tidyr)
library(stringr) 
library(writexl) 
library(ggplot2)
library(here)
library(rvest)

##



# Notes -------------------------------------------------------------------

# Pulling that state info from the first part of the registration? Like.. 
# PR1234XY would be Puerto Rico
# FL4321AB would be Florida

# And potentially pulling the country info from the addresses? 

##


# Load data ---------------------------------------------------------------

# permits for HMS anglers
oap <- readRDS(here::here("data", "OAP-vessels-owners_2022-08-15.rds"))

# convert to all caps
oap <- oap %>% 
  mutate(across(everything(), toupper))

# usps abbreviations
usps_abr_link <- "https://about.usps.com/who/profile/history/state-abbreviations.htm"
usps_content <- read_html(usps_abr_link)

# read table
st_abr <- usps_content %>% 
  html_table() %>% 
  bind_rows() %>%
  select(1, 6)

# rename
names(st_abr) <- c("State", "Abr")

head(st_abr)

# fix NE
st_abr$Abr <- ifelse(st_abr$State == "Nebraska", "NE", st_abr$Abr)

# EDA ----------------------------------------------------------------

# quick look at the data
head(oap)
glimpse(oap)


## Extracting the state code from the state registration number 
# i'm suspecting there will be some odd stuff like preceding spaces or 0's
table(is.na(oap$STATEREGISTRATIONNBR)) # 40k NA

oap$st_reg_t <- ifelse(!is.na(oap$STATEREGISTRATIONNBR), 
                       toupper(substr(oap$STATEREGISTRATIONNBR, 1, 2)), 
                       NA)

length(unique(oap$st_reg_t)) # 491 unique
stReg_substr <- data.frame(sort(table(oap$st_reg_t))) # messy 


# many DO-CG # in this field 




## Looking for countries outside the US
country <- oap %>% 
  filter(!toupper(OWNER_BILLINGSTATE) %in% st_abr$Abr & 
           !is.na(OWNER_BILLINGSTATE) & 
           OWNER_BILLINGSTATE != "FI") # drop FL typos

unique(country$OWNER_BILLINGSTATE)


# Canada, Bermuda, BVI, 




## What we end up with (broad strokes)
# some vessels didn't include the state registration prefix so we see numbers as the first two 
# Delaware is DL
# CN and QC are Canada
# OR is Oregon 
# MS actually has Mississippi and Mass
# some Mass are MA
# DO is CG#
# MC is Michigan
# BV is British Virgin Islands
# WA is sometimes washington, sometimes other states (SC a lot)
# DP is a mistype of DO
# NO is NOVESID
# NT is CT or NY mistyped
# DR is some number associated with NY (not sure what here)
# CF is California often
# DC is washington DC, but more commonly used in Puerto Rico to prefix a doc number
# WS is Wisconsin
# WI is also Wisconsin
# DB is a prefix for CG# for some NY vessels
# ON is Ontario, Canada
# UT has one Utah, rest some odd number from NY
# AK is Alaska
# DJ is odd numbers from NY


