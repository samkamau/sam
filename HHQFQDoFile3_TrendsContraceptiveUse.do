clear
clear matrix
clear mata
set maxvar 15000
set more off
numlabel, add

/*******************************************************************************
*
*  FILENAME:	HHQFQDoFile3_TrendsContraceptiveUse
*  PURPOSE:		Generate Contraceptive Use Trends, all women, all rounds using PMA2020 and PMA data
*  CREATED:		Aisha Siewe (asiewe@jhu.edu)
*  DATA IN:		PMA2020 Analysis datasets datasets / PMA cross-sectional WealthWeightAll dataset
*  DATA OUT:	CC_ContraceptiveUseUnmetNeedDemandSat_date.xls
*
*******************************************************************************/

*SET MACROS
local CCPX $CCPX

*Name of the excel output
local excel $excel

*EA_ID or Cluster_ID 
local PSU $PSU

*Name of the FQweight variable for rounds/phases with regional weights
local FQweight $FQweight

*Variables used to calculate the strata
local strata $strata

*Number of PMA2020 rounds for the country
local roundcount $roundcount
local round1data $round1data
local round2data $round2data
local round3data $round3data
local round4data $round4data
local round5data $round5data
local round6data $round6data
local round7data $round7data
local round1dates $round1dates
local round2dates $round2dates
local round3dates $round3dates
local round4dates $round4dates
local round5dates $round5dates
local round6dates $round6dates
local round7dates $round7dates

local phasecount $phasecount
local phase1data $phase1data
local phase2data $phase2data

********************************************************************************
**********************TRENDS IN METHOD USE**************************************
********************************************************************************

**********Prepare Excel**********
cd "$datadir"

putexcel set "`excel'", replace sheet("Method Use, Unmet Need, Demand")

putexcel C4=("All Women")
putexcel C6=("Dates of Data Collection"), txtwrap
putexcel D6=("N")
putexcel E6=("Longacting Method Use"), txtwrap
putexcel F6=("Shortacting Method Use"), txtwrap
putexcel G6=("Traditional Method Use"), txtwrap
putexcel H6=("Unmet Need for Limiting"), txtwrap
putexcel I6=("Unmet Need for Spacing"), txtwrap
putexcel J6=("Demand Satisfied by Modern Method"), txtwrap

***** PMA2020 DATA
putexcel A7=("PMA2020")

