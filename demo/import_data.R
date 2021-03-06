###
## This demo shows how to create a NetCDF file from a numeric vector in R.

## The data was retrieved using Quandl as follows
# 
## Note: requires RCurl which requires libcurl4-openssl-dev
## install.packages("Quandl")
# library(Quandl)
# mydata <- Quandl("YAHOO/INDEX_GSPC")
# mydata <- mydata[1:1000,]
# save(mydata, file="RBi/data/SP500.RData")
##
###
## The data is provided in the data folder of RBi for conveniency.
library(bi)
# Import data
load(system.file(package="bi", "data/SP500.RData"))
SP500 <- mydata$Close
# do some calculation on the data
logreturns <- rep(0, length(SP500))
for (i in 2:length(SP500)){
  logreturns[i+1] <- log(SP500[i+1]) - log(SP500[i])
}
# create a NetCDF file from the data
obs_file_name <- tempfile(pattern="obs", fileext=".nc")
bi_obs_file(filename=obs_file_name, 
            variable=logreturns, 
            name="LogReturns")
bi_file_summary(obs_file_name)
bi_file_ncdump(obs_file_name)
# this data file can now be given to LibBi with the '--obs-file' option.
