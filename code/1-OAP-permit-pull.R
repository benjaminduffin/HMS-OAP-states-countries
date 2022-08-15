# Header ------------------------------------------------------------------
## Request from DS 6/16/22
## State prefixes (from vessels) 
## What countries are represented in the data
## BD 8/15/2022


##


# Load libraries and .env -------------------------------------------------

library(RJDBC) 
library(dotenv)
library(keyring)
library(here)


# load .env
load_dot_env(".env") # this is coming from the value pair in .env file (made separately and added to .gitignore)

# check keyring for UN
keyring::key_list("HMS-BFT")$username
# and pw
keyring::key_get("HMS-BFT", "NMFS")  


##


# Notes -------------------------------------------------------------------

# Pulling that state info from the first part of the registration? Like.. 
# PR1234XY would be Puerto Rico
# FL4321AB would be Florida

# And potentially pulling the country info from the addresses? 

## State abbreviations (for vessel):: State they represent


## Data source
# TOWNER and TVESSEL
  # TOWNER has mult addresses (owner, port state)

##


# Pull Data ---------------------------------------------------------------

## Must first be tunneling thru the AFMSS VPN


# Create driver object 
# point this to your local ojdbc8.jar file!

jdbcDriver <- JDBC(driverClass = "oracle.jdbc.OracleDriver",
                 classPath="C:/instantclient-basic-windows.x64-21.6.0.0.0dbru/instantclient_21_6/ojdbc8.jar") #CHANGE

# 
# # Create a Connection to the Oracle Database 
jdbConnection <- dbConnect(jdbcDriver, 
                           Sys.getenv("HMS_OAP_PERMITS"), # this is loaded from the .env file using {dotenv} package
                           user = keyring::key_list("HMS-BFT")$username, 
                           password = keyring::key_get("HMS-BFT", "NMFS"))


## Run Query

# for addresses/locations
states_sql <- "select 
                    A.VESSELNAME, 
                    A.COASTGUARDNBR, 
                    A.STATEREGISTRATIONNBR,
                    A.VESSELIDENTIFICATIONNBR,
                    A.HOMEPORTCITY AS VESSEL_HOMEPORT, 
                    A.HOMEPORTSTATE AS VESSEL_HOMESTATE, 
                    A.PRINCIPALPORTSTATE AS VESSEL_PRINCIPALSTATE, 
                    B.SHIPTOCITY AS OWNER_SHIPPINGCITY,
                    B.SHIPTOSTATE AS OWNER_SHIPPINGSTATE, 
                    B.BILLTOCITY AS OWNER_BILLINGCITY, 
                    B.BILLTOSTATE AS OWNER_BILLINGSTATE, 
                    NMFS.DECRYPTRAW(B.BILLTOSTREETADDRESS1) || ' ' || NMFS.DECRYPTRAW(B.BILLTOSTREETADDRESS2) AS OWNERBILLINGDETAILADDY,
                    NMFS.DECRYPTRAW(B.SHIPTOSTREETADDRESS1) || ' ' || NMFS.DECRYPTRAW(B.SHIPTOSTREETADDRESS2) AS OWNER_SHIPPINGDETAILADDY
                from
                    TVESSEL A
                left join
                    TOWNER B ON (A.OWNERID = B.OWNERID)"

sql_results <- dbGetQuery(jdbConnection, states_sql)


# save data to data folder 
saveRDS(sql_results, here("data", paste0("OAP-vessels-owners_", Sys.Date(), ".rds")))

# check for open connections and close any 
var <- as.list(.GlobalEnv)
var_names <- names(var)

for (i in seq_along(var_names)){
  if (class(var[[var_names[i]]]) == "JdbConnection"){
    dbDisconnect(var[[var_names[i]]])
  }
}

# remove objects
rm(jdbcDriver, jdbConnection, var, i, var_names, states_sql)