local row=8
forval i = 1/`roundcount' {
	use "`round`i'data'", clear
	if "$level1"!="" {
		numlabel, remove force
		decode $level1_var, gen(str_$level1_var)
		keep if str_$level1_var=="$caps_level1"
		}
		
	putexcel B`row'=("Round `i'")
	putexcel C`row'=("`round`i'dates'")

	** COUNT - Female Sample - All **
	capture confirm var last_night
	if _rc==0 {
		cap gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & last_night==1
		}
	else {
		cap gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & (usual_member==1 | usual_member==3)
		}
	preserve
	
	cap collapse (count) FQresponse_1
	mkmat FQresponse_1
	putexcel D`row'=matrix(FQresponse_1)
	restore

	** Generate Longacting shortacting
	cap gen shortacting= current_methodnum>=5 & current_methodnum<=16
	label var shortacting "Current use of short acting contraceptive method"

	cap gen longacting=current_methodnum>=1 & current_methodnum<=4
	label var shortacting "Current use of long acting contraceptive method"

	* Generate total demand = current use + unmet need
	cap gen totaldemand=0
	replace totaldemand=1 if cp==1 | unmettot==1
	label variable totaldemand "Has contraceptive demand, i.e. current user or unmet need"

	* Generate total demand staisfied
	cap gen totaldemand_sat=0 if totaldemand==1
	replace totaldemand_sat=1 if totaldemand==1 & mcp==1
	label variable totaldemand_sat "Contraceptive demand satisfied by modern method"

	* Unmet need for limiting
	cap gen unmet_limit = 0 if unmet != .
	replace unmet_limit = 1 if unmet == 2
	label var unmet_limit "Unmet need for limiting"

	* Unmet need for spacing
	cap gen unmet_space = 0 if unmet != .
	replace unmet_space = 1 if unmet == 1
	label var unmet_space "Unmet need for spacing"

	*** Estimate Percentage and 95% CI
	keep if FQresponse_1==1
	egen all=tag(FQmetainstanceID)
	
	if "`strata'"!="" {
		capture egen strata=concat(`strata'), punct(-)
		}
	else{
		gen strata=1
		}
	
	svyset `PSU' [pw=`FQweight'], strata(strata) singleunit(scaled)
	foreach group in all {
	preserve
		keep if `group'==1
		foreach indicator in longacting shortacting tcp unmet_limit unmet_space totaldemand_sat{
			svy: prop `indicator', citype(wilson) percent
			matrix reference=r(table)
			matrix `indicator'_`group'_percent=round(reference[1,2]	, .1)
			}	
	restore
		}
	putexcel E`row'=matrix(longacting_all_percent)
	putexcel F`row'=matrix(shortacting_all_percent)
	putexcel G`row'=matrix(tcp_all_percent)
	putexcel H`row'=matrix(unmet_limit_all_percent)
	putexcel I`row'=matrix(unmet_space_all_percent)
	putexcel J`row'=matrix(totaldemand_sat_all_percent)
	local row=`row'+1
	}

***** PMA PHASES

	
putexcel A16=("PMA")

local row=17
forval i = 1/`phasecount' {
	use "`phase`i'data'", clear
	
	if "$level1"!="" {
		numlabel, remove force
		decode $level1_var, gen(str_$level1_var)
		keep if str_$level1_var=="$caps_level1"
		}
		
	putexcel B`row'=("phase`i'")
	putexcel C`row'=("`phase`i'dates'")

capture rename EA EA_ID
capture rename ClusterID Cluster_ID


** COUNT - Female Sample - All / Married Women  **
	capture confirm var last_night
	if _rc==0 {
		cap gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & last_night==1
		}
	else {
		cap gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & (usual_member==1 | usual_member==3)
		}

preserve
cap gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & last_night==1
collapse (count) FQresponse_1
mkmat FQresponse_1
putexcel D`row'=matrix(FQresponse_1)
restore

** Generate Longacting shortacting
gen shortacting= current_methodnum>=5 & current_methodnum<=16
label var shortacting "Current use of short acting contraceptive method"

capture drop longacting
gen longacting=current_methodnum>=1 & current_methodnum<=4
tab current_recent_methodnum longacting
label var shortacting "Current use of long acting contraceptive method"

* Generate total demand = current use + unmet need
gen totaldemand=0
replace totaldemand=1 if cp==1 | unmettot==1
label variable totaldemand "Has contraceptive demand, i.e. current user or unmet need"

* Generate total demand staisfied
gen totaldemand_sat=0 if totaldemand==1
replace totaldemand_sat=1 if totaldemand==1 & mcp==1
label variable totaldemand_sat "Contraceptive demand satisfied by modern method"

* Unmet need for limiting
gen unmet_limit = 0 if unmet != .
replace unmet_limit = 1 if unmet == 2
label var unmet_limit "Unmet need for limiting"

* Unmet need for spacing
gen unmet_space = 0 if unmet != .
replace unmet_space = 1 if unmet == 1
label var unmet_space "Unmet need for spacing"

*** Estimate Percentage and 95% CI
keep if FRS_result==1 & HHQ_result==1 & last_night==1
egen all=tag(FQmetainstanceID)

