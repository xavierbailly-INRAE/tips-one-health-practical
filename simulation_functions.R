# Supplied simulation functions: inspect these if you want the implementation.
# Extracted from the validated instructor analysis; no simulations run on source().

# Compatibility wrapper for TiPS 1.3.0.
# TiPS treats extinction before the time horizon as failure and deletes the TSV.
# Preserve that file so each attempted epidemic can be counted and validated.
# No propensity, event, stopping rule or random-number draw is changed.
# The installed package and namespace are never modified.
build_teaching_simulator <- function(reactions) {
  if (as.character(utils::packageVersion("TiPS")) != "1.3.0") {
    stop("This compatibility wrapper is validated only for TiPS 1.3.0.")
  }
  ns <- asNamespace("TiPS")
  original_generator <- get("simulator_generator", ns)
  local_env <- new.env(parent = ns)
  local_env$simulator_generator <- function(reactions, functions = NULL) {
    cpp <- original_generator(reactions, functions)
    deletion <- "remove((outFile_.c_str()));"
    hits <- gregexpr(deletion, cpp, fixed = TRUE)[[1]]
    if (length(hits) != 1L || hits[1] < 0) {
      stop("Unexpected TiPS source: refusing to apply the compatibility fix.")
    }
    sub(deletion, "/* Teaching wrapper: retain failed-attempt trace. */",
        cpp, fixed = TRUE)
  }
  builder <- get("build_simulator", ns)
  environment(builder) <- local_env
  builder(reactions)
}

read_trace <- function(path) {
  if (!file.exists(path) || file.info(path)$size == 0) {
    stop("TiPS did not write a trajectory: ", path)
  }
  z <- strsplit(readLines(path, warn = FALSE), "\t", fixed = TRUE)
  # Some TiPS outputs add an empty field to the initial row.
  z <- lapply(z, function(x) x[nzchar(x)])
  if (length(z) < 2L || any(lengths(z[-1L]) != length(z[[1L]]))) {
    stop("Unexpected TiPS trace format")
  }
  d <- as.data.frame(do.call(rbind, z[-1L]), stringsAsFactors = FALSE)
  names(d) <- z[[1L]]
  required <- c("Time", "Reaction", "Nrep", "S1", "I1", "S2", "I2")
  stopifnot(all(required %in% names(d)))
  for (nm in setdiff(names(d), "Reaction")) {
    d[[nm]] <- as.numeric(d[[nm]])
  }
  # The tree engine expects the three metadata columns first.
  d <- d[c("Time", "Reaction", "Nrep",
           setdiff(names(d), c("Time", "Reaction", "Nrep")))]
  # Keep the time prefix, never later events.
  end <- which(!is.finite(d$Time) | d$Time > tmax)
  if (length(end)) d <- d[seq_len(end[1L] - 1L), , drop = FALSE]
  extinct <- which(d$I1 + d$I2 == 0)
  if (length(extinct)) d <- d[seq_len(extinct[1L]), , drop = FALSE]
  stopifnot(nrow(d) >= 1L, !anyNA(d$Time), all(diff(d$Time) >= 0))
  # Preserve event order if TSV rounding produces tied timestamps.
  ties <- sum(diff(d$Time) == 0)
  if (ties && nrow(d) > 1L) for (i in 2:nrow(d)) {
    if (d$Time[i] <= d$Time[i - 1L]) {
      d$Time[i] <- d$Time[i - 1L] +
        16 * .Machine$double.eps * max(1, abs(d$Time[i - 1L]))
    }
  }
  attr(d, "timestamp_ties") <- ties
  rownames(d) <- NULL
  d
}

