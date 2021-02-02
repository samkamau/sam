clear all

**********************************
*****Set Macros******
**********************************

*Macro for country phase
local CCPX $CCPX

*Dataset to use
use "$datadir/`CCPX'_WealthWeightAll_30Jan2021.dta",clear

if "$level1"!="" {
	rename HHweight_$caps_level1 HHweight
	rename FQweight_$caps_level1 FQweight
	}

*Macros for the years in the calendar
local firstyear $firstyear
local lastyear $lastyear

*Macro for the number of months in the full calendar (36 or 48 depending on if the calendar was over 3 or 4 years)
local cal_len = $cal_len

**********************************
*****Stop Macros******
**********************************
cd "$datadir"

* Install Programs you may need
*ssc install stcompet, replace 

*Restrict the data to only variables you need
keep FQmetainstanceID cc_col1_* cc_col2_* FQdoi_correctedSIF level1 FQweight*
duplicates tag FQmetainstanceID, gen(d)
keep if d== 0 

* Step 1 : Rename Contraceptive Calendar Month by Month Data serially in the order of the calendar with *_1 being the month prior to interview month. Interview month is denoted with *_0 (Step 1a). Generate variables that document the number of changes in contraceptive use status (Refer Step 1b)  

*Step 1.a
local cc_m = 1
forval y = `firstyear'/`lastyear' {
	forval m = 1/12 {
			rename cc_col*_`y'_`m' cc_col*_`cc_m'a 
			local cc_m=`cc_m'+1
			}
	}
	rename cc_col*a cc_col*

* Step 1b
/* Note: 
* Events refer to a change in status of method use either due to discontinuation, adopting a new method, switching a method, pregnancies, births and terminations. Event number increases by 1 unit for every change in contraceptive use status or pregnancy and related status. 
* Episodes refer to the total number of events for a woman
*/

* Set episode number - initialized to 0
gen episodes_tot = 0
* Set previous calendar column 1 variable to anything that won't be in the calendar
gen prev_cal_col = -1

* Create variable to identify unique episodes of use
forvalues j = `cal_len'(-1)1 {
  local i = `cal_len' - `j' + 1
  * Increase the episode number if there is a change in cc_col1_
  replace episodes_tot = episodes_tot+1 if cc_col1_`i' != prev_cal_col
  * Set the episode number
  gen int event_number`i' = episodes_tot
  * Save the cc_col1_* value for the next time through the loop
  replace prev_cal_col = cc_col1_`i'
}

* Step 2: Reshape to data into Long Format and drop unnnecessary variables
* Drop the calendar variables now we have the separate month by month variables
drop *_full episodes_tot prev_cal_col
* Reshape the new month by month variables into a long format
reshape long event_number cc_col1_ cc_col2_ , i(FQmetainstanceID) j(i)

* label the event number variable
label variable event_number "Event number"

* Step 3 - Generate Century Month Code for start of calendar and date of interview
/* Note:
* Reference 1900 and Month is January, of the first year of the calendar which is where the calendar starts = Start of Survey
*/
gen start_cmc = ((`firstyear'-1900)*12)+1
gen cmc=start_cmc+i-1

* CMC Dates for today
replace FQdoi_correctedSIF=dofc(FQdoi_correctedSIF)
format FQdoi_correctedSIF %td
gen today_cmc = ((year(FQdoi_correctedSIF)-1900)*12)+month(FQdoi_correctedSIF) 

* Drop blank episodes occurring after the date of interview 
drop if cmc > today_cmc

*Step 4: Generate Events File 
* 4a Collapse the episodes within each case, keeping start and end, the event code,
* and other useful information 
*4b Generate Variables that document current, previous and next Event status 
*4c Label all variables 

* Step 4a
collapse FQweight* today_cmc start_cmc (first) event_start=cmc (last) event_end=cmc (count) event_duration=cmc ///
  (last) event_code_numeric=cc_col1_ discontinuation_code_numeric=cc_col2_, by(FQmetainstanceID event_number)

* label the variables created in the collapse statement
label variable event_start  "CMC event begins"
label variable event_end  "CMC event ends"
label variable event_duration "Duration of event"
label variable event_code_numeric "Event code"
label variable discontinuation_code_numeric "Discontinuation Code"
format event_number %2.0f
format event_start event_end %4.0f

* Step 4b				
* capture the previous event and its duration for each respondent
by FQmetainstanceID:gen previous_event = event_code_numeric[_n-1] if _n > 1
by FQmetainstanceID:gen previous_event_dur = event_duration[_n-1] if _n > 1

* capture the following event and its duration for this respondent
by FQmetainstanceID:gen next_event = event_code_numeric[_n+1]  if _n < _N
by FQmetainstanceID:gen next_event_dur = event_duration[_n+1]  if _n < _N

* Step 4c
* label the event file variables and values
label variable event_code_numeric  "Current Event code"
label variable discontinuation_code_numeric   "Discontinuation code"
label variable previous_event  "Prior event code"
label variable previous_event_dur "Duration of prior event"
label variable next_event  "Next event code"
label variable next_event_dur "Duration of next event"
label values previous_event cc_option1_list
label values next_event cc_option1_list
label values event_code_numeric cc_option1_list
label values discontinuation_code_numeric cc_option2_list

format event_duration event_code_numeric discontinuation_code_numeric	///
	previous_event previous_event_dur next_event next_event_dur %2.0f	
	
* save the events file
save `CCPX'_eventsfile.dta, replace

* Step 5
* Use Events File to generate Discontinuation Indicators: - 
*Variables Generated in Step 5: Discontinuation; Time from event to Interview; Late Entry Variables; Exposure

* Drop ongoing events as the calendar began
drop if start_cmc == event_start

* drop births, terminations, pregnancies, and episodes of non-use
* keep missing methods. to exclude missing change 99 below to 100.
drop if (event_code_numeric > 39| event_code_numeric ==0 ) & event_code_numeric!=.

* time from beginning of event to interview
gen tbeg_int = today_cmc - event_start
label var tbeg_int "time from beginning of event to interview"

* time from end of event to interview
gen tend_int = today_cmc - event_end
label var tend_int "time from end of event to interview"

* Generate Discontinuation Variable
gen discont = 0
replace discont = 1 if discontinuation_code_numeric != .
* censoring those who discontinue in last three months
replace discont = 0 if tend_int < 3
label var discont "discontinuation indicator"
tab discont
tab discontinuation_code_numeric discont, m


* Generate late entry variable
gen entry = 0
replace entry = tbeg_int - 23 if tbeg_int >= 24
tab tbeg_int entry

* taking away exposure time outside of the 3 to 23 month window
gen exposure = event_duration
replace exposure = event_duration - (3 - tend_int) if tend_int < 3
recode exposure -3/0=0

* drop those events that started in the month of the interview and two months prior
drop if tbeg_int < 3

* drop events that started and ended before 23 months prior to survey
drop if tbeg_int > 23 & tend_int > 23

* to remove sterilized women or women whose partners use male sterilisation from denominator use the command below - not used for DHS standard
replace exposure = . if (event_code_numeric == 1| event_code_numeric == 2)

* censor any discontinuations that are associated with use > 20 months
replace discont = 0 if (exposure - entry) > 20


* Step 6 
* recode methods, discontinuation reason, and construct switching

* recode contraceptive method
recode event_code_numeric	/// 						
	(7  = 1  )	///* Pills			
	(4  = 2 )	///* IUD 				
	(5 6 16 = 3 )	///* Injectables	 		
	(3 = 4 )	///* Implants				
	(9  = 5 )	///* MC			
	(31  = 7 )	/// * WITHDRAWAL		
	(8 = 8 )	///* EC	
	(14 = 14 )  ///*LAM
	(nonmissing = 9 )	///*other	
	(missing = .), gen(method)	

label define method_list 1 "Pill" 2 "IUD" 3 "Injectables" 4 "Implant" 5 "Male condom" 7 "Withdrawal" 8 "EC" 9 "Other" 14 "LAM"
label values method method_list
tab event_code_numeric method, m

* LAM and Emergency contraception are grouped here
* Other category is Female Sterilization, Male sterilization, Other Traditional, 
*       Female Condom, Other Modern, Standard Days Method
* adjust global meth_list below if changing the grouping of methods above

* recode reasons for discontinuation - ignoring switching
recode discontinuation_code_numeric 			     						///
	(0 .     = .)		     						///
	(2       = 1 "Method failure")	     			///
	(3       = 2 "Desire to become pregnant")		///
	(1 11 12 = 3 "Other fertility related reasons")	///
	(6    = 4 "Side effects/health concerns")	///
	(5       = 5 "Wanted more effective method")	///
	(7 8 9 = 6 "Other method related")			///
	(nonmissing = 7 "Other/DK") if discont==1, gen(reason)
label var reason "Reason for discontinuation"
tab discontinuation_code_numeric reason if discont==1, m

* switching methods
* switching directly from one method to the next, with no gap
sort FQmetainstanceID event_number
by FQmetainstanceID: gen switch = 1 if event_end+1 == event_start[_n+1]
* if reason was "wanted more effective method" allow for a  1-month gap
by FQmetainstanceID: replace switch = 1 if discontinuation_code_numeric == 5 & event_end+2 >= event_start[_n+1] & next_event == 0
* not a switch if returned back to the same method
* note that these are likely rare, so there may be no or few changes from this command
by FQmetainstanceID: replace switch = . if event_code_numeric == event_code_numeric[_n+1] & event_end+1 == event_start[_n+1]
tab switch

* calculate variable for switching for discontinuations we are using
gen discont_sw = .
replace discont_sw = 1 if switch == 1 & discont == 1
replace discont_sw = 2 if discont_sw == . & discontinuation_code_numeric != . & discont == 1
label def discont_sw 1 "switch" 2 "other reason"
label val discont_sw discont_sw
tab discont_sw

* Step 7
* Calculate the competing risks cumulative incidence for each method and for all methods

* create global lists of the method variables included
levelsof method
global meth_codes `r(levels)'
*modify meth_list and methods_list according to the methods included
global meth_list pill iud inj impl mcondom withdr lam ec other
global methods_list `" "Pill" "IUD" "Injectables" "Implant" "Male condom" "Withdrawal" "LAM" "EC" "Other" "All methods" "'
global drate_list 
global drate_list_sw 
foreach m in $meth_list {
	global drate_list $drate_list drate_`m'
	global drate_list_sw $drate_list_sw drate_`m'_sw
}

* competing risks estimates - first all methods and then by method
tokenize allmeth $meth_list
foreach x in 0 $meth_codes {

	* by reason - no switching
	* declare time series data for st commands
	stset exposure if `x' == 0 | method == `x' [iw=FQweight], failure(reason==1) enter(entry)
	stcompet discont_`1' = ci, compet1(2) compet2(3) compet3(4) compet4(5) compet5(6) compet6(7) 
	* convert rate to percentage
	gen drate_`1' = discont_`1' * 100

	* switching
	* declare time series data for st commands
	stset exposure if `x' == 0 | method == `x' [iw=FQweight], failure(discont_sw==1) enter(entry)
	stcompet discont_`1'_sw = ci, compet1(2) 
	* convert rate to percentage
	gen drate_`1'_sw = discont_`1'_sw * 100

	* Get the label for the method and label the variables appropriately
	local lab1 All methods
	if `x' > 0 {
		local lab1 : label method `x'
	}
	label var drate_`1' "Rate for `lab1'"
	label var drate_`1'_sw "Rate for `lab1' for switching"
	
	* shift to next method name in token list
	macro shift
}

