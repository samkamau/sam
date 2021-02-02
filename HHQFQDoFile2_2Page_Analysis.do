clear
clear matrix
clear mata
set maxvar 15000
set more off
numlabel, add

/*******************************************************************************
*
*  FILENAME:	PMA_HHQFQ_4Pager_Analysis_$date.do
*  PURPOSE:		PMA HHQ/FQ two page data analysis
*  CREATED:		
*  DATA IN:		CCPX_WealthWeightFemale_$date.dta
*  DATA OUT:	CCPX_HHQFQ_4Pager_Analysis_$date.dta
*  UPDATES:		
*				
*******************************************************************************/

*******************************************************************************
* SET MACROS
*******************************************************************************

* Set macros for country and round
local CCPX $CCPX
local strata $strata
	
********************************************************************************
* Set macros for education - No school or upto primary school will be coded as none_primary_education
local none_primary_education $none_primary_education
local secondary_education $secondary_education
local tertiary_education  $tertiary_education

*******************************************************************************
* PREPARE DATA FOR ANALYSIS
*******************************************************************************
cd "$datadir"

* EXPORT RESPONSE RATES OF HHQ and FQ
* First use household data to show response rates

use "`CCPX'_WealthWeightAll_$date",clear
capture rename wealth_ wealth

if "$level1"!="" {
	rename HHweight_$caps_level1 HHweight
	rename FQweight_$caps_level1 FQweight
	}
	
preserve
keep if metatag==1 
gen responserate=0 if HHQ_result>=1 & HHQ_result<6
replace responserate=1 if HHQ_result==1
label define responselist 0 "Not complete" 1 "Complete"
label val responserate responselist

tabout responserate using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", replace ///
	cells(freq col) h1("Household response rate") f(0 1) clab(n %)
restore

* Response rate among all women
gen FQresponserate=0 if eligible==1 & last_night==1
replace FQresponserate=1 if FRS_result==1 & last_night==1
label define responselist 0 "Not complete" 1 "Complete"
label val FQresponserate responselist

tabout FQresponserate if HHQ_result==1 using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append ///
	cells(freq col) h1("Female response rate") f(0 1) clab(n %)	
	
* Restrict analysis to women who completed questionnaire and households with completed questionnaire
keep if FRS_result==1 & HHQ_result==1

* Restrict analysis to women who slept in the house the night before (de facto)
keep if last_night==1

* Save data set so can replicate analysis results later
save "`CCPX'_HHQFQ_4Page_Analysis_$date.dta", replace

* Check for duplicates 
duplicates report FQmetainstanceID
codebook FQmetainstanceID

capture confirm var strata 
if _rc==0 {
	local strata strata
	}

