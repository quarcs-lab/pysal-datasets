clear all
cls
macro drop _all


* Install packages
*ssc install spatreg
*ssc install spwmatrix


* From Github, donwload a ZIP file containing the shape file
copy "https://github.com/quarcs-lab/data-open/raw/master/grekousis/CityGeoDa.zip" CityGeoDa.zip, replace
unzipfile CityGeoDa.zip

* TRANSLATE the general shapefile into a stata-format shapefile
spshape2dta CityGeoDa, replace

* Use and describe the translated shape file
use CityGeoDa, clear
describe
list in 1/3


* SET new ID variable
*spset _ID, modify replace

* SET new coordinate units
*spset, modify coordsys(latlong, miles)
*save, replace


* Analyse dataset
summarize Income Insurance

* OLS regression
regress Income Insurance
  * information criteria
  estat ic
  * evaluate residuals (pnorm should be along the line)
  predict r, resid
  kdensity r, kernel(gaussian ) normal
  pnorm r
  * Mulicollinerity test via VIF (VIF > 10 is  bad)
  vif
  * Heteroskedasticity test via  BP (p-vale <0.05 is bad)
  rvfplot, yline(0)
  estat hettest

* Create a map of the spatial distribution
grmap, activate
grmap Income, fcolor(Heat) clmethod(kmeans) clnumber(3) legenda(on) legorder(lohi) legstyle(2) legcount
grmap Insurance, fcolor(Heat) clmethod(kmeans) clnumber(3) legenda(on) legorder(lohi) legstyle(2) legcount
grmap r, fcolor(Heat) clmethod(kmeans) clnumber(5) legenda(on) legorder(lohi) legstyle(2) legcount

* Create weight matrix (need Stata>=15)
spmatrix create contiguity Wqueen, normalize(row) replace
spmatrix summarize Wqueen

spmatrix create idistance Widist, normalize(row) replace
spmatrix summarize Widist


* Create and export weight matrix to .txt  and .dta
spmatrix create contiguity WqueenStata, normalize(none)  replace
spmatrix create idistance  WidistStata, normalize(none)  replace

spmatrix export WqueenStata using WqueenStata.txt, replace
import delimited "WqueenStata.txt", delimiter(space) rowrange(2) clear
drop v1
rename v# m#, renumber
save "WqueenStata.dta", replace

spmatrix export WidistStata using WidistStata.txt, replace

* Import standardized weight matrix from .txt format
spmatrix import WqueenStata using WqueenStata.txt, replace
spmatrix import WidistStata using WidistStata.txt, replace
spmatrix dir

* Run the Moran test based on the residuals of an OLS regression
use CityGeoDa, clear
regress Income Insurance
estat moran, errorlag(Wqueen)

* Run LM spatial diagnostics (needs spatreg package, not working)
  * [IMPORTANT] Import .dta weight matrix with spatwmat package, standardize it, and store eigen values
    spatwmat using "WqueenStata.dta", name(WqueenStata_spatwmat) eigenval(eWqueenStata_spatwmat) standardize
reg Income Insurance
spatdiag, weights(WqueenStata_spatwmat)



* Fit SLM(SAR) model: spatial lag of the dependent variable
spregress Income Insurance, ml dvarlag(Wqueen) vce(robust)
  * Compute information criteria (only for maximum likelihood)
  estat ic
  * Compute spillover (indirect) effect
  estat impact

spregress Income Insurance, gs2sls dvarlag(Wqueen)


* Fit SLX model: spatial lag of the independent variables
spregress Income Insurance, ml ivarlag(Wqueen:Insurance) vce(robust)
  * Compute information criteria (only for maximum likelihood)
  estat ic
  * Compute spillover (indirect) effect
  estat impact


* Fit SEM model: spatial lag of the error (no spillover)
spregress Income Insurance, ml errorlag(Wqueen) vce(robust)
  * Compute information criteria (only for maximum likelihood)
  estat ic
  * Compute spillover (indirect) effect
  estat impact