* Keep the variables we need for output
keep FQmetainstanceID method drate* exposure reason discont_sw FQweight entry

* save data file with cumulative incidence variables added to each case
save "`CCPX'_drates.dta", replace


* Step 8
* calculate and save the weighted and unweighted denominators
* and convert into format for adding to dataset of results

* calculate unweighted Ns, for entries in the first month of the life table
drop if entry != 0
collapse (count) methodNunwt = entry, by(method)
save "`CCPX'_method_Ns.dta", replace

use "`CCPX'_drates.dta", clear
* calculate weighted Ns, for total episodes including late entries
collapse (count) methodNwt = entry [iw=FQweight], by(method)

* merge in the unweighted Ns
merge 1:1 method using "`CCPX'_method_Ns.dta"

* drop the merge variable
drop _merge

* switch rows (methods) and columns (weighted and unweighted counts)
* to create a file that will have a row for weight Ns and a row for unweighted Ns with methods as the variables
* first transpose the file
xpose, clear
* rename the variables v1 to v9 to match the drate variable list (ignoring all methods)
tokenize $drate_list
local num : list sizeof global(drate_list)
forvalues x = 1/`num' { // this list is a sequential list of numbers up to the count of vars
	rename v`x' `1'
	mac shift
}
* drop the first line with the method code as the methods are now variables
drop if _n == 1
* generate the reason code (to be used last for the Ns)
gen reason = 9 + _n

