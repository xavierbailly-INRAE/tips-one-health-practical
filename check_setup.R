# Run from the unzipped student folder before class:
# source("check_setup.R") or Rscript check_setup.R
# A real compilation is used: PATH checks alone are unreliable on Windows.
setup_help <- function(os = Sys.info()[["sysname"]]) {
  switch(os,
    Windows = paste(
      "WINDOWS: install Rtools matching your R version from",
      "https://cran.r-project.org/bin/windows/Rtools/",
      "Use the standard installation location. RStudio alone is not enough.",
      "Close ALL R/RStudio windows, reopen R, and rerun this check.", sep="\n"),
    Darwin = paste(
      "MAC: open the macOS Terminal (not the R console) and run:",
      "  xcode-select --install",
      "Finish the Apple installer, then restart R/RStudio and rerun this check.",
      "If tools are already installed, check xcode-select -p in Terminal.",
      "See https://mac.r-project.org/tools/ for R-compatible build tools.", sep="\n"),
    paste("LINUX: ask IT to install R development tools, make and a C++ compiler.",
          "Then restart R and rerun this check.", sep="\n"))
}

run_setup_check <- function() {
  if (!file.exists("simulation_functions.R")) {
    stop("Open the unzipped student folder as your working directory first. See Installation_EN.pdf.",call.=FALSE)
  }
  if(dir.exists(".R-library")) .libPaths(c(".R-library",.libPaths()))
  stage <- "R packages"
  trace_file <- tempfile(fileext=".tsv")
  on.exit(unlink(trace_file),add=TRUE)
  tryCatch({
    missing <- c("ape","TiPS")[!vapply(c("ape","TiPS"),requireNamespace,
                                         logical(1),quietly=TRUE)]
    if(length(missing)) stop("Missing or unloadable package(s): ",paste(missing,collapse=", "),
      ". Run source(\"00_install_packages.R\") before this check.",call.=FALSE)
    stage <- "TiPS version"
    if(as.character(packageVersion("TiPS"))!="1.3.0")
      stop("This practical requires TiPS 1.3.0. Ask the instructor for the tested version; see Installation_EN.pdf.",call.=FALSE)
    source("simulation_functions.R",local=TRUE)
    stage <- "C++ compilation"
    cat("Checking C++ compilation with TiPS (this may take a few seconds)...\n")
    small_simulator <- build_teaching_simulator(c("S [beta*S*I/N] -> I", "I [gamma*I] -> 0"))
    stage <- "native simulation and trace output"
    invisible(suppressMessages(small_simulator(paramValues=c(beta=0,gamma=.1,N=1000),
        initialStates=c(S=999,I=1),times=c(0,600),method="exact",nTrials=1L,
        seed=130001L,outFile=trace_file)))
    if(!file.exists(trace_file) || length(readLines(trace_file))!=3L)
      stop("The tiny simulation did not produce the expected trace.")
    cat("READY: TiPS 1.3.0 compiled, simulated an event and retained its trace.\n")
    invisible(TRUE)
  },error=function(e) {
    details <- c(paste("NOT READY - failed stage:",stage),
      paste("System:",Sys.info()[["sysname"]]),R.version.string,
      paste("Original error:",conditionMessage(e)),capture.output(sessionInfo()))
    saved <- tryCatch({writeLines(details,"setup_diagnostics.txt");TRUE},error=function(e) FALSE)
    cat("\nNOT READY - failed stage:",stage,"\n")
    if(stage=="C++ compilation") {
      cat("R could not build the model. Build tools may be missing or misconfigured;\n",
          "other compilation errors are also possible.\n",setup_help(),"\n",sep="")
    } else if(stage=="R packages") {
      cat("Run source(\"00_install_packages.R\"), then source(\"check_setup.R\").\n")
    } else if(stage=="native simulation and trace output") {
      cat("Compilation succeeded, but the simulation/output check failed. Ask the instructor.\n")
    }
    cat("Read Installation_EN.pdf. Send the instructor the console error",
        if(saved) " and setup_diagnostics.txt" else " (diagnostic file could not be saved)",".\n",sep="")
    cat("During class: do not spend more than two minutes troubleshooting.\n",
        "Rescue: set use_precomputed <- TRUE in block 1 of TiPS_student.R,\n",
        "then rerun all blocks. Only ape is required; no compiler is used.\n",sep="")
    stop(paste("Setup check failed:",conditionMessage(e)),call.=FALSE)
  })
}
run_setup_check()
