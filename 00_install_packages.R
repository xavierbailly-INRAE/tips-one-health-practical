# Run before class, from the student folder. Internet only for missing packages.
# Rscript 00_install_packages.R          -> normal live-simulation route
# Rscript 00_install_packages.R --rescue -> ape only (precomputed rescue)
local_library <- file.path(getwd(),".R-library")
dir.create(local_library,showWarnings=FALSE,recursive=TRUE)
.libPaths(c(local_library,.libPaths()))
packages <- if("--rescue" %in% commandArgs(trailingOnly=TRUE)) "ape" else c("ape","TiPS")
missing <- packages[!vapply(packages,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) install.packages(missing,lib=local_library,repos="https://cloud.r-project.org")
missing <- packages[!vapply(packages,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop("Packages still unavailable: ",paste(missing,collapse=", "))
if("TiPS" %in% packages && as.character(packageVersion("TiPS"))!="1.3.0") {
  stop("The teaching wrapper requires TiPS 1.3.0. Ask the instructor for setup help.")
}
print(vapply(packages,function(p)as.character(packageVersion(p)),character(1)))
cat("Packages ready. For the live route, run check_setup.R before class.\n")
