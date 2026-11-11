# FROM TRANSMISSION TO GENEALOGIES - MAIN PRACTICAL, 30-45 MINUTES
# Work in the student folder. Run one block at a time in R or RStudio.
# Terminal alternative: Rscript run_without_rstudio.R
# Before class: Rscript 00_install_packages.R, then Rscript check_setup.R

# BLOCK 1 - Start and predict (5 minutes) ---------------------------------
use_precomputed <- FALSE  # Normal route: simulate everything during the TP.
if ("--rescue" %in% commandArgs(trailingOnly=TRUE)) use_precomputed <- TRUE
# RESCUE ONLY: change to TRUE and rerun from block 1. No automatic fallback.
if (dir.exists(".R-library")) .libPaths(c(".R-library", .libPaths()))
if (!file.exists("helpers.R")) stop("Change into the student folder first.")
if (!requireNamespace("ape",quietly=TRUE)) stop("Run 00_install_packages.R before class.")
library(ape)
source("helpers.R")
N <- 1000L
beta <- 0.2
gamma <- 0.1
tmax <- 600
n_tips <- 50L
min_cases <- 200L
n_perm <- 199L
q_values <- c(0.001, 0.1, 1)
n_attempts <- 500L  # Fixed attempts per scenario, INCLUDING early extinctions.
max_trees <- 30L   # First eligible epidemics, never selected by their tree shape.
seed_base <- 500000L
lesson <- NULL    # Never reuse an object from an earlier live/rescue run.
mode_label <- if(use_precomputed) "PRECOMPUTED RESCUE" else "LIVE SIMULATION"
cat("DATA SOURCE:",mode_label,"\n")
out_dir <- tempfile(pattern=if(use_precomputed) "rescue_" else "live_",
                    tmpdir="runs")
dir.create(out_dir,recursive=TRUE)
timings <- data.frame(stage=character(),seconds=numeric())
if (!use_precomputed) {
  if (!requireNamespace("TiPS",quietly=TRUE)) {
    stop("TiPS missing. Prepare it before class, or explicitly set use_precomputed=TRUE and restart.")
  }
  source("simulation_functions.R")
}
# q = between-species / within-species transmission coefficient.
# Predict which scenario should show the strongest host clustering.

# BLOCK 2 - Define and compile the model (5 minutes) -----------------------
reactions <- c(
  "S1 [beta*S1*I1/N] -> I1", # within host 1
  "S2 [beta*S2*I2/N] -> I2", # within host 2
  "S2 [b*S2*I1/N] -> I2",    # host 1 infects host 2
  "S1 [b*S1*I2/N] -> I1",    # host 2 infects host 1
  "I1 [gamma*I1] -> 0",      # recovery of host 1
  "I2 [gamma*I2] -> 0"       # recovery of host 2
)
initial_state <- c(S1=N-1L,I1=1L,S2=N,I2=0L)
if (!use_precomputed) {
  elapsed <- system.time(simulator <- build_teaching_simulator(reactions))["elapsed"]
  timings <- rbind(timings,data.frame(stage="compile",seconds=unname(elapsed)))
} else {
  lesson <- readRDS("data/lesson.rds")
  stopifnot(all(as.character(q_values) %in% names(lesson$trees)),
            lesson$parameters$N_per_host==N, lesson$parameters$beta_per_day==beta,
            lesson$parameters$gamma_per_day==gamma, lesson$parameters$samples_per_host==n_tips)
  lesson$data_source <- "PRECOMPUTED RESCUE"
  lesson$display_source <- "PRECOMPUTED RESCUE"
}
# Which reaction introduces infection into host 2? What happens if q=0?

