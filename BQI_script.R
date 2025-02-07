#########################################################################################
###   HELCOM Core indicator "State of the softbottom macrofauna community" R-script   ###
###   for calculating BQI based on data extracts from HELCOM/ICES COMBINE database    ###
###										      ###
###   Developed within the "Baltic Data Flows" project, funded by the EU Innovation   ###
###   and Networks Agency (INEA) via CEF funding instrument.			      ###
###   Project information: https://balticdataflows.helcom.fi/			      ###
#########################################################################################

rm(list=ls())
options(max.print=50000000)

## Set working directory where input/output folders are located
#setwd("D:/ ...")

## load necessary libraries
library(dplyr)
library(vegan)
library(pivottabler)
library(raster)
library(rgdal)

### read input files
## data extract from COMBINE as txt file:		### Change file name ###
InputData		<- read.table(file = "./input/ZB_HELCOM_20162021.txt", fileEncoding="UTF-8-BOM", sep="\t", header = TRUE)	
## data extract from COMBINE as csv file:		### Change file name ###
#InputData 		<- read.csv(file = "./input/ZB_HELCOM_20211004.csv", sep=";", header = TRUE)	

SpSensitivity 	<- read.csv(file = "./input/SensitivityLists.csv", sep=";", header = TRUE)	# species sensitivity values (based on Schiele et al. 2016, Leonardsson et al. 2009)
Salinity_Raster 	<- raster("./input/raster_salmean.TXT")							# Salinity based on EUSeaMap (published 2010-12-01)

### Data preparations ###
## choose needed columns and filter abundances, years and sampling gear
Data_BQI <- InputData[,c(1,6:7,11:15,22,24,26,32:39,41,48:50,18)]						# choose data columns needed
Data_BQI <- filter(Data_BQI[Data_BQI$PARAM == "ABUNDNR" | Data_BQI$FNFLA == "N",])			# filter abundance data and empty samples
Data_BQI <- filter(Data_BQI[Data_BQI$MYEAR>=2016 & Data_BQI$MYEAR<=2020,]) 				# choose time span
Data_BQI <- filter(Data_BQI[Data_BQI$SMTYP == "VV" | Data_BQI$SMTYP == "SM",])			# filter van Veen and Smith-MacIntyre grabs

#no_animals <- InputData[InputData$FNFLA == "N",c(1,6:7,11:15,22,24,26,32:39,41,48:50,18)]


## match data with species sensitivity list using AphiaID and add to data
aphia_match <- match(Data_BQI[,11], SpSensitivity[,2])

for (i in 1:nrow(Data_BQI)){
	Data_BQI[i,25] <- SpSensitivity[aphia_match[i],6]
}
colnames(Data_BQI)[25] <- "AphiaBQI"

## extract salinity for samples from EUSeaMap2016
Sample_points <- SpatialPoints(Data_BQI[,c(7,6)], proj4string=CRS('+proj=longlat +datum=WGS84'))
pts <- spTransform(Sample_points, CRS("+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +datum=WGS84"))
Salinity <- extract(Salinity_Raster, Sample_points)

Data_BQI <- cbind(Data_BQI, Salinity)

## convert data to 0.1 m2 values to new column
Data_BQI[,27] <- Data_BQI$Final_VALUE/10
colnames(Data_BQI)[27] <- "VALUE01"

### Assign species sensitivity lists to the samples ###

S_list <- 0

Data_BQI <- Data_BQI[!(is.na(Data_BQI$WADEP)), ]   	# Remove samples for which no depth is reported
#Data_BQI <- Data_BQI[!(is.na(Data_BQI$MESHS)), ]  	# Remove samples for which no mesh size is reported
Data_BQI[Data_BQI$CNTRY == "Estonia", 20] <- 250        # replace missing sieve size with 250 for Estonia (used as an intermediate solution awaiting confirmation of sieve size)
Data_BQI[Data_BQI$CNTRY == "Sweden", 20] <- 1000        # replace missing sieve size with 1000 for Sweden (used as an intermediate solution awaiting confirmation of sieve size)
Data_BQI[Data_BQI$CNTRY == "Poland", 20] <- 1000        # replace missing sieve size with 1000 for Poland (used as an intermediate solution awaiting confirmation of sieve size)
Data_BQI[Data_BQI$CNTRY == "Germany", 20] <- 1000       # replace missing sieve size with 1000 for Germany (used as an intermediate solution awaiting confirmation of sieve size)

