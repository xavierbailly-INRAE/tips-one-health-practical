# Plotting functions supplied by the instructor. No simulation runs here.
host_colours <- c(H1 = "#0072B2", H2 = "#D55E00")
validate_scenarios <- function(lesson, q_values) {
  if (!length(q_values) || anyNA(q_values) || anyDuplicated(q_values) ||
      !all(as.character(q_values) %in% names(lesson$trees))) {
    stop("Select distinct available q values from lesson$metrics$q.")
  }
}
plot_trajectories <- function(lesson, q_values) {
  validate_scenarios(lesson, q_values)
  old <- par(no.readonly = TRUE); on.exit(par(old))
  par(mfrow = c(1, length(q_values)), mar = c(4, 4, 4, 1))
  banks <- lapply(as.character(q_values), function(q) head(lesson$trajectories[[q]], 3))
  xmax <- max(vapply(unlist(banks, recursive = FALSE), function(d) max(d$Time), numeric(1)))
  ymax <- max(vapply(unlist(banks, recursive = FALSE), function(d) max(d$I1,d$I2), numeric(1)))
  for (i in seq_along(q_values)) {
    plot(NA, xlim = c(0, xmax), ylim = c(0, ymax),
         xlab = "Days since introduction", ylab = "Infected individuals",
         main = paste("q =", q_values[i]))
    if (!is.null(lesson$display_source)) mtext(lesson$display_source,side=3,line=2.7,cex=.7)
    for (j in seq_along(banks[[i]])) {
      d <- banks[[i]][[j]]
      lines(d$Time, d$I1, col = host_colours[1], lty = j)
      lines(d$Time, d$I2, col = host_colours[2], lty = j)
    }
    legend("topright", c("Host 1", "Host 2"), col = host_colours,
           lty = 1, bty = "n", cex = .75)
  }
}
plot_genealogies <- function(lesson, q_values, replicate_id = 1L, tip_size = 1.15) {
  validate_scenarios(lesson, q_values)
  if (length(replicate_id) != 1L || is.na(replicate_id) ||
      replicate_id < 1 || replicate_id != floor(replicate_id) ||
      any(vapply(lesson$trees[as.character(q_values)], length, integer(1)) < replicate_id)) {
    stop("Choose an available integer replicate_id, for example 1, 2 or 3.")
  }
  old <- par(no.readonly = TRUE); on.exit(par(old))
  par(mfrow = c(1, length(q_values)), mar = c(4, 1, 6, 1))
  for (q in q_values) {
    tr <- ape::ladderize(lesson$trees[[as.character(q)]][[replicate_id]])
    host <- ifelse(grepl("^I1_", tr$tip.label), "H1", "H2")
    ape::plot.phylo(tr, show.tip.label = FALSE, edge.width = .7,
                   main = "",
                   no.margin = FALSE)
    ape::tiplabels(pch = ifelse(host == "H1", 21, 22),
                   bg = host_colours[host], col = host_colours[host],
                   cex = tip_size, lwd = .8)
    ape::axisPhylo()
    mtext("Days before latest sample", side = 1, line = 2.4, cex = .7)
    mtext(paste0("q = ", q, "; replicate ", replicate_id),
          side = 3, line = 3, font = 2, cex = .95)
    if (!is.null(lesson$display_source)) mtext(lesson$display_source,side=3,line=4.2,cex=.65)
    legend(x = mean(par("usr")[1:2]),
           y = par("usr")[4] + 2 * strheight("M"),
           xjust = .5, yjust = 1, xpd = NA, horiz = TRUE,
           legend = c("Host 1", "Host 2"), col = host_colours,
           pt.bg = host_colours, pch = c(21, 22), pt.cex = 1.3,
           bty = "n", cex = .85)
  }
}
plot_mixing <- function(lesson, q_values) {
  validate_scenarios(lesson, q_values)
  old <- par(no.readonly = TRUE); on.exit(par(old))
  par(mfrow = c(1,1), mar = c(4,4,4.5,1))
  d <- lesson$metrics[lesson$metrics$q %in% q_values, ]
  f <- factor(d$q, levels = q_values)
  boxplot(d$M ~ f, outline = FALSE, ylim = c(0, max(1.12, d$M)),
          xlab = "q: between / within-species transmission (categories)",
          ylab = "Normalised parsimony score M", col = "#DFE7EE",
          main = "One dot = one independent epidemic and genealogy")
  if (!is.null(lesson$display_source)) mtext(lesson$display_source,side=3,line=3.2,cex=.8)
  # Deterministic offsets: displaying the plot never changes R's RNG state.
  for (i in seq_along(q_values)) {
    values <- d$M[d$q == q_values[i]]
    offsets <- (((seq_along(values) * .61803398875) %% 1) - .5) * .3
    points(i + offsets, values, pch = 16, cex = .65, col = "#31485D")
    mtext(paste0("n = ", length(values)), side = 3, at = i, line = .2, cex = .75)
  }
  abline(h = 1, lty = 2, col = "#8E4A36")
  legend("topleft", "Shuffled-label reference (M = 1)",
         lty = 2, col = "#8E4A36", bty = "n", cex = .8)
}