# BLOCK 3 - Simulate and inspect epidemics (8 minutes) ---------------------
if (!use_precomputed) {
  elapsed <- system.time(epidemics <- simulate_epidemics(
    q_values,n_attempts,max_trees,seed_base))["elapsed"]
  timings <- rbind(timings,data.frame(stage="epidemics",seconds=unname(elapsed)))
  saveRDS(epidemics,file.path(out_dir,"epidemics.rds"))
  write.csv(epidemics$attempts,file.path(out_dir,"attempts.csv"),row.names=FALSE)
  # Stop transparently instead of substituting cached results for any scenario.
  if(any(lengths(epidemics$bank)<3L)) {
    stop("Fewer than 3 eligible epidemics in a scenario. All attempts were saved. Use explicit rescue or discuss with the instructor.")
  }
  # Temporary display object; all curves here are from THIS run.
  trajectory_view <- list(
    trajectories=lapply(epidemics$bank,function(bank) lapply(head(bank,3),function(x) x$traj)),
    trees=epidemics$bank,display_source=paste("LIVE | seed",seed_base))
  plot_trajectories(trajectory_view,q_values)
  print(aggregate(accepted~q,epidemics$attempts,sum))
} else {
  plot_trajectories(lesson,q_values)
  print(lesson$acceptance[lesson$acceptance$q %in% q_values,
                          c("q","attempts","accepted","proportion")])
}
# Compare peak timing and height. Why are these plotted epidemics conditional
# on >=200 infections in BOTH hosts and extinction before day 600?

# BLOCK 4 - Simulate and inspect genealogies (10 minutes) ------------------
if (!use_precomputed) {
  elapsed <- system.time(genealogies <- simulate_genealogies(
    epidemics$bank,q_values,seed_base))["elapsed"]
  timings <- rbind(timings,data.frame(stage="trees_and_metrics",seconds=unname(elapsed)))
  saveRDS(genealogies,file.path(out_dir,"genealogies.rds"))
  lesson <- assemble_lesson(epidemics,genealogies)
  lesson$data_source <- "LIVE SIMULATION"
  lesson$display_source <- paste("LIVE | seed",seed_base)
}
# Rerun only these two lines with replicate_id=2 or 3 to inspect more trees.
replicate_id <- 1L
plot_genealogies(lesson,q_values,replicate_id,tip_size=1.15)
# Do colours cluster? Does this comparison survive across replicates?

# BLOCK 5 - Compare YOUR distributions and conclude (10 minutes) ----------
# M = observed parsimony score / mean score after 199 host-label permutations.
# Low M means host clustering; M near 1 means similarity to the shuffled reference.
q_final <- c(0.001, 0.1, 1)
cat("FINAL COMPARISON USES:",lesson$data_source,"\n")
plot_mixing(lesson,q_final)
print(lesson$summary[lesson$summary$q %in% q_final,
                    c("q","n","median_M","p10_M","p90_M")])
# Each dot is an independent epidemic and its genealogy. Use the displayed n:
# with another random seed, fewer than 30 eligible trees can be available.
# Complete: "In this model, increasing transmission between hosts ..."
# Why can this score not directly estimate q from a real tree?
saveRDS(lesson,file.path(out_dir,"lesson.rds"))
write.csv(lesson$metrics[lesson$metrics$q %in% q_final,],file.path(out_dir,"metrics.csv"),row.names=FALSE)
write.csv(timings,file.path(out_dir,"timings.csv"),row.names=FALSE)
saveRDS(list(source=lesson$data_source,seed_base=if(use_precomputed) NA else seed_base,
  q=q_values,N=N,beta=beta,gamma=gamma,n_attempts=if(use_precomputed) NA else n_attempts,
  max_trees=max_trees,n_perm=n_perm,R=R.version.string,
  TiPS=if(use_precomputed) "not required" else as.character(packageVersion("TiPS"))),
  file.path(out_dir,"settings.rds"))
writeLines(lesson$data_source,file.path(out_dir,"DATA_SOURCE.txt"))
writeLines(capture.output(sessionInfo()),file.path(out_dir,"sessionInfo.txt"))
writeLines(out_dir,"runs/latest_run.txt")
print(timings)
cat("Results saved in",out_dir,"\n")