for (i in 1:nrow(Data_BQI)){
if (Data_BQI[i,4] == "Bothnian Sea" |
	Data_BQI[i,4] == "Bothnian Bay" |
	Data_BQI[i,4] == "The Quark" |
	Data_BQI[i,4] == "Åland Sea" |
	Data_BQI[i,4] == "Western Gotland Basin" |
	Data_BQI[i,4] == "Northern Baltic Proper" |
	Data_BQI[i,4] == "Eastern Gotland Basin" &
	Data_BQI[i,1] == "Sweden" |
	Data_BQI[i,4] == "Bornholm Basin" &
	Data_BQI[i,1] == "Sweden" |
	Data_BQI[i,4] == "Arkona Basin" &
	Data_BQI[i,1] == "Sweden") 
	{S_list[i] <- 20 }

else if (Data_BQI[i,26] > 30)
	{S_list[i] <- 1 }

else if (Data_BQI[i,26] > 18 &
	Data_BQI[i,9] <= 20)
	{S_list[i] <- 2 }

else if (Data_BQI[i,26] > 18)
	{S_list[i] <- 3 }

else if (Data_BQI[i,4] == "Eastern Gotland Basin" &
	Data_BQI[i,9] > 60 |
	Data_BQI[i,4] == "Gdansk Basin" &
	Data_BQI[i,9] > 60) 
	{S_list[i] <- 7 }

else if (Data_BQI[i,4] == "Eastern Gotland Basin" &
	Data_BQI[i,9] <= 60 &
	Data_BQI[i,20] == 1000 |		
	Data_BQI[i,4] == "Gdansk Basin" &
	Data_BQI[i,9] <= 60 &
	Data_BQI[i,20] == 1000) 
	{S_list[i] <- 8 }

else if (Data_BQI[i,4] == "Eastern Gotland Basin" &
	Data_BQI[i,9] <= 60 &
	Data_BQI[i,20] == 500 |		
	Data_BQI[i,4] == "Gdansk Basin" &
	Data_BQI[i,9] <= 60 &
	Data_BQI[i,20] == 500) 
	{S_list[i] <- 9 }

else if (Data_BQI[i,26] > 10)
	{S_list[i] <- 4 }

else if (#Data_BQI[i,4] == "Gulf of Riga" &
#	Data_BQI[i,20] == 250 |
#	Data_BQI[i,4] == "Gulf of Finland" &
	Data_BQI[i,20] == 250) 
	{S_list[i] <- 13 }

else if (Data_BQI[i,4] == "Gulf of Riga" &
	Data_BQI[i,26] > 5 &
	Data_BQI[i,20] == 1000 |
	Data_BQI[i,4] == "Gulf of Finland" &
	Data_BQI[i,26] > 5 &
	Data_BQI[i,20] == 1000) 
	{S_list[i] <- 11 }

else if (Data_BQI[i,4] == "Gulf of Riga" &
	Data_BQI[i,26] > 5 &
	Data_BQI[i,20] == 500 |
	Data_BQI[i,4] == "Gulf of Finland" &
	Data_BQI[i,26] > 5 &
	Data_BQI[i,20] == 500) 
	{S_list[i] <- 12 }

else if (Data_BQI[i,4] == "Gulf of Riga" &
	Data_BQI[i,26] > 3 &
	Data_BQI[i,20] == 1000 |
	Data_BQI[i,4] == "Gulf of Finland" &
	Data_BQI[i,26] > 3 &
	Data_BQI[i,20] == 1000) 
	{S_list[i] <- 14 }

else if (Data_BQI[i,4] == "Gulf of Riga" &
	Data_BQI[i,26] > 3 &
	Data_BQI[i,20] == 500 |
	Data_BQI[i,4] == "Gulf of Finland" &
	Data_BQI[i,26] > 3 &
	Data_BQI[i,20] == 500) 
	{S_list[i] <- 15 }

else if (Data_BQI[i,26] > 7.5)
	{S_list[i] <- 5 }

else if (Data_BQI[i,26] > 5)
	{S_list[i] <- 6 }
}

Data_BQI <- cbind(Data_BQI, S_list)
colnames(Data_BQI)[28] <- "EIG"

## Pick out samples with no animals
no_animals <- Data_BQI[Data_BQI$FNFLA == "N",]

## filter out species not included in BQI calculations
Data_BQI <- filter(Data_BQI[Data_BQI$AphiaBQI != "delete",])

## Split into sensitivity groups
EIGS <- split(Data_BQI, Data_BQI$EIG)

### Calculate BQI for samples in all sensitivity groups ###