if "`strata'"!="" {
	capture egen strata=concat(`strata'), punct(-)
	}
else{
	gen strata=1
	}
	
svyset `PSU' [pw=`FQweight'], strata(strata) singleunit(scaled)
foreach group in all {
preserve
	keep if `group'==1
		foreach indicator in longacting shortacting tcp unmet_limit unmet_space totaldemand_sat{
			svy: prop `indicator', citype(wilson) percent
			matrix reference=r(table)
			matrix `indicator'_`group'_percent=round(reference[1,2]	, .1)
	}	
	restore
	}
	putexcel E`row'=matrix(longacting_all_percent)
	putexcel F`row'=matrix(shortacting_all_percent)
	putexcel G`row'=matrix(tcp_all_percent)
	putexcel H`row'=matrix(unmet_limit_all_percent)
	putexcel I`row'=matrix(unmet_space_all_percent)
	putexcel J`row'=matrix(totaldemand_sat_all_percent)
	local row=`row'+1
	}


********************************************************************************
**********************TRENDS IN METHOD MIX**************************************
********************************************************************************

**********Prepare Excel**********2

putexcel set "`excel'", modify sheet("Method Mix-All Women")
putexcel C4=("All Women")
putexcel C6=("Dates of Data Collection"), txtwrap
putexcel D6=("N")
putexcel E6=("Female Sterilization")
putexcel F6=("Male Sterilization")
putexcel G6=("Implants")
putexcel H6=("IUD")
putexcel I6=("Injectables")
putexcel J6=("Injectables 1mo")
putexcel K6=("Pills")
putexcel L6=("EC")
putexcel M6=("Male Condoms")
putexcel N6=("Female Condoms")
putexcel O6=("Diaphragm")
putexcel P6=("Foam")
putexcel Q6=("Beads")
putexcel R6=("LAM")
putexcel S6=("N Tablet")
putexcel T6=("Sayana Press")
putexcel U6=("Other Modern Methods")

tokenize E F G H I J K L M N O P Q R S T U

putexcel A7=("PMA2020")

local row=8
forval i = 1/`roundcount' {
	use "`round`i'data'", clear
	putexcel B`row'=("Round `i'")
	putexcel C`row'=("`round`i'dates'")

	if "`strata'"!="" {
		capture egen strata=concat(`strata'), punct(-)
		}
	else{
		gen strata=1
		}
	
	svyset `PSU' [pw=`FQweight'], strata(strata) singleunit(scaled)

	forval y = 1/17 {
		gen method_`y'=0 if mcp==1
		replace method_`y'=1 if current_methodnum_rc==`y'
		capture replace method_17=1 if current_methodnum_rc==19
		svy: tab method_`y' if mcp==1, percent
		if e(r)==2 {
			matrix prop_`y'=e(Prop)*100
			matrix prop_`y'=round(prop_`y'[2,1], .1)
			}
		else {
			matrix prop_`y'=0
			}
		putexcel D`row'=(e(N))
		putexcel ``y''`row' =matrix(prop_`y')
		}
	local row=`row'+1
	}

	
***** PMA PHASES

putexcel A16=("PMA")

local row=17
forval i = 1/`phasecount' {
	use "`phase`i'data'", clear
	putexcel B`row'=("phase `i'")
	putexcel C`row'=("`phase`i'dates'")
capture rename EA EA_ID
capture rename ClusterID Cluster_ID

if "`strata'"!="" {
	capture egen strata=concat(`strata'), punct(-)
	}
else{
	gen strata=1
	}
	
svyset `PSU' [pw=`FQweight'], strata(strata) singleunit(scaled)