* save the final Ns - two rows, one for weighhted N, one for unweighted N
save "`CCPX'_method_Ns.dta", replace


* Step 9: Combine components for results output

* Prepare resulting data for output
* This code can be used to produce rates for different durations for use, 
* but is here set for 12-month discontinuation rates

* Loop through possible discontinuation rates for 6, 12, 24 and 36 months
//foreach x in 6 12 24 36 {
* current version presents only 12-month discontinuation rates:
local x 12

* open the working file with the rates attached to each case
use "`CCPX'_drates.dta", clear	

* collect information from relevant time period only
drop if exposure > `x'

* keep only discontinuation information
keep method drate* exposure reason discont_sw FQweight

* save smaller dataset for x-month duration which we will use in collapse commands below
save "`CCPX'_drates_`x'm.dta", replace

* collapsing data for reasons, all reasons, switching, merging and adding method Ns

* reasons for discontinuation
* collapse data by discontinuation category and save
collapse (max) $drate_list drate_allmeth, by(reason)
* drop missing values
drop if reason == .
save "`CCPX'_reasons.dta", replace

* All reasons
* calculate total discontinuation and save
collapse (sum) $drate_list drate_allmeth
gen reason = 8
save "`CCPX'_allreasons.dta", replace

* switching data
use "`CCPX'_drates_`x'm.dta"
* collapse and save a file just for switching
collapse (max) $drate_list_sw drate_allmeth_sw, by(discont_sw)
* only keep row for switching, not for other reasons
drop if discont_sw != 1
* we no longer need discont_sw and don't want it in the resulting file
drop discont_sw 
gen reason = 9	// switching
* rename switching variables to match the non-switching names
rename drate_*_sw drate_*
save "`CCPX'_switching.dta", replace

