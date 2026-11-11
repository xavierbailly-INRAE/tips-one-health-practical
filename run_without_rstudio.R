# From the student folder: Rscript run_without_rstudio.R
# Explicit rescue: Rscript run_without_rstudio.R --rescue
# Before class: Rscript 00_install_packages.R && Rscript check_setup.R
pdf("student_plots.pdf",width=12,height=8)
tryCatch(source("TiPS_student.R",echo=FALSE),finally=dev.off())
file.copy("student_plots.pdf",file.path(out_dir,"student_plots.pdf"),overwrite=TRUE)
cat("Plots saved in student_plots.pdf and",out_dir,"\n")
