# From transmission to genealogies

A 30-45 minute practical for Master's students in One Health. Run R code in five blocks to simulate epidemics in two host species, generate genealogies and compare host mixing for three transmission scenarios. No functions need to be written by students.

## Download the complete folder

On GitHub, choose **Code > Download ZIP**, then extract the whole archive into a writable folder. Keep `data/` and `figures/` with the scripts. Do not download the R script alone. The extracted folder's name may vary; use that folder as your working directory.

## Before class

Read [Installation_EN.pdf](Installation_EN.pdf) for Windows/Mac setup and troubleshooting. Install R, the matching C++ build tools, and the R packages **ape** and **TiPS 1.3.0**. RStudio is optional.

Open `TiPS_student.Rproj` in RStudio, or start R with this folder as its working directory. In the R console:

```r
source("00_install_packages.R")
source("check_setup.R")
```

Wait for **READY**. Package installation alone does not confirm that TiPS can compile a model. Prepare this before the session.

## During class

Read [the student handout](TiPS_student_EN.pdf). Open [TiPS_student.R](TiPS_student.R) and execute one complete numbered block at a time. Keep `use_precomputed <- FALSE` to generate the trajectories, trees and final distributions yourself.

For a complete run without RStudio, from this folder in a terminal:

```bash
Rscript run_without_rstudio.R
```

Figures are saved in `student_plots.pdf`; results and provenance go into a new folder under `runs/`. The core teaching plan is 38 minutes; installation is separate.

## Explicit rescue

If setup is blocked, change `use_precomputed <- FALSE` to `use_precomputed <- TRUE` in block 1 and rerun all blocks. This needs only **ape**, with no TiPS or compiler. From a terminal:

```bash
Rscript 00_install_packages.R --rescue
Rscript run_without_rstudio.R --rescue
```

Rescue plots are labelled **PRECOMPUTED RESCUE**. The supplied `figures/` and `data/` also support offline discussion if R cannot run. No cached results are substituted automatically in a live run.

## Contents and reproducibility

- `TiPS_student_EN.pdf`: student handout, four pages.
- `Installation_EN.pdf`: Windows/Mac installation, two pages.
- `Simulation_EN.pdf`: functions, outputs and rescue reference.
- `simulation_functions.R` and `helpers.R`: complete supporting code.
- `data/` and `figures/`: validated precalculated rescue data and figures.
- `.Rmd` files: editable document sources; Pandoc/LaTeX is needed only to rebuild PDFs.

The main exercise uses q = 0.001, 0.1 and 1, 500 epidemic attempts per scenario, up to 30 eligible trees per scenario and 199 label permutations per tree. Seeds are fixed for reproducibility. Cached data use different seeds and include additional instructor-generated scenarios.

The workflow has been executed under Linux with R 4.5.2 and TiPS 1.3.0. Native Windows/Mac classroom trials are still needed. See [software attribution](SOFTWARE_SOURCES.txt). The local directory of the original computation is omitted from distributed provenance; model parameters, seeds, versions and results are retained.