forval y = 1/17 {
	gen method_`y'=0 if mcp==1
	replace method_`y'=1 if current_methodnumEC==`y'
	capture replace method_17=1 if current_methodnumEC==19
	svy: tab method_`y' if mcp==1, percent
	if e(r)==2 {
		matrix prop_`y'=e(Prop)*100
		matrix prop_`y'=round(prop_`y'[2,1], .1)
		}
	else {
		matrix prop_`y'=0
		}
	putexcel D`row'=(e(N))
	putexcel ``y''`row' =matrix(prop_`y')
	}
    local row=`row'+1
}

********************************************************************************
**********************TRENDS IN CPR,mCPR, UNMET NEED****************************
********************************************************************************

**********Prepare Excel**********

putexcel set "`excel'", modify sheet("Trends")
putexcel D4=("All Women")
putexcel Q4=("Married Women")
putexcel AD4= ("Unmarried Sexually Active")
putexcel E5=("CPR")
putexcel I5=("mCPR")
putexcel M5=("Total Unmet Need")
putexcel R5=("CPR")
putexcel V5=("mCPR")
putexcel Z5=("Total Unmet Need")
putexcel AE5=("CPR")
putexcel AI5=("mCPR")
putexcel AM5=("Total Unmet Need") 
putexcel C6=("Dates of Data Collection")
putexcel D6=("N")
putexcel Q6=("N")
putexcel AD6=("N")


foreach col in E I M R V Z AE AI AM {
	putexcel `col'6=("Percent")
	}

foreach col in F J N S W AA AF AJ AN {
	putexcel `col'6=("SE")
	}	

foreach col in G K O T X AB	AG AK AO {
	putexcel `col'6=("CI LB")
	}	

foreach col in H L P U Y AC AH AL AP {
	putexcel `col'6=("CI UB")
	}	

***** PMA2020 data
putexcel A7=("PMA2020")
putexcel B8=("Round 1")

local row=8

forval i = 1/`roundcount' {
	use "`round`i'data'", clear
	if "$level1"!="" {
		numlabel, remove force
		decode $level1_var, gen(str_$level1_var)
		keep if str_$level1_var=="$caps_level1"
		}
	putexcel C`row'=("`round`i'dates'")
	
* Generate Unmarried sexually active	
	cap drop umsexactive
	gen umsexactive=0 
	replace umsexact=1 if (FQmarital_status!=1 & FQmarital_status !=2 & FQmarital_status !=.) & ((last_time_sex==2 & last_time_sex_value<=4 & last_time_sex_value>=0) | ///
		(last_time_sex==1 & last_time_sex_value<=30 & last_time_sex_value>=0) | (last_time_sex==3 & last_time_sex_value<=1 & last_time_sex_value>=0))	
		