for (k in 1:length(EIGS)) {

## make a table with samples as columns, species as rows and values as sums of abundance
pt <- PivotTable$new()
pt$addData(EIGS[[k]])
pt$addColumnDataGroups("tblSampleID")
pt$addRowDataGroups("AphiaBQI")
pt$defineCalculation(calculationName="TotalInd", summariseExpression="sum(VALUE01)")
pt$evaluatePivot()
data1 <- pt$asDataFrame()


## Calculation of BQI
sensitivitylist <- EIGS[[k]][1,28]             	# choose sensitivity list, i.e. column in the sensitivity lists file

ref.species <- nrow(SpSensitivity)                   
stations <- ncol(data1)-1
SampleID <- names(data1[1:stations])
species <- nrow(data1)-1       
ind.station <- as.numeric(data1[species+1,1:stations])                  

data11 <- data1[1:species,1:stations, drop=FALSE]
data11[is.na(data11)] <- 0
sp.names <- row.names(data11)

		#1. Variable setting
a <- 1
used.ind <- 0
S.stat <- 0
BQI2009 <- 0
sensitivitylistname <- 0

for (a in 1:stations) {									##start loop
		#2. Merge frames
	S.stat[a]<-nrow(subset(data11,data11[,a]>0))
	help.df.station<-data.frame(sp.names,data11[,a])
	ref.list<-sensitivitylist+6
	ref.list
	sensitivitylist
	help.df.ref<-data.frame(SpSensitivity$WoRMS_acc_AphiaID,SpSensitivity[,ref.list])         
	help.df.ref1<-na.omit(help.df.ref)
	kombi.frame<-0
	kombi.frame<-merge(help.df.station,help.df.ref1,by.x=c("sp.names"),by.y=c("SpSensitivity.WoRMS_acc_AphiaID")) 
		#3. calculation
	help.column<-0
	used.ind[a]<-sum(kombi.frame[,2])
	help.column<-(kombi.frame[,2]/used.ind[a])*kombi.frame[,3]

	BQI2009[a]<-(sum(help.column)*(log(S.stat[a]+1,10))*(ind.station[a]/(ind.station[a]+5)))
	sensitivitylistname[a]<-names(SpSensitivity[ref.list])
}												##End loop

## Collect results
BQI2009[is.nan(BQI2009)] <- 0		
result.EIG <- data.frame(SampleID,S.stat,ind.station,BQI2009,sensitivitylistname)

## Combine results from the EIGs
	if (k == 1) {
		result.BQI <- result.EIG }
	else {
		result.BQI <- rbind(result.BQI, result.EIG) }
}

## Match samples with input data to add sample information to results
sample_match <- match(result.BQI[,1], Data_BQI[,22])

for (i in 1:nrow(result.BQI)){
	result.BQI[i,6] <- Data_BQI[sample_match[i],4]
	result.BQI[i,7] <- Data_BQI[sample_match[i],5]
	result.BQI[i,8] <- Data_BQI[sample_match[i],1]
	result.BQI[i,9] <- Data_BQI[sample_match[i],8]
	result.BQI[i,10] <- Data_BQI[sample_match[i],24]
	result.BQI[i,11] <- Data_BQI[sample_match[i],6]
	result.BQI[i,12] <- Data_BQI[sample_match[i],7]
	result.BQI[i,13] <- Data_BQI[sample_match[i],9]
	result.BQI[i,14] <- Data_BQI[sample_match[i],2]
	result.BQI[i,15] <- Data_BQI[sample_match[i],3]
	result.BQI[i,16] <- Data_BQI[sample_match[i],17]
}
colnames(result.BQI)[6] <- "HELCOM_subbasin"
colnames(result.BQI)[7] <- "HELCOM_L4"
colnames(result.BQI)[8] <- "CNTRY"
colnames(result.BQI)[9] <- "STATN"
colnames(result.BQI)[10] <- "SD_station_code_All"
colnames(result.BQI)[11] <- "Lat"
colnames(result.BQI)[12] <- "Lon"
colnames(result.BQI)[13] <- "WADEP"
colnames(result.BQI)[14] <- "MYEAR"
colnames(result.BQI)[15] <- "Date"
colnames(result.BQI)[16] <- "FNFLA"

## Add samples with no animals
# rename EIG
EIGcolumn <- 0
for (i in 1:nrow(no_animals)) {
	if (no_animals[i,28] == 20)
		{EIGcolumn[i] <- "ES-SWE"}
	else
		{EIGcolumn[i] <- paste("EIG",no_animals[i,28], sep="")}
} 

# make result rows for empty samples
no_animals_result <- cbind(no_animals[,22], 0, 0, 0, EIGcolumn, no_animals[,c(4:5,1,8,24,6:7,9,2:3,17)])
no_animals_result[,1] <- as.factor(no_animals_result[,1])
colnames(no_animals_result)<-colnames(result.BQI)

# merge empty samples with BQI results
result.BQI <- rbind(result.BQI,no_animals_result)


### Write results to table, BQI for each sample
write.csv(result.BQI, "./output/BQI_result.csv", row.names=FALSE)



