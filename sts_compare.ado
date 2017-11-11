*! version 0.0 Ishmail Azindoo Baako (IPA) October, 2017
cap version 13.1 
program define sts_compare
	syntax using/, DATAbase(string) OUTfile(string)
	
	qui {
		cls
		noi disp "Comparing Datasets ... "
		noi disp
		
		tempfile sts_request sts_database

		* IMPORT AND SAVE REQUEST
		*------------------------
		import excel using "`using'", sheet("Staff Details") cellrange(C5) allstring clear
		keep C D E G K

		* rename variables and assign value labels to them
		rename  (C 			D 			E		G		K		 ) ///
				(fullname	phonenumber	email	nhis	unique_id)	
		
		* label variables
		label variable fullname 	"Full name (automatically filled)"
		label variable phonenumber 	"Phone number"
		label variable email		"Email address"
		label variable nhis			"NHIS number"
		label variable unique_id	"IPA Unique Staff ID"
				
		* Mark observation row numbers
		gen request_row = _n + 4
						
		* trim string variables
		foreach var of varlist fullname email {
			replace `var' = trim(itrim(`var'))
		}
		
		* delete empty rows
		drop if missing(fullname)

		* Check for missing values in phonenumber, email, nhis
		foreach var of varlist phonenumber email nhis { 
			cap assert !missing(`var')
			if _rc {
				sort request_row
				noi disp in red "The following are missing for `var' in Contract Request"
				noi list request_row fullname if missing(`var')	abbrev(32) noobs sep(1) 
			}
		}
		
		* Check that phone numbers are at least 9 digits. 
		gen len_check = length(phonenumber) >= 9 | missing(phonenumber)
		if _rc {
			noi disp in red "The following phonenumbers in Contract Request are less than 9 digits"
			noi list request_row fullname phonenumber if !len_check, abbrev(32) noobs sep(1)
		}
		drop len_check
		
		* destring phone, nhis numbers and unique_id
		destring phonenumber, ignore("+") replace
		destring unique_id, force replace
		format %10.0f phonenumber
		
		* Check for duplicates on uniqueid, phonenumber, email, nhis
		foreach var of varlist unique_id phonenumber email nhis { 
			duplicates tag `var' if !missing(`var'), gen (_dup)
			count if _dup & !missing(`var')
			if `r(N)' > 0 {
				sort `var' request_row
				noi disp in red "The following are duplicate on `var' in Contract Request"
				noi list request_row fullname `var' if _dup & !missing(`var'), ///
					abbrev(32) noobs sepby(`var') 
			}
			drop _dup
		}
		
		* save data
		sort request_row
		save `sts_request'

		* save values of request in locals
		loc request_count `=_N'
		forval i = 1/`request_count' {
			loc request_row_`i'			= request_row[`i']
			loc request_unique_id_`i'	= unique_id[`i']
			loc request_fullname_`i' 	= fullname[`i']
			loc request_phonenumber_`i'	= phonenumber[`i']
			loc request_email_`i'		= email[`i']
			loc request_nhis_`i'		= nhis[`i']
		}
		
		* IMPORT AND SAVE DATABASE
		*-------------------------
		import excel using "`database'", sheet("Staff details") cellrange(B3) clear

		* keep only relevant variables
		keep B E F G I AO

		* rename variables and assign value labels to them
		rename  (E 			F 			G		I		B		 	AO			) ///
				(fullname	phonenumber	email	nhis	unique_id	correct_id	)
		
		* prefix all database variables with database
		rename	(*) (database_*)
		
		* replace unique_id if the unique_id is duplicates and was corrected
		destring database_correct_id, replace
			replace database_correct_id = . if length(string(database_correct_id)) != 6
			replace database_unique_id = database_correct_id if !missing(database_correct_id)
				drop database_correct_id
		
		* label variables
		label variable database_fullname 	"Full name (automatically filled)"
		label variable database_phonenumber "Phone number"
		label variable database_email		"Email address"
		label variable database_nhis		"NHIS number"
		label variable database_unique_id	"IPA Unique Staff ID"
		
		* trim string variables
		tostring database_nhis, replace
		foreach var of varlist database_fullname database_email database_nhis {
			replace `var' = trim(itrim(`var'))
		}
		
		* Drop empty rows
		drop if missing(database_fullname)
		
		* Mark observation row numbers
		gen database_row = _n + 2

		save `sts_database'
		
		* COMPARE DATASETS
		*-----------------
		*generate missing variables for request dataset
		generate request_row 			= .
		generate request_unique_id 		= .
		generate unique_id_matched		= .
		generate request_fullname 		= ""
		generate request_phonenumber 	= ""
		generate phonenumber_matched	= .
		generate request_email			= ""
		generate email_matched			= .
		generate request_nhis			= ""
		generate nhis_matched			= .

		* re-order variables
		#d;
		order   request_row
				database_row
				request_unique_id
				database_unique_id
				unique_id_matched
				request_fullname
				database_fullname
				request_phonenumber
				database_phonenumber
				phonenumber_matched
				request_email
				database_email
				email_matched
				request_nhis
				database_nhis
				nhis_matched
				;
		#d cr

		* loop through all request rows and flag matches
		forval i = 1/`request_count' {
		
			if !missing("`request_unique_id_`i''") {
				* look for matches in unique_id
				replace request_row = `request_row_`i'' ///
					if database_unique_id == `request_unique_id_`i'' 
			}
			
			* look for matches in phone
			if !missing("`request_phonenumber_`i''") {
				replace request_row = `request_row_`i'' ///
					if regexm(database_phonenumber, "`request_phonenumber_`i''") 
			}
			
			* look for matches in email
			if !missing("`request_email_`i''") {
				replace request_row = `request_row_`i'' ///
					if database_email == "`request_email_`i''" 							
			}

			* look for matches in nhis
			* for string nhis, check for a continues 4 digit or more sequence of numbers
			gen _nhis_fmt = regexs(0) if regexm("`request_nhis_`i''", "[0-9][0-9][0-9][0-9][0-9]+")
			loc request_nhis_`i'_fmt = _nhis_fmt[1]
			if !missing("`request_nhis_`i'_fmt'") {
				replace request_row = `request_row_`i'' ///
					if regexm(database_nhis, "`request_nhis_`i'_fmt'")
			}
			
			
			* Replace Request Variables
			cap replace request_unique_id 	= `request_unique_id_`i'' 		if request_row == `request_row_`i''
			cap replace request_phonenumber = "`request_phonenumber_`i''" 	if request_row == `request_row_`i''
			cap replace request_email 		= "`request_email_`i''" 		if request_row == `request_row_`i''
			cap replace request_nhis 		= "`request_nhis_`i''"			if request_row == `request_row_`i''
			replace request_fullname 		= "`request_fullname_`i''" 		if request_row == `request_row_`i''
			set trace on
			* Replace match markers
			replace unique_id_matched 	= 1 if database_unique_id 		== request_unique_id & request_row == `request_row_`i'' 
			
			* For the variables that can be missing, check that it is not before replacing
			if !missing("`request_email_`i''") 			replace email_matched 		= 1 if regexm(database_email, "`request_email_`i''") 				& ///
																						request_row == `request_row_`i'' 				
			if !missing("`request_nhis_`i'_fmt'") 		replace nhis_matched 		= 1 if regexm(database_nhis, "`request_nhis_`i'_fmt'")				& ///
																						request_row == `request_row_`i'' 			
			if !missing("`request_phonenumber_`i''") 	replace phonenumber_matched = 1 if regexm(database_phonenumber, "`request_phonenumber_`i''") 	& ///
																						request_row == `request_row_`i''
			set trace off
			* drop _nhis_fmt
			drop _nhis_fmt
		}
		
		foreach var of varlist *_matched {
			replace `var' = 0 if missing(`var')
		}
		
		* generate serial number for each request row
		sort request_row database_row	
		bysort request_row: gen index = _n
		bysort request_row: egen last_submission = max(index)
		replace last_submission = last_submission == index
		
		* gen matches
		egen matches = rowtotal(*_matched)
		
		* convert matches to string yes
		label define yesno 0 "no" 1 "yes"
		label values *_matched last_submission yesno
		
		keep if matches >= 1
		
		* generate variable to mark the number of uniqueids matched per request
		
		* Export Matched
		if `=_N' > 0 {
			sort request_row request_unique_id database_row
			export excel using "`outfile'", sheet("matches") firstrow(variable) replace
		}
		
		* Get the request_row numbers of matched observations
		levelsof request_row, loc (matched_rows) clean
		
		* delete matched rows from request data
		use `sts_request', clear
		gen matched = 0
		foreach row in `matched_rows' {
			replace matched = 1 if request_row == `row'
		}
		keep if !matched
		
		* Export unmatched
		if `=_N' > 0 {
			sort request_row 
			export excel request_row fullname email nhis using "`outfile'", sheet("no matches", replace) firstrow(variable)
		}
		
		noi disp
		noi disp "Comparison Completed ... "
	}
	
end