** COUNT - Female Sample - All / Married Women  **
	capture confirm var last_night
	if _rc==0 {
		gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & last_night==1
		gen FQresponse_2=1 if FRS_result==1 & HHQ_result==1 & last_night==1 & (FQmarital_status==1 | FQmarital_status==2)
		gen FQresponse_3=1 if FRS_result==1 & HHQ_result==1 & last_night==1 & umsexactive == 1
		}
	else {
		gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & (usual_member==1 | usual_member==3)
		gen FQresponse_2=1 if FRS_result==1 & HHQ_result==1 & (usual_member==1 | usual_member==3) & (FQmarital_status==1 | FQmarital_status==2)
		gen FQresponse_3=1 if FRS_result==1 & HHQ_result==1 & (usual_member==1 | usual_member==3) & umsexactive == 1
		
		}
	preserve
	collapse (count) FQresponse_1 FQresponse_2 FQresponse_3
	mkmat FQresponse_1
	mkmat FQresponse_2
	mkmat FQresponse_3
	putexcel D`row'=matrix(FQresponse_1)
	putexcel Q`row'=matrix(FQresponse_2)
	putexcel AD`row'=matrix(FQresponse_3)
	restore

	*** Estimate Percentage and 95% CI
	keep if FQresponse_1==1
	egen all=tag(FQmetainstanceID)
	egen mar=tag(FQmetainstanceID) if (FQmarital_status==1 | FQmarital_status==2)
	egen umsex = tag(FQmetainstanceID) if umsexactive == 1
	
	if "`strata'"!="" {
		capture egen strata=concat(`strata'), punct(-)
		}
	else{
		gen strata=1
		}
	
	svyset `PSU' [pw=`FQweight'], strata(strata) singleunit(scaled)
	foreach group in all mar umsex {
	preserve
		keep if `group'==1
		foreach indicator in cp mcp unmettot  {
			svy: prop `indicator', citype(wilson) percent
			matrix reference=r(table)
			matrix `indicator'_`group'_percent=round(reference[1,2]	, .01)
			matrix `indicator'_`group'_se=round(reference[2,2], .01)
			matrix `indicator'_`group'_ll=round(reference[5,2], .01)
			matrix `indicator'_`group'_ul=round(reference[6,2], .01)
		}	
	restore
	}
	putexcel E`row'=matrix(cp_all_percent)
	putexcel F`row'=matrix(cp_all_se)
	putexcel G`row'=matrix(cp_all_ll)
	putexcel H`row'=matrix(cp_all_ul)
	putexcel I`row'=matrix(mcp_all_percent)
	putexcel J`row'=matrix(mcp_all_se)
	putexcel K`row'=matrix(mcp_all_ll)
	putexcel L`row'=matrix(mcp_all_ul)
	putexcel M`row'=matrix(unmettot_all_percent)
	putexcel N`row'=matrix(unmettot_all_se)
	putexcel O`row'=matrix(unmettot_all_ll)
	putexcel P`row'=matrix(unmettot_all_ul)
	putexcel R`row'=matrix(cp_mar_percent)
	putexcel S`row'=matrix(cp_mar_se)
	putexcel T`row'=matrix(cp_mar_ll)
	putexcel U`row'=matrix(cp_mar_ul)
	putexcel V`row'=matrix(mcp_mar_percent)
	putexcel W`row'=matrix(mcp_mar_se)
	putexcel X`row'=matrix(mcp_mar_ll)
	putexcel Y`row'=matrix(mcp_mar_ul)
	putexcel Z`row'=matrix(unmettot_mar_percent)
	putexcel AA`row'=matrix(unmettot_mar_se)
	putexcel AB`row'=matrix(unmettot_mar_ll)
	putexcel AC`row'=matrix(unmettot_mar_ul)
	putexcel AE`row'=matrix(cp_umsex_percent)
	putexcel AF`row'=matrix(cp_umsex_se)
	putexcel AG`row'=matrix(cp_umsex_ll)
	putexcel AH`row'=matrix(cp_umsex_ul)
	putexcel AI`row'=matrix(mcp_umsex_percent)
	putexcel AJ`row'=matrix(mcp_umsex_se)
	putexcel AK`row'=matrix(mcp_umsex_ll)
	putexcel AL`row'=matrix(mcp_umsex_ul)
	putexcel AM`row'=matrix(unmettot_umsex_percent)
	putexcel AN`row'=matrix(unmettot_umsex_se)
	putexcel AO`row'=matrix(unmettot_umsex_ll)
	putexcel AP`row'=matrix(unmettot_umsex_ul)
	local row=`row'+1
	}
	
***** PMA PHASES

putexcel A16=("PMA")
putexcel B17=("phase1")
putexcel B18=("phase2")
local row=17

forval i = 1/`phasecount' {
	use "`phase`i'data'", clear
	if "$level1"!="" {
		numlabel, remove force
		decode $level1_var, gen(str_$level1_var)
		keep if str_$level1_var=="$caps_level1"
		}
	putexcel C`row'=("`phase`i'dates'")
	
capture rename EA EA_ID
capture rename ClusterID Cluster_ID

* Generate Unmarried sexually active	
	cap drop umsexactive
	gen umsexactive=0 
	replace umsexact=1 if (FQmarital_status!=1 & FQmarital_status!=2 & FQmarital_status !=.) & ((last_time_sex==2 & last_time_sex_value<=4 & last_time_sex_value>=0) | ///
	(last_time_sex==1 & last_time_sex_value<=30 & last_time_sex_value>=0) | (last_time_sex==3 & last_time_sex_value<=1 & last_time_sex_value>=0))


** COUNT - Female Sample - All / Married Women  **
preserve
gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & last_night==1
collapse (count) FQresponse_1
mkmat FQresponse_1
putexcel D`row'=matrix(FQresponse_1)
restore
preserve
gen FQresponse_1=1 if FRS_result==1 & HHQ_result==1 & last_night==1 & (FQmarital_status==1 | FQmarital_status==2)
collapse (count) FQresponse_1
mkmat FQresponse_1
putexcel Q`row'=matrix(FQresponse_1)
restore 
preserve
gen FQresponse_3=1 if FRS_result==1 & HHQ_result==1 & last_night==1 &umsexactive == 1
collapse (count) FQresponse_3
mkmat FQresponse_3
putexcel AD`row'=matrix(FQresponse_3)
restore 