check_trace <- function(d, q) {
  stopifnot(nrow(d) >= 1L, !anyNA(d), d$Time[1L] == 0,
            d$Reaction[1L] == "init", all(diff(d$Time) > 0),
            all(d$Nrep == 1L))
  state <- as.matrix(d[c("S1", "I1", "S2", "I2")])
  stopifnot(all(state >= 0), all(state == floor(state)),
            all(d$S1 + d$I1 <= N), all(d$S2 + d$I2 <= N),
            all(diff(N - d$S1 - d$I1) >= 0),
            all(diff(N - d$S2 - d$I2) >= 0),
            all(state[1L, ] == unname(initial_state)))
  delta <- rbind(c(-1, 1, 0, 0), c(0, 0, -1, 1),
                 c(0, 0, -1, 1), c(-1, 1, 0, 0),
                 c(0, -1, 0, 0), c(0, 0, 0, -1))
  if (nrow(d) > 1L) {
    j <- match(d$Reaction[-1L], reactions)
    stopifnot(!anyNA(j))
    before <- state[-nrow(state), , drop = FALSE]
    after <- state[-1L, , drop = FALSE]
    stopifnot(all(after - before == delta[j, , drop = FALSE]))
    rates <- cbind(beta * before[, 1] * before[, 2] / N,
                   beta * before[, 3] * before[, 4] / N,
                   q * beta * before[, 3] * before[, 2] / N,
                   q * beta * before[, 1] * before[, 4] / N,
                   gamma * before[, 2], gamma * before[, 4])
    stopifnot(all(rates[cbind(seq_along(j), j)] > 0))
  }
  if (q == 0) stopifnot(all(d$I2 == 0), all(d$S2 == N))
  invisible(TRUE)
}

one_trajectory <- function(q, seed) {
  path <- tempfile(fileext = ".tsv")
  valid <- FALSE
  on.exit({
    if (valid) unlink(path) else if (file.exists(path)) {
      file.copy(path, file.path(out_dir,
        paste0("failed_trajectory_seed_", seed, ".tsv")), overwrite = TRUE)
    }
  }, add = TRUE)
  p <- c(beta = beta, b = beta * q, gamma = gamma, N = N)
  ans <- suppressMessages(simulator(
    paramValues = p, initialStates = initial_state,
    times = c(0, tmax), method = "exact", nTrials = 1L,
    seed = as.integer(seed), outFile = path
  ))
  d <- read_trace(path)
  check_trace(d, q)
  valid <- TRUE
  structure(list(reactions = reactions,
    values = as.list(c(p, initial_state)), times = c(0, tmax),
    method = "Exact Method", tau = 0, seed = seed, traj = d,
    original_return_empty = length(ans) == 0L,
    timestamp_ties = attr(d, "timestamp_ties")), class = "simutraj")
}

trajectory_summary <- function(simu) {
  d <- simu$traj
  last <- d[nrow(d), ]
  c1 <- N - last$S1
  c2 <- N - last$S2
  extinct <- last$I1 + last$I2 == 0
  data.frame(cases1 = c1, cases2 = c2, extinct = extinct,
    peak1 = max(d$I1), peak2 = max(d$I2),
    peak_lag = d$Time[which.max(d$I2)] - d$Time[which.max(d$I1)],
    cross12 = sum(d$Reaction == reactions[3L]),
    cross21 = sum(d$Reaction == reactions[4L]),
    accepted = extinct && c1 >= min_cases && c2 >= min_cases,
    empty_return = simu$original_return_empty,
    timestamp_ties = simu$timestamp_ties)
}



host_labels <- function(labels) {
  h <- ifelse(grepl("^I1_", labels), "H1",
              ifelse(grepl("^I2_", labels), "H2", NA_character_))
  if (anyNA(h)) stop("Unknown TiPS label: ", labels[which(is.na(h))[1]])
  setNames(h, labels)
}

check_tree <- function(tr, expected_tips) {
  stopifnot(inherits(tr, "phylo"), Ntip(tr) == expected_tips,
            !is.null(tr$edge.length), !anyDuplicated(tr$tip.label),
            all(is.finite(tr$edge.length)), all(tr$edge.length >= 0),
            length(setdiff(tr$edge[, 1], tr$edge[, 2])) == 1L,
            !anyDuplicated(tr$edge[, 2]))
  invisible(TRUE)
}