* Go back to data by reasons and merge "all reasons" and switching data to it
use "`CCPX'_reasons.dta"
append using "`CCPX'_allreasons.dta" // all reasons
append using "`CCPX'_switching.dta" // switching 
append using "`CCPX'_method_Ns.dta" // weighted and unweighted numbers
label def reason 8 "All reasons" 9 "Switching" 10 "Weighted N" 11 "Unweighted N", add

* replace empty cells with zeros for each method
* and sum the weighted and unweighted Ns into the all methods variable
foreach z in drate_allmeth $drate_list {
	replace `z' = 0 if `z' == .
	* sum the method Ns to give the total Ns
	replace drate_allmeth = drate_allmeth + `z' if reason >= 10
}

*Add missing reason if no woman selected a reason in the list 
forval y= 1/11 {
	local n= [_N]+1
	egen reason_`y'=anycount(reason), values(`y')
	quietly sum reason_`y'
	local total_reason_`y'=r(max)
	if `total_reason_`y''==0 {
		set obs `n'
		replace reason =`y' in `n'
		foreach var of varlist drate* {
			replace `var'=0 in `n'
			}
		}
	drop reason_`y'
	}
sort reason

save "`CCPX'_drates_`x'm.dta", replace

* Step 10
* Output results in various ways

* simple output with reasons in rows and methods in columns
list reason $drate_list drate_allmeth, tab div abb(16) sep(9) noobs linesize(160)
outsheet reason $drate_list drate_allmeth using `CCPX'_`x'm_rates.csv, comma replace	

* Outputting as excel file with putexcel	
* putexcel output
putexcel set "`CCPX'_drates_`x'm.xlsx", replace
putexcel B1 = "Reasons for discontinuation"
putexcel A2 = "Contraceptive method"
* list out the contraceptive methods
local row = 2
foreach method of global methods_list {
	local row = `row'+1
	putexcel A`row' = "`method'"
}

putexcel B3:J`row', nformat(number_d2)
putexcel K3:L`row', nformat(number)

tokenize B C D E F G H I J K L
local recs = [_N]
* loop over reasons for discontinuation
forvalues j = 1/`recs' {
	local lab1 : label reason `j'
	putexcel `1'2 = "`lab1'", txtwrap
	local k = 2
	* loop over contraceptive methods
	local str
	foreach i in $drate_list drate_allmeth {
		local k = `k'+1
		local str `str' `1'`k' = `i'[`j']
	}
	* output results for method
	putexcel `str'
	mac shift
}


* Converting results dataset into long format for use with other tab commands

* convert results into long format 
reshape long drate_, i(reason) j(method_name) string
gen method = .
tokenize $meth_list allmeth
foreach m in $meth_codes 10 {
	replace method = `m' if method_name == "`1'"
	mac shift
}

label var method "Contraceptive method"
label def method		///
1 "Pill"				///
2 "IUD"					///
3 "Injectables"	 		///
4 "Implant"				///
5 "Male condom"			///
6 "Periodic abstinence"	///
7 "Withdrawal"			///
8 "EC"				///
9 "Other"				///
10 "All methods"    ///
14 "LAM"
label val method method

* Now tabulate (using table instead of tab to avoid extra Totals)
table method reason [iw=drate_], cellwidth(10) f(%3.1f)


* close loop if multiple durations used and file clean up
* closing brace if foreach is used for different durations
//}


* clean up working files
erase "`CCPX'_drates.dta"
erase "`CCPX'_reasons.dta"
erase "`CCPX'_allreasons.dta"
erase "`CCPX'_switching.dta"
erase "`CCPX'_method_Ns.dta"