* Set survey weights
svyset EA [pweight=FQweight], strata(`strata') singleunit(scaled)

*******************************************************************************
* PREPARE DATA TO RUN 4-PAGE ANALYSIS
*******************************************************************************
* GENERATE ALL DISAGGREGATORS 

* Generate variable that represents number of observations - all women in the sample
gen one=FRS_result
label var one "All women"

* Generate dichotomous "married" variable to represent all women married or currently living with a man
gen married=(FQmarital_status==1 | FQmarital_status==2)
label define married_list 0 "Single/Divorced/Widowed/Seperated" 1 "Married/Currently living with a man"
label values married married_list
label variable married "Married or currently living with a man"

 * Generate 0/1 urban/rural variable
capture confirm var ur 
if _rc==0 {
gen urban=ur==1
label variable urban "Urban/rural place of residence"
label define urban 1 "Urban" 0 "Rural"
label value urban urban
tab urban, mis
}
else {
gen urban=1
label variable urban "No urban/rural breakdown"
}

* Age group
	recode age -99=. -88=. -77=.
	egen age_cat5=cut(FQ_age) , at (15(5)50)
	label define age_cat5_lab 15 "15-19" 20 "20-24" 25 "25-29" 30 "30-34" 35 "35-39" 40 "40-44" 45 "45-49" 50 ">=50"
	label values age_cat5 age_cat5_lab
	label var age_cat5 "Age Categories (by 5 years)"
	
	recode age -99=. -88=. -77=.
	egen age_cat=cut(FQ_age) , at (15,20,25,50)
	label define age_cat_lab 15 "15-19" 20 "20-24" 25 "25-49" 
	label values age_cat age_cat_lab
	label var age_cat "Age Categories (years)"

* Education 
gen none_primary_education = `none_primary_education' 
gen secondary_education  = `secondary_education' 
gen tertiary_education =  `tertiary_education' 
	
gen education = 1 if none_primary_education == 1
replace education = 2 if secondary_education == 1
replace	education = 3 if tertiary_education == 1
label define education_list 1 "None/Primary education" 2 "Secondary Education" 3 "Tertiary Education"
label values education education_list
label var education "Highest level of education attained"

* Parity
* Create categorical parity variable
replace birth_events=. if birth_events ==-88 | birth_events ==-99
egen parity=cut(birth_events), at (0, 1, 3, 5) icodes
label define paritylist 0 "None" 1 "One-Two" 2 "Three-Four" 3 "Five+"
replace parity=3 if birth_events>=5 & birth_events!=.
label val parity paritylist

* Unmarried sexually active
* Generate dichotomous sexually active unmarried women variable
cap drop umsexactive
gen umsexactive=0 
replace umsexact=1 if (FQmarital_status!=1 & FQmarital_status != 2 & FQmarital_status !=.) & ((last_time_sex==2 & last_time_sex_value<=4 & last_time_sex_value>=0) | (last_time_sex==1 & last_time_sex_value<=30 & last_time_sex_value>=0) | (last_time_sex==3 & last_time_sex_value<=1 & last_time_sex_value>=0))

*Generate sexually active variable
gen sexactive= (last_time_sex==2 & last_time_sex_value<=4 & last_time_sex_value>=0) | (last_time_sex==1 & last_time_sex_value<=30 & last_time_sex_value>=0)| (last_time_sex==3 & last_time_sex_value<=1 & last_time_sex_value>=0) 
	
* Work
gen work = 0 
replace work = 1 if (work_yn_12mo == 1| work_yn_7days == 1)
replace work =. if (work_yn_12mo == . & work_yn_7days == .)
label values work yes_no_dnk_nr_list
label var work "Aside from household work, have you done any work in the last 12 months or 7 days"
	
* Intention to use
gen intention_use = 0 
replace intention_use=1 if fp_start==1 | fp_start==3 | (fp_start==2 & fp_start_value<=1)

label values intention_use yes_no_dnk_nr_list
label var intention_use "Intention to use contraception in the future/in the next year"
tab intention_use, m
			
*******************************************************************************
* UNINTENDED BIRTHS
*******************************************************************************
* Percent of Recent births unintended

* Generate wantedness variable that combines results from last birth and current pregnancy questions
gen wanted=pregnancy_desired if recent_birth != "" & ever_birth == 1 & month_calculation<="60"
recode wanted -88=0 -99=0 
label variable wanted "Intendedness of previous birth/current pregnancy (categorical): then, later, not at all"
label def wantedlist 1 "then" 2 "later" 3 "not at all"
label val wanted wantedlist
tab wanted, mis

* Generate dichotomous intendedness variables that combines births wanted "later" or "not at all"
gen unintend=1 if wanted==2 | wanted==3
replace unintend=0 if wanted==1
label variable unintend "Intendedness of previous birth/current pregnancy (dichotomous)"
label define unintendlist 0 "intended" 1 "unintended"
label values unintend unintendlist

* Percent wanted later
gen wanted_later = 1 if wanted == 2
replace wanted_later = 0 if wanted == 1| wanted == 3
label variable wanted_later "% Wanted later" 
label define wanted_laterlist 0 "Wanted then or not at all" 1"Wanted later"
label values wanted_later wanted_laterlist

* Percent not wanted at all
gen wanted_nomore = 1 if wanted == 3
replace wanted_nomore = 0 if wanted == 1| wanted == 2
label variable wanted_nomore "% Wanted nomore" 
label define wanted_nomorelist 1 "Wanted none at all" 0"Wanted then or later"
label values wanted_nomore wanted_nomorelist

*******************************************************************************
* WGE Score
*******************************************************************************
********************************************************************************
* Variable Generation: Contraceptive Existence of Choice (motivational autonomy)
********************************************************************************
* Create composite variable for would/could conflict
	gen wge_conflict=wge_will_conflict
	replace wge_conflict=wge_could_conflict if wge_conflict==.
	label var wge_conflict "If I use FP it could/will cause conflict in my relationship" 
	label val wge_conflict agree_down5_list

* Reverse scores for low empowerment direction measures
foreach v of var wge_seek_partner wge_trouble_preg wge_conflict ///
		wge_abnormal_birth wge_body_side_effects {
		local `v'_lab : variable label `v'
		gen `v'_rev=.
		replace `v'_rev=1 if `v'==5
		replace `v'_rev=2 if `v'==4
		replace `v'_rev=3 if `v'==3
		replace `v'_rev=4 if `v'==2
		replace `v'_rev=5 if `v'==1
		label var `v'_rev "REVERSE ``v'_lab'" 
	}

* Create composite variables for Contraceptive Existence of Choice
	*Mean impute
foreach var in wge_seek_partner_rev wge_trouble_preg_rev wge_conflict_rev ///
		wge_abnormal_birth_rev wge_body_side_effects_rev {

	*Store mean value of reversed
	quietly sum `var'
	local `var'_m r(mean)
	
	*Replace missing values with the mean of the recode
	gen `var'_rc=`var'
	replace `var'_rc=``var'_m' if `var'==.
	}

egen fp_aut_mean_score=rowmean(wge_seek_partner_rev_rc wge_trouble_preg_rev_rc ///
		wge_conflict_rev_rc wge_abnormal_birth_rev_rc wge_body_side_effects_rev_rc)
	label var fp_aut_mean_score "Mean WGE FP autonomy score"

*Create absolute quintiles
	gen fp_aut_quint=.
	replace fp_aut_quint=1 if fp_aut_mean_score>=1 & fp_aut_mean_score<=2
	replace fp_aut_quint=2 if fp_aut_mean_score>2 & fp_aut_mean_score<=3
	replace fp_aut_quint=3 if fp_aut_mean_score>3 & fp_aut_mean_score<=4
	replace fp_aut_quint=4 if fp_aut_mean_score>4 & fp_aut_mean_score<5
	replace fp_aut_quint=5 if fp_aut_mean_score==5

********************************************************************************
* Variable Generation: Contraceptive Exercise of Choice (Self-efficacy)
********************************************************************************
*Mean impute
	foreach var in wge_switch_fp wge_confident_switch {

	local `var'_lab: variable label `var'
	
	*Store mean value of recode
	recode `var' -99 -88 =.
	quietly sum `var'
	local `var'_m r(mean)
	
	*Replace missing values with the mean of the recode
	gen `var'_rc=`var'
	replace `var'_rc=``var'_m' if `var'==.
	}

* Create composite variable for Contraceptive Exercise of Choice	
	gen fp_se_mean_score=(wge_switch_fp_rc+wge_confident_switch_rc)/2
	label var fp_se_mean_score "Mean FP exercise of choice score"
	sum fp_se_mean_score

*Create absolute quintiles
	gen fp_se_quint=. 
	replace fp_se_quint=1 if fp_se_mean_score>=1 & fp_se_mean_score<=2
	replace fp_se_quint=2 if fp_se_mean_score>2 & fp_se_mean_score<=3
	replace fp_se_quint=3 if fp_se_mean_score>3 & fp_se_mean_score<=4
	replace fp_se_quint=4 if fp_se_mean_score>4 & fp_se_mean_score<5
	replace fp_se_quint=5 if fp_se_mean_score==5
	tab fp_se_quint, m
	bysort fp_se_quint: summ fp_se_mean_score

********************************************************************************
* Variable Generation: Combined Indicator
********************************************************************************
egen fp_wge_comb=rowmean(wge_seek_partner_rev_rc wge_trouble_preg_rev_rc wge_conflict_rev_rc wge_abnormal_birth_rev_rc wge_body_side_effects_rev_rc wge_switch_fp_rc wge_confident_switch_rc)
label var fp_wge_comb "Mean combined FP WGE score"

gen wge_quint=. 
	replace wge_quint=1 if fp_wge_comb>=1 & fp_wge_comb<=2
	replace wge_quint=2 if fp_wge_comb>2 & fp_wge_comb<=3
	replace wge_quint=3 if fp_wge_comb>3 & fp_wge_comb<=4
	replace wge_quint=4 if fp_wge_comb>4 & fp_wge_comb<5
	replace wge_quint=5 if fp_wge_comb==5
	
label var wge_quint "WGE Quintile values, from least to most"	
	
*******************************************************************************
* MII
*******************************************************************************
* Tabout told of other methods by marital_status (weighted) among current users
recode fp_told_other_methods -88 -99=.

* Tabout counseled on side effects by marital_status (weighted) among current users
recode fp_side_effects -88 -99=.

* Tabout counseled on what to do in case of side effects by marital_status (weighted) among current users
recode fp_side_effects_instructions -88 -99=.

* Tabout counseled on what to do in case of side effects by marital_status (weighted) among current users
recode fp_told_future_switch -88=. -99=.

gen mii = 0
replace mii = 1 if fp_told_future_switch == 1 & fp_side_effects == 1 & fp_told_other_methods == 1 & fp_side_effects_instructions==1
replace mii= . if fp_provider_rw == .

label define mii_list 1 "YES for all four MII sub-categories" 0 "No for at least one"
label values mii mii_list
label var mii "Method Information Index"

*******************************************************************************
* PERSONAL NORMS
*******************************************************************************
label define self_list 1 "Strongly Agree/Agree" 0 "Disagree/Strongly Disagree"
foreach var in fp_promiscuous fp_married fp_no_child fp_lifestyle {
	recode `var'_self -88=. -99=. 
	gen self_`var' = 1 if `var'_self  == 1|`var'_self == 2
	replace self_`var' = 0 if `var'_self == 3|`var'_self == 4 
	label values self_`var' self_list
	}
label var  self_fp_promiscuous "Self View:Adolescents who use FP are promiscuous"
label var self_fp_married "Self View:FP is only for married women"
label var self_fp_no_child "Self View:FP is only for women who dont want any children"
label var self_fp_lifestyle "Self View: People who use FP have a better quality of life"

*******************************************************************************
* Information received at provider
*******************************************************************************
* Percent received FP information from visiting provider or health care worker at facility
recode visited_by_health_worker -88 -99=0
recode facility_fp_discussion -88 -99=0
gen healthworkerinfo=0
replace healthworkerinfo=1 if visited_by_health_worker==1 | facility_fp_discussion==1
label values healthworkerinfo yes_no_dnk_nr_list
label variable healthworkerinfo "Received family planning info from provider/community health worker in last 12 months"
tab healthworkerinfo [aweight=FQweight]

*******************************************************************************
*** CONTRACEPTIVE USE AND UNMET NEED 
*******************************************************************************

* Tabout current/recent method if using modern contraceptive method, among married women
tabout current_methodnumEC [aweight=FQweight] if mcp==1 & married==1 using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append c(col) f(1) clab(%) npos(row)  h2("Method mix - married women (weighted)")

* Tabout current/recent method if using modern contraceptive method, among unmarried sexually active women
capture tabout current_methodnumEC [aweight=FQweight] if mcp==1 & umsexactive==1 using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append c(col) f(1) clab(%) npos(row)  h2("Method mix - unmarried sexually active women (weighted)") 

tabout unintend wanted_later wanted_nomore [aweight=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append oneway c(col) f(1) clab(%) npos(row)  h2("Fertility Intention Indicators among all women with births in last 5 years (weighted)")
 
*******************************************************************************
****CLIENT PERCEPTIONS OF FP SERVICES RECEIVED 
** METHOD INFORMATION INDEX
*******************************************************************************
tabout mii fp_told_other_methods fp_side_effects fp_side_effects_instructions fp_told_future_switch [aweight=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", oneway append c(col) f(1) clab(%) npos(row)  h2("MII Indicators among all current modern users (weighted)")

* Discussed fp in the past year with provider/community health worker
tabout healthworkerinfo age_cat [aweight=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append  c(col) f(1) clab(%) npos(row)  h1("Discussed FP in the past year with a provider/community health worker by age (weighted)- All Women")

*******************************************************************************
*******PARTNER DYNAMICS*********************
*******************************************************************************
foreach var in partner_know partner_decision why_not_decision partner_overall {
recode `var' -99=. 
}

tabout partner_know partner_decision if mcp == 1 [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append oneway c(col) f(1) clab(%) npos(row) h2("Partner Dynamics among Modern Method Users (Female Controlled)(weighted)")

tabout why_not_decision [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append c(col) f(1) clab(%) npos(row) h2("Partner Dynamics among Non-Users (weighted)") 

tabout partner_overall [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append c(col) f(1) clab(%) npos(row) h2("Partner Dynamics among Users (weighted)") 

*******************************************************************************
*******WGE SCORE AND COMPONENTS*********************
******************************************************************************* 
tabout wge_switch_fp wge_confident_switch [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append oneway c(col) f(1) clab(%) npos(row) h2("Exercise of Choice for Family Planning-All Women(weighted)")

tabout wge_seek_partner wge_trouble_preg wge_conflict wge_abnormal_birth wge_body_side_effects [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", ///
	append oneway c(col) f(1) clab(%) npos(row) h2("Existence of Choice for Family Planning-All Women(weighted)")

foreach v of var education age_cat {
	tabout `v' using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append sum cells(mean fp_wge_comb) npos(row) h2("Mean WGE Score by `v'")
	}
	
tabout mcp wge_quint [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append cells(col) h1("mcp by WGE Quintile- All women") f(1) clab(%) nwt(FQweight) npos(row)

tabout intention_use wge_quint [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append cells(col) h1("Intent to Use by WGE Quintile-All Women") f(1) clab(%) nwt(FQweight) npos(row)

tabout mcp work [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append cells(col) h1("mcp by Household Work-All women") f(1) clab(%) nwt(FQweight) npos(row)

tabout intention_use work [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append cells(col) h1("Intent to use by Household Work-All Women") f(1) clab(%) nwt(FQweight) npos(row)


*******************************************************************************
*****ATTITUDES TOWARDS CONTRACEPTION
*******************************************************************************
foreach x in age_cat urban cp {
	foreach var in fp_promiscuous fp_married fp_no_child fp_lifestyle {
		tabout self_`var' `x' [aweight=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append c(col) f(1) clab(%) npos(row)  h1("Personal Norms by `x' (weighted)")
		} 
	}

*******************************************************************************
* REPRODUCTIVE TIMELINE INDICATORS 
*******************************************************************************
* Generate variables like in DHS, birth date in cmc
destring birthmonth birthyear, replace
gen birthmonth1=birthmonth
replace birthmonth=6 if birthmonth==-88
gen v011=(birthyear-1900)*12 + birthmonth 

*******************************************************************************
* MEANS AND MEDIANS
*******************************************************************************
**Define the program to calculate medians
cap program drop pmamediansimple
program define pmamediansimple

use `1', clear
keep if FQ_age>=`3' //age range for the tabulation

gen one=1
drop if `2'==.
collapse (count) count=one [pweight=FQweight], by(`2')
sort  `2'
gen ctotal=sum(count)
egen total=sum(count)
gen cp=ctotal/total

keep if (cp <= 0.5 & cp[_n+1]>0.5) | (cp>0.5 & cp[_n-1]<=0.5)

local median=(0.5-cp[1])/(cp[2]-cp[1])*(`2'[2]-`2'[1])+`2'[1] +1

macro list _median

clear
set obs 1
gen median=`median'

end
capture drop one

* Generate age at first marriage by "date of first marriage - date of birth"
	* Get the date for those married only once from FQcurrent*
	* Get the date for those married more than once from FQfirst*

* Marriage cmc already defined in unmet need 

* Generate median age of first marriage 
capture drop agemarriage
gen agemarriage=(marriagecmc-v011)/12
label variable agemarriage "Age at first marriage (25 to 49 years)"
save, replace

*ssc install listtab, all replace
* Median age at marriage among all women who have married
preserve
save tem, replace
pmamediansimple tem agemarriage 25 
gen urban="All Women"
tempfile total
save `total', replace 
restore

preserve
keep if urban==0
capture codebook metainstanceID
if _rc!=2000{ 
save tem, replace
pmamediansimple tem agemarriage 25
gen urban="Rural"
tempfile rural
save `rural', replace
}
restore 

preserve
keep if urban==1
capture codebook metainstanceID
if _rc!=2000{ 
save tem, replace
pmamediansimple tem agemarriage 25
gen urban="Urban"
tempfile urban
save `urban', replace
}
restore 

preserve
use `total', clear
capture append using "`rural'"
append using "`urban'"

listtab urban median , appendto("`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls") rstyle(tabdelim) headlines("Median age at marriage among all women who have married- by urban/rural (weighted)") footlines(" ")
restore

*Median age at first sex among all women who have had sex
preserve
keep if age_at_first_sex>0 & age_at_first_sex<50 
save tem, replace
pmamediansimple tem age_at_first_sex 15
gen urban="All Women"
tempfile total
save `total', replace
restore

preserve 
keep if age_at_first_sex>0 & age_at_first_sex<50 & urban==0
capture codebook metainstanceID
if _rc!=2000 {
save tem, replace
pmamediansimple tem age_at_first_sex 15
gen urban="Rural"
tempfile rural
save `rural', replace 
}
restore

preserve 
keep if age_at_first_sex>0 & age_at_first_sex<50 & urban==1 
capture codebook metainstanceID
if _rc!=2000 {
save tem, replace
pmamediansimple tem age_at_first_sex 15
gen urban="Urban"
tempfile urban
save `urban',replace
}
restore

preserve
use `total', clear
capture append using `rural'
append using `urban'
listtab urban median , appendto("`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls") rstyle(tabdelim)  headlines("Median age at first sex - among all women who have had sex by urban/rural(weighted)") footlines(" ")
restore

* Median age at first contraceptive use among all women who have ever use contraception
preserve
keep if fp_ever_used==1 & age_at_first_use>0
save tem, replace
pmamediansimple tem age_at_first_use 15
gen urban="All Women"
tempfile total
save `total', replace
restore

preserve
keep if fp_ever_used==1 & age_at_first_use>0 & urban==0
capture codebook metainstanceID
if _rc!=2000 {
save tem, replace
pmamediansimple tem age_at_first_use 15
gen urban="Rural"
tempfile rural
save `rural', replace
}
restore

preserve
keep if fp_ever_used==1 & age_at_first_use>0 & urban==1
capture codebook metainstanceID
if _rc!=2000 {
save tem, replace
pmamediansimple tem age_at_first_use 15
gen urban="Urban"
tempfile urban
save `urban', replace
}
restore

preserve
use `total', clear
capture append using `rural'
append using `urban'
listtab urban median , appendto("`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls") rstyle(tabdelim)  headlines("Median age at first contraceptive use - among all women who have used contraception by urban/rural (weighted)") footlines(" ")
restore

* Generate age at first birth by subtracting birth date from age at first birth and dividing by hours in a year
capture drop agefirstbirth
capture replace first_birthSIF=recent_birthSIF if birth_events==1
capture replace first_birthSIF=recent_birthSIF if children_born==1 
gen agefirstbirth=(first_birthSIF-birthdateSIF)/365.25


* Median age at first birth among all women who have ever given birth
preserve
keep if ever_birth==1
save tem, replace
pmamediansimple tem agefirstbirth 25
gen urban="All Women"
tempfile total
save `total', replace
restore

preserve
keep if ever_birth==1 & birth_events!=. & birth_events!=-99 & urban==0
capture codebook metainstanceID 
if _rc!=2000 {
save tem, replace
pmamediansimple tem agefirstbirth 25
gen urban="Rural"
tempfile rural
save `rural', replace
}
restore

preserve
keep if ever_birth==1 & birth_events!=. & birth_events!=-99 & urban==1
capture codebook metainstanceID 
if _rc!=2000 {
save tem, replace
pmamediansimple tem agefirstbirth 25
gen urban="Urban"
tempfile urban
save `urban', replace
}
restore

preserve
use `total', clear
capture append using "`rural'"
append using "`urban'"
listtab urban median , appendto("`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls") rstyle(tabdelim)  headlines("Median age at first birth - among all women who have given birth by urban/rural(weighted)") footlines(" ")
restore

* Percent women 18-24 who are married by age 18
gen married18=0 if FQ_age>=18 & FQ_age<25
replace married18=1 if agemarriage<18 & married18==0
label variable married18 "Married by age 18"
tab married18 [aw=FQweight]
tab urban married18 [aw=FQweight], row

* Percent of women age 18-24 having first birth by age 18 
capture drop birth18
gen birth18=0 if FQ_age>=18 & FQ_age<25
replace birth18=1 if agefirstbirth<18 & birth18==0
label variable birth18 "Birth by age 18 (18-24)"
tab birth18 [aw=FQweight]
tab urban birth18 [aw=FQweight], row
	
* Percent women 18-24 who have had first contraceptive use by age 18
gen fp18=0 if FQ_age>=18 & FQ_age<25
replace fp18=1 if age_at_first_use>0 & age_at_first_use<18 & fp18==0 
label variable fp18 "Used contraception by age 18"
tab fp18 [aw=FQweight]
tab urban fp18 [aw=FQweight], row

* Percent women who had first sex by age 18
gen sex18=0 if FQ_age>=18 & FQ_age<25
replace sex18=1 if age_at_first_sex>0 & age_at_first_sex<18 & sex18==0 
label variable sex18 "Had first sex by age 18"
tab sex18 [aw=FQweight]
tab urban sex18 [aw=FQweight], row

* Label yes/no response options
foreach x in married18 birth18 fp18 sex18 {
	label values `x' yes_no_dnk_nr_list
	}

tabout married18 sex18 fp18 birth18 [aw=FQweight] if FQ_age>=18 & FQ_age<25 using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append oneway c(col) f(1) clab(%) npos(row) 	///
h2("Married by 18, first sex by 18, contraceptive use by 18, first birth before 18 - women age 18-24 (weighted)") 

* Tabout mean no. of living children at first contraceptive use among women who have ever used contraception 
replace age_at_first_use_children=0 if ever_birth==0 & fp_ever_used==1
tabout urban [aweight=FQweight] if fp_ever_used==1 & age_at_first_use_children>=0 using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append sum c(mean age_at_first_use_children) f(3) npos(row)  h2("Mean number of children at first contraceptive use - among all women who have used contraception (weighted)") 

*******************************************************************************
*****OBTAINED METHOD FROM PUBLIC FACILITY
*******************************************************************************
recode fp_provider_rw (1/19=1 "public") (-88 -99=0) (nonmiss=0 "not public"), gen(publicfp_rw)
label variable publicfp_rw "Respondent or partner for method got first time from public provider"
	
tabout publicfp_rw if mcp==1 [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls", append c(col) f(1) npos(row)  h2("Respondent/partner received method from public facility  - current modern user (weighted)") 
	
*******************************************************************************
* DEMOGRAPHIC VARIABLES
*******************************************************************************
recode school -99=.
tabout age_cat5  [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls",  append  ///
c(freq col) f(0 1) clab(n %) npos(row)  h2("Distribution of de facto women by age - weighted")

tabout school  [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls",  append  ///
c(freq col) f(0 1) clab(n %) npos(row)  h2("Distribution of de facto women by education - weighted")

tabout FQmarital_status [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls",  append  ///
c(freq col) f(0 1) clab(n %) npos(row)  h2("Distribution of de facto women by marital status - weighted")

tabout wealth  [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls",  append  ///
c(freq col) f(0 1) clab(n %) npos(row)  h2("Distribution of de facto women by wealth - weighted")

capture tabout urban [aw=FQweight] using "`CCPX'_HHQFQ_4Pager_Analysis_Output_$date.xls",  append ///
c(freq col) f(0 1) clab(n %) npos(row)  h2("Distribution of de facto women by urban/rural - weighted")

*******************************************************************************
* CLOSE
*******************************************************************************

if "$level1"!="" {
	rename HHweight HHweight_$caps_level1 
	rename FQweight FQweight_$caps_level1 
	}	

	
save, replace