*** Estimate Percentage and 95% CI
keep if FRS_result==1 & HHQ_result==1 & last_night==1
egen all=tag(FQmetainstanceID)
egen mar=tag(FQmetainstanceID) if (FQmarital_status==1 | FQmarital_status==2)
egen umsex = tag(FQmetainstanceID) if umsexactive == 1


if "`strata'"!="" {
	capture egen strata=concat(`strata'), punct(-)
	}
else{
	gen strata=1
	}
	
svyset `PSU' [pw=`FQweight'], strata(strata) singleunit(scaled)
foreach group in all mar umsex {
	preserve
	keep if `group'==1
	foreach indicator in cp mcp unmettot {
		svy: prop `indicator', citype(wilson) percent
		matrix reference=r(table)
		matrix `indicator'_`group'_percent=round(reference[1,2]	, .01)
		matrix `indicator'_`group'_se=round(reference[2,2], .01)
		matrix `indicator'_`group'_ll=round(reference[5,2], .01)
		matrix `indicator'_`group'_ul=round(reference[6,2], .01)
		}	
	restore
	}
putexcel E`row'=matrix(cp_all_percent)
putexcel F`row'=matrix(cp_all_se)
putexcel G`row'=matrix(cp_all_ll)
putexcel H`row'=matrix(cp_all_ul)
putexcel I`row'=matrix(mcp_all_percent)
putexcel J`row'=matrix(mcp_all_se)
putexcel K`row'=matrix(mcp_all_ll)
putexcel L`row'=matrix(mcp_all_ul)
putexcel M`row'=matrix(unmettot_all_percent)
putexcel N`row'=matrix(unmettot_all_se)
putexcel O`row'=matrix(unmettot_all_ll)
putexcel P`row'=matrix(unmettot_all_ul)
putexcel R`row'=matrix(cp_mar_percent)
putexcel S`row'=matrix(cp_mar_se)
putexcel T`row'=matrix(cp_mar_ll)
putexcel U`row'=matrix(cp_mar_ul)
putexcel V`row'=matrix(mcp_mar_percent)
putexcel W`row'=matrix(mcp_mar_se)
putexcel X`row'=matrix(mcp_mar_ll)
putexcel Y`row'=matrix(mcp_mar_ul)
putexcel Z`row'=matrix(unmettot_mar_percent)
putexcel AA`row'=matrix(unmettot_mar_se)
putexcel AB`row'=matrix(unmettot_mar_ll)
putexcel AC`row'=matrix(unmettot_mar_ul)
putexcel AE`row'=matrix(cp_umsex_percent)
putexcel AF`row'=matrix(cp_umsex_se)
putexcel AG`row'=matrix(cp_umsex_ll)
putexcel AH`row'=matrix(cp_umsex_ul)
putexcel AI`row'=matrix(mcp_umsex_percent)
putexcel AJ`row'=matrix(mcp_umsex_se)
putexcel AK`row'=matrix(mcp_umsex_ll)
putexcel AL`row'=matrix(mcp_umsex_ul)
putexcel AM`row'=matrix(unmettot_umsex_percent)
putexcel AN`row'=matrix(unmettot_umsex_se)
putexcel AO`row'=matrix(unmettot_umsex_ll)
putexcel AP`row'=matrix(unmettot_umsex_ul)
local row=`row'+1
}