one_tree <- function(simu, seed) {
  d <- simu$traj
  totals <- c(N - tail(d$S1, 1), N - tail(d$S2, 1))
  stopifnot(tail(d$I1 + d$I2, 1) == 0)
  full <- suppressMessages(TiPS::simulate_tree(
    simuResults = simu, dates = NULL,
    deme = c("I1", "I2"), sampled = c(I1 = 0.5, I2 = 0.5),
    root = "I1", isFullTrajectory = TRUE, addInfos = TRUE,
    nTrials = 1L, resampling = FALSE, seed = as.integer(seed)
  ))
  if (!inherits(full, "phylo")) {
    stop("Native simulate_tree failure; seed = ", seed)
  }
  tr <- collapse.singles(full, root.edge = TRUE)
  check_tree(tr, sum(totals))
  # Keep native annotations in full; pruned Newick without
  # internal labels containing reaction strings.
  tr$node.label <- NULL
  h <- host_labels(tr$tip.label)
  stopifnot(sum(h == "H1") == totals[1], sum(h == "H2") == totals[2])

  # Recover the time origin from the recorded removal events.
  depth <- node.depth.edgelength(tr)[seq_len(Ntip(tr))]
  offsets <- unlist(lapply(1:2, function(i) {
    removal <- sort(d$Time[d$Reaction == reactions[4L + i]])
    removal - sort(depth[h == paste0("H", i)])
  }))
  origin <- median(offsets)
  stopifnot(max(abs(offsets - origin)) < 1e-5)
  metadata <- data.frame(label = tr$tip.label, host = unname(h),
                         date = depth + origin)

  set.seed(seed + 1L)
  keep <- unlist(lapply(c("H1", "H2"), function(host) {
    ids <- which(h == host)
    stopifnot(length(ids) >= n_tips)
    ids[sample.int(length(ids), n_tips)]
  }))
  sampled <- keep.tip(tr, tr$tip.label[keep])
  metadata <- metadata[match(sampled$tip.label, metadata$label), ]
  check_tree(sampled, 2L * n_tips)
  stopifnot(all(table(metadata$host) == n_tips))
  dd <- node.depth.edgelength(sampled)[seq_len(Ntip(sampled))]
  root_time <- median(metadata$date - dd)
  stopifnot(max(abs(metadata$date - dd - root_time)) < 1e-5)
  list(tree = sampled, metadata = metadata, root_time = root_time,
       full = full, seed = seed, trajectory_seed = simu$seed)
}



# One row per host assignment; one column per tip.
# 0 = H1 ; 1 = H2. Postorder traversal avoids deep recursion.
sankoff <- function(tree, states) {
  tr <- reorder.phylo(tree, "postorder")
  x <- as.matrix(states)
  nt <- Ntip(tr)
  stopifnot(ncol(x) == nt, all(x %in% c(0L, 1L)))
  c0 <- c1 <- matrix(0, nrow(x), nt + tr$Nnode)
  c0[, seq_len(nt)] <- ifelse(x == 0L, 0, nt + 1)
  c1[, seq_len(nt)] <- ifelse(x == 1L, 0, nt + 1)
  for (i in seq_len(nrow(tr$edge))) {
    parent <- tr$edge[i, 1L]
    child <- tr$edge[i, 2L]
    c0[, parent] <- c0[, parent] + pmin(c0[, child], c1[, child] + 1)
    c1[, parent] <- c1[, parent] + pmin(c1[, child], c0[, child] + 1)
  }
  r <- setdiff(tr$edge[, 1L], tr$edge[, 2L])
  pmin(c0[, r], c1[, r])
}

