capture log close
clear
clear matrix
clear mata
capture log close
set maxvar 15000
set more off
numlabel, add

*******************************************************************************
* INSTRUCTIONS
*******************************************************************************
** Set macros for country and round
****Leave level1 blank if running for national analysis, if running for regional/state level analysis, set each level1 one at a time
global country "KENYA"
global level1 
global phase "Phase2"
global CCPX "KEP2"
local CCPX $CCPX

* Set macro for date of HHQ/FQ EC recode dataset that intend to use for Phase 1
*local datadate "20Feb2020"

* Set local/global macros for current date
local today=c(current_date)
local c_today= "`today'"
global date=subinstr("`c_today'", " ", "",.)
local todaystata=clock("`today'", "DMY")

* Set macro for do-File directory (HHQFQ_Analysis repository for your country)
local dofiledir "D:\Project\PMA Action\Phase_2\Data\Do_files\HHQFQ_dofile"

* Set macro for final cleaned EC recode dataset 
global cleaneddataset "D:\Project\PMA Action\Phase_2\Data\HQFQ_data\KEP2_NONAME_ECRecode_CS_26Jan2021.dta"

* Set Directory for Data 
global datadir "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\P1"

*******************************************************************************
*WEALTH WEIGHT ALL MACROS
*******************************************************************************
global assets "electricity-motor_boat" 
global water "water_pipe2dwelling-water_sachet"
global wealthgroup 5

*******************************************************************************
*Cross-Section Indicator Analysis Macros
*******************************************************************************
* Set macros for education - No school or upto primary school will be coded as none_primary_education
global none_primary_education "(school == 0| school == 1 | school == 6)"
global secondary_education "(school== 7)"
global tertiary_education  "(school == 4| school == 5)"

*******************************************************************************
**** TREND DATA MACROS 
*******************************************************************************
*Name of the excel output
global excel "`CCPX'_ContraceptiveUseTrends_$date.xlsx"

*EA_ID or Cluster_ID 
global PSU "EA_ID"

*Name of the FQweight variable for rounds/phases with regional weights
global FQweight "FQweight"

*Variables used to calculate the strata
global strata  ur

*Variable name for level1 in PMA2020 (ex. state in Nigeria, or county in Kenya)
global level1_var state

*Number of PMA2020 rounds for the country
global roundcount 7
global phasecount 2

**************PHASE 1 MACROS*************
	**Publicly Released HHQFQ dataset/WealthWeightAll for current phase
	global phase1data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\P1\KEP1_WealthWeightAll_24Feb2020.dta"
	**Dates of Data Collection
	global phase1dates "11-12/2019"
	
**************PHASE 2 MACROS*************
	**Publicly Released HHQFQ dataset/WealthWeightAll for current phase
	global phase2data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\P1\KEP2_WealthWeightAll_30Jan2021.dta"
	**Dates of Data Collection
	global phase2dates "11-12/2020"

**************ROUND 1 MACROS*************
	**Publicly Released HHQFQ dataset
	global round1data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\R1\KER1_HHQFQ_AnalysisData_7Mar2019.dta" 
	**Dates of Data Collection
	global round1dates "5-7/2014"

**************ROUND 2 MACROS*************
	**Publicly Released HHQFQ dataset
	global round2data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\R2\KER2_HHQFQ_AnalysisData_2May2019.dta"
	**Dates of Data Collection
	global round2dates "11-12/2014"

**************ROUND 3 MACROS*************
	**Publicly Released HHQFQ dataset
	global round3data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\R3\KER3_HHQFQ_AnalysisData_2May2019.dta"
	**Dates of Data Collection
	global round3dates "6-7/2015"

**************ROUND 4 MACROS*************
	**Publicly Released HHQFQ dataset
	global round4data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\R4\KER4_HHQFQ_AnalysisData_2May2019.dta"
	**Dates of Data Collection
	global round4dates "11-12/2015"
	
**************ROUND 5 MACROS*************
	**Publicly Released HHQFQ dataset
	global round5data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\R5\KER5_HHQFQ_AnalysisData_5Apr2019.dta"
	**Dates of Data Collection
	global round5dates "11-12/2016"

**************ROUND 6 MACROS*************
	**Publicly Released HHQFQ dataset
	global round6data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\R6\KER6_HHQFQ_AnalysisData_10Nov2018.dta"
	**Dates of Data Collection
	global round6dates "11-12/2017"	
	
**************ROUND 7 MACROS*************
	**Publicly Released HHQFQ dataset
	global round7data "D:\Project\PMA Action\Phase_1\County_disseminations\1_data\R7\KER7_HHQFQ_AnalysisData_16Jul2019.dta"
	**Dates of Data Collection
	global round7dates "11-12/2018"
		
********************************************************************************
*DISCONTINUATION RATE MACROS
********************************************************************************

*Macros for the years in the calendar
global firstyear 2018
global lastyear 2020


*Macro for the number of months in the full calendar (36 or 48 depending on if the calendar was over 3 or 4 years)
global cal_len = 36

********************************************************************************
*STOP UPDATING MACROS HERE
********************************************************************************

cd "$datadir"

* Create log
log using "`CCPX'_HHQFQ_Analysis.log", replace

run "`dofiledir'/HHQFQDoFile1_Wealth_Unmet_Generation.do"
run "`dofiledir'/HHQFQDoFile2_2Page_Analysis.do"
run "`dofiledir'/HHQFQDoFile3_TrendsContraceptiveUse.do"
run "`dofiledir'/HHQFQDoFile4_Discontinuation_Code.do"

log close