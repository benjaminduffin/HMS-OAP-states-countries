
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

# get OG names 
oap_names <- names(oap)

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


# all the owner shipping/billing the same? 
# if both NA, return NA 
# if the same or one NA, return same value or non-NA
# if different, return both 
oap$OwnerAddyRect <- ifelse(is.na(oap$OWNER_BILLINGSTATE) & is.na(oap$OWNER_SHIPPINGSTATE), NA, 
                            ifelse(!is.na(oap$OWNER_BILLINGSTATE) & is.na(oap$OWNER_SHIPPINGSTATE), oap$OWNER_BILLINGSTATE, 
                                   ifelse(is.na(oap$OWNER_BILLINGSTATE) & !is.na(oap$OWNER_SHIPPINGSTATE), oap$OWNER_SHIPPINGSTATE, 
                                          ifelse(!is.na(oap$OWNER_BILLINGSTATE) & !is.na(oap$OWNER_SHIPPINGSTATE) & 
                                                   oap$OWNER_BILLINGSTATE == oap$OWNER_SHIPPINGSTATE, oap$OWNER_BILLINGSTATE, 
                                                 ifelse(!is.na(oap$OWNER_BILLINGSTATE) & !is.na(oap$OWNER_SHIPPINGSTATE) & 
                                                          oap$OWNER_BILLINGSTATE != oap$OWNER_SHIPPINGSTATE, 
                                                        paste0(oap$OWNER_BILLINGSTATE, ", ", oap$OWNER_SHIPPINGSTATE), 
                                                              NA)))))



length(unique(oap$OwnerAddyRect)) # 76! 
table(is.na(oap$OwnerAddyRect)) # all NA for both 
unique(oap$OwnerAddyRect)

## looking at combos of vessel home state and principal state 
sum(is.na(oap$VESSEL_HOMESTATE) & is.na(oap$VESSEL_PRINCIPALSTATE)) # only 2 
table(is.na(oap$VESSEL_HOMESTATE), is.na(oap$VESSEL_PRINCIPALSTATE)) # mostly not NA
table(oap$VESSEL_HOMESTATE == oap$VESSEL_PRINCIPALSTATE) # 11.2k F

oap$VesselStateRect <- ifelse(is.na(oap$VESSEL_HOMESTATE) & is.na(oap$VESSEL_PRINCIPALSTATE), NA, 
                              ifelse(!is.na(oap$VESSEL_HOMESTATE) & is.na(oap$VESSEL_PRINCIPALSTATE), oap$VESSEL_HOMESTATE, 
                                     ifelse(is.na(oap$VESSEL_HOMESTATE) & !is.na(oap$VESSEL_PRINCIPALSTATE), oap$VESSEL_PRINCIPALSTATE, 
                                            ifelse(!is.na(oap$VESSEL_HOMESTATE) & !is.na(oap$VESSEL_PRINCIPALSTATE) & 
                                                     oap$VESSEL_HOMESTATE == oap$VESSEL_PRINCIPALSTATE, oap$VESSEL_HOMESTATE, 
                                                   ifelse(!is.na(oap$VESSEL_HOMESTATE) & !is.na(oap$VESSEL_PRINCIPALSTATE) & 
                                                            oap$VESSEL_HOMESTATE != oap$VESSEL_PRINCIPALSTATE, 
                                                          paste0(oap$VESSEL_HOMESTATE, ", ", oap$VESSEL_PRINCIPALSTATE), 
                                                          NA)))))

length(unique(oap$VesselStateRect)) # 791
table(is.na(oap$VesselStateRect)) # only 2, good 
unique(oap$VesselStateRect)


## combining them
oap$states_conc <- paste0(oap$VesselStateRect, "; ", oap$OwnerAddyRect)

## Now, count the combos with each substr of the state reg
oap_f <- oap %>% 
  group_by(st_reg_t, states_conc) %>% # group for counts 
  summarize(count = n()) %>% # get counts 
  ungroup() %>% # ungroup to split strings
  mutate(VesselStateRect = str_split_fixed(states_conc, pattern = "; ", n = 2)[,1], # split strings
         OwnerAddyRect = str_split_fixed(states_conc, pattern = "; ", n = 2)[,2]) %>% 
  filter(!is.na(st_reg_t)) # filter NA for the st_reg_t

# reorder, rename 
oap_f <- oap_f %>% 
  select(st_reg_t, VesselStateRect, OwnerAddyRect, count) 
  
names(oap_f) <- c("StateFromRegistration", "Vessel_HomeState_PrincipalState", "Owner_BillState_ShipState", "count")



# write file 
write_xlsx(oap_f, here("output", paste0("PermitShop_StateInfo_", Sys.Date(), ".xlsx")))


## Looking for countries outside the US
country <- oap %>% 
  filter(!toupper(OWNER_BILLINGSTATE) %in% st_abr$Abr & 
           !is.na(OWNER_BILLINGSTATE) & 
           OWNER_BILLINGSTATE != "FI" & 
           OWNER_BILLINGSTATE != "VI" & 
           !OwnerAddyRect %in% st_abr$Abr) %>% # drop FL typos and VI
  select(all_of(oap_names))

unique(country$OWNER_BILLINGSTATE)

# Write file 
write_xlsx(country, here("output", paste0("PermitShop_CountryInfo_", Sys.Date(), ".xlsx")))

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