mixing_metrics <- function(tree, seed) {
  h <- as.integer(host_labels(tree$tip.label) == "H2")
  nt <- length(h)
  stopifnot(all(c(0L, 1L) %in% h), n_perm >= 1L)
  set.seed(seed)
  x <- matrix(NA_integer_, n_perm + 1L, nt)
  x[1L, ] <- h
  for (i in seq_len(n_perm)) x[i + 1L, ] <- h[sample.int(nt)]
  scores <- sankoff(tree, x)
  null <- scores[-1L]
  children <- split(tree$edge[, 2L], tree$edge[, 1L])
  cherries <- Filter(function(v) length(v) == 2L && all(v <= nt), children)
  mixed <- if (length(cherries)) mean(vapply(cherries,
    function(v) h[v[1]] != h[v[2]], logical(1))) else NA_real_
  counts <- matrix(0L, nt + tree$Nnode, 2L)
  counts[cbind(seq_len(nt), h + 1L)] <- 1L
  e <- reorder.phylo(tree, "postorder")$edge
  for (i in seq_len(nrow(e))) {
    counts[e[i, 1L], ] <- counts[e[i, 1L], ] + counts[e[i, 2L], ]
  }
  data.frame(PS = scores[1L], null_mean = mean(null),
    M = scores[1L] / mean(null),
    p_permutation = (1 + sum(null <= scores[1L])) / (n_perm + 1L),
    mixed_cherries = mixed, n_cherries = length(cherries),
    pure_H1 = max(counts[counts[, 2] == 0, 1]) / sum(h == 0),
    pure_H2 = max(counts[counts[, 1] == 0, 2]) / sum(h == 1))
}



# Batch operations used by the main student script. All attempts are retained.
simulate_epidemics <- function(q_values, n_attempts, max_trees, seed_base) {
trajectory_bank <- setNames(vector("list",length(q_values)),as.character(q_values))
attempt_rows <- list()

  for (iq in seq_along(q_values)) {
    for (attempt in seq_len(n_attempts)) {
      seed <- seed_base+10000L*iq+attempt
      epidemic <- one_trajectory(q_values[iq],seed)
      info <- trajectory_summary(epidemic)
      attempt_rows[[length(attempt_rows)+1L]] <- cbind(
        data.frame(q=q_values[iq],attempt=attempt,seed=seed),info)
      if(info$accepted && length(trajectory_bank[[iq]])<max_trees) {
        trajectory_bank[[iq]][[length(trajectory_bank[[iq]])+1L]] <- epidemic
      }
    }
  }
  list(bank=trajectory_bank, attempts=do.call(rbind,attempt_rows))
}
simulate_genealogies <- function(trajectory_bank, q_values, seed_base) {
tree_bank <- setNames(vector("list",length(q_values)),as.character(q_values))
metric_rows <- list()

  for(iq in seq_along(q_values)) {
    for(j in seq_along(trajectory_bank[[iq]])) {
      tree_seed <- seed_base+100000L+iq*1000L+j
      result <- one_tree(trajectory_bank[[iq]][[j]],tree_seed)
      tree_bank[[iq]][[j]] <- result
      metric_rows[[length(metric_rows)+1L]] <- cbind(
        data.frame(q=q_values[iq],replicate=j,
                   trajectory_seed=result$trajectory_seed,tree_seed=tree_seed),
        mixing_metrics(result$tree,tree_seed+100000L))
    }
  }
  if (!length(metric_rows)) stop("No eligible trees in this run.")
  list(bank=tree_bank, metrics=do.call(rbind,metric_rows))
}
assemble_lesson <- function(epidemics, genealogies) {
  metrics <- genealogies$metrics
  summary <- do.call(rbind,lapply(sort(unique(metrics$q)),function(q) {
    d <- metrics[metrics$q==q,]
    data.frame(q=q,n=nrow(d),median_M=median(d$M),
               p10_M=unname(quantile(d$M,.1)),p90_M=unname(quantile(d$M,.9)))
  }))
  attempts <- epidemics$attempts
  acceptance <- do.call(rbind,lapply(sort(unique(attempts$q)),function(q) {
    d <- attempts[attempts$q==q,]
    data.frame(q=q,attempts=nrow(d),accepted=sum(d$accepted),
               proportion=mean(d$accepted),kept=length(epidemics$bank[[as.character(q)]]))
  }))
  list(parameters=data.frame(N_per_host=N,beta_per_day=beta,gamma_per_day=gamma,
                            initial_I1=1,initial_I2=0,samples_per_host=n_tips),
       trajectories=lapply(epidemics$bank,function(bank) lapply(head(bank,3),function(x) x$traj)),
       trees=lapply(genealogies$bank,function(bank) lapply(bank,function(x) x$tree)),
       metrics=metrics,summary=summary,acceptance=acceptance)
}
