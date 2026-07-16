# Keep Rcpp exports in a subenvironment
cpp <- new.env()

# Compile. Has a caching function
Rcpp::sourceCpp(
  here::here("src/rcpp.cpp"), # source file
  cacheDir = here::here("src/rcpp-cache"),
  env = cpp
) # default is globalenv(), use a local environment instead


daice <- cpp$daice
predict_dice <- cpp$predict_dice
lookup <- cpp$lookup
interpolate_cpp <- cpp$interpolate_cpp


quantile <- function(
  x,
  probs = seq(0, 1, 0.25),
  na.rm = FALSE,
  names = TRUE,
  type = 7,
  digits = 7,
  fuzz = if (type == 7L) 0 else 4 * .Machine$double.eps,
  ...
) {
  q <- stats::quantile(x, probs, na.rm, names, type, digits, fuzz, ...)
  if (!names) {
    return(q)
  }

  if (is.null(names(probs))) {
    return(q)
  }

  names(q) <- ifelse(names(probs) == "", names(q), names(probs))
  q
}


median_ci <- function(x, ci = .95) {
  quantile(
    stats::na.omit(x),
    probs = c(low = 0.5 - ci / 2, estimate = 0.5, high = 0.5 + ci / 2),
    names = TRUE
  ) |>
    as.list()
}

average <- function(x) {
  test <- t.test(x)
  list(
    estimate = test$estimate,
    low = test$conf.int[1],
    high = test$conf.int[2]
  )
}


normalise_names <- function(data) {
  normal_names <- list(
    x = c("xgrid", "lon", "longitude", "i"),
    y = c("ygrid", "lat", "latitude", "j")
  )

  for (normal_name in names(normal_names)) {
    for (bad_name in normal_names[[normal_name]]) {
      data.table::setnames(data, bad_name, normal_name, skip_absent = TRUE)
    }
  }

  return(data)
}


on_gadi <- function() {
  as.numeric(Sys.getenv("ON_GADI", unset = "0")) == 1
}

ncview <- function(file) {
  system2("ncview", args = c(file), wait = FALSE)
}


remap_cdr <- function(file) {
  nsidc_grid <- here::here("data/raw/nsidc_grid.txt")

  rcdo::cdo_remapbil(file, nsidc_grid)
}

cdo_chname <- function(ifile, oldname, newname, ofile = NULL) {
  rcdo::cdo_operator("chname", params = c("oldname", "newname"), 1, 1) |>
    rcdo::cdo(
      input = list(ifile),
      params = list(oldname = oldname, newname = newname),
      output = ofile
    )
}


cdo_del29feb <- function(ifile, ofile = NULL) {
  rcdo::cdo_operator("del29feb", params = NULL, 1, 1) |>
    rcdo::cdo(
      input = list(ifile),
      params = NULL,
      output = ofile
    )
}


cdo_iiee <- function(ifile1, ifile2, output, threshhold = 0.15) {
  file1 <- rcdo::cdo_gtc(ifile1, c = threshhold) |>
    rcdo::cdo_options_use("-L") |>
    rcdo::cdo_execute()

  file2 <- rcdo::cdo_gtc(ifile2, c = threshhold) |>
    rcdo::cdo_options_use("-L") |>
    rcdo::cdo_execute()

  out <- rcdo::cdo_ne(file1, file2) |>
    rcdo::cdo_fldint() |>
    rcdo::cdo_execute(output = output)

  file.remove(c(file1, file2))
  return(out)
}


cdo_rmse <- function(file1, file2) {
  rcdo::cdo_sub(file1, file2) |>
    rcdo::cdo_sqr() |>
    rcdo::cdo_fldmean() |>
    rcdo::cdo_sqrt()
}

cdo_extent <- function(file, threshhold = 0.15) {
  file |>
    rcdo::cdo_gtc(threshhold) |>
    rcdo::cdo_fldint()
}


pad_number <- function(x, pad = 2) formatC(x, width = pad, flag = "0")


sd_ci <- function(x, signif = 2, sep = "\ ", ...) {
  estimate <- sd(x, ...)

  # From https://daniellakens.blogspot.com/2019/07/calculating-confidence-intervals-around.html
  N <- sum(!is.na(x))
  alpha <- 0.05
  low_chi <- qchisq(alpha / 2, N - 1, lower.tail = TRUE)
  high_chi <- qchisq(alpha / 2, N - 1, lower.tail = FALSE)

  out <- list(
    estimate = estimate,
    p.value = NA_real_,
    low = sqrt((N - 1) / low_chi) * estimate,
    high = sqrt((N - 1) / high_chi) * estimate
  )
  out$text <- with(
    out,
    paste0(
      round(estimate, signif),
      sep,
      "(CI:\ ",
      round(low, signif),
      "\ --\ ",
      round(high, signif),
      ")"
    )
  )

  out
}


correlate <- function(x, y, signif = 2, sep = "\ ", ...) {
  correlation <- stats::cor.test(x, y, ...)
  out <- with(
    correlation,
    list(
      estimate = estimate,
      p.value = p.value,
      low = conf.int[1],
      high = conf.int[2]
    )
  )

  # out$text <- with(
  #   out,
  #   paste0(
  #     round(estimate, signif),
  #     sep,
  #     "(CI:\ ",
  #     round(low, signif),
  #     "\ --\ ",
  #     round(high, signif),
  #     ")"
  #   )
  # )

  out
}


rmse <- function(x, y) {
  dif <- x - y
  df <- sum(!is.na(dif)) - 2
  # rmse <- sqrt(mean(dif^2, na.rm = TRUE))
  rmse <- mean(abs(dif), na.rm = TRUE)

  p_lower <- 0.025
  p_upper <- 0.975

  out <- list(
    estimate = rmse,
    p.value = NA_real_,
    low = sqrt(df / stats::qchisq(p_upper, df = df)) * rmse,
    high = sqrt(df / stats::qchisq(p_lower, df = df)) * rmse
  )

  return(out)
}

stat2text <- function(estimate, low, high, signif = 2, sep = "\ ") {
  paste0(
    round(estimate, signif),
    sep,
    "(CI:\ ",
    round(low, signif),
    "\ --\ ",
    round(high, signif),
    ")"
  )
}

dir_part <- function(x, n = 0) {
  for (i in seq_len(n)) {
    x <- dirname(x)
  }

  return(basename(x))
}


lm_constrained <- function(data, formula) {
  # Design matrix for polynomial fit (example: quadratic in t2m, linear in aice)
  # formula <-
  X <- stats::model.matrix(formula, data = data)
  y <- data$daice

  # Quadratic programming setup
  Dmat <- t(X) %*% X
  dvec <- t(X) %*% y

  # Constraints:
  # If aice = 0 -> daice >= 0
  min_aice <- data$aice == min(data$aice)
  A1 <- X[min_aice, , drop = FALSE]
  b1 <- rep(0, nrow(A1))

  # If aice = 1 -> daice <= 0
  A2 <- -X[data$aice == 1, , drop = FALSE]
  b2 <- rep(0, nrow(A2))

  # negative values at high temp
  A3 <- -X[data$t2m > -1 & !(min_aice), , drop = FALSE]
  b3 <- rep(0, nrow(A3))

  # positive values at low temp
  A4 <- X[data$t2m < -30 & !(data$aice == 1), , drop = FALSE]
  b4 <- rep(0, nrow(A4))

  Amat <- t(rbind(A1, A2, A3, A4)) # constraints in quadprog form: t(Amat) %*% beta >= bvec
  bvec <- c(b1, b2, b3, b4)

  fit <- quadprog::solve.QP(Dmat, dvec, Amat, bvec)

  # Create a normal lm fit and replace coefficients with the new
  formula2 <- stats::as.formula(paste0("daice ~", as.character(formula)[2]))
  mod <- stats::lm(formula2, data = data[1:100, ])
  mod$coefficients <- fit$solution
  mod
}


freezepoint <- function(S, P = 100) {
  a0 <- -0.0575
  a1 <- 1.710523e-3
  a2 <- -2.154996e-4
  b <- -7.53e-4

  # freezing point in Celsius
  fpoint <- a0 * S + a1 * S * sqrt(S) + a2 * S * S + b * P

  fpoint
}

salinity <- function(T, P = 100) {
  a0 <- -0.0575
  a1 <- 1.710523e-3
  a2 <- -2.154996e-4
  b <- -7.53e-4

  if (length(P) == 1) {
    P <- rep(P, length(T))
  }

  if (length(T) != length(P)) {
    stop("T and P must have the same length, or P must be scalar.")
  }

  S_vals <- mapply(
    function(Ti, Pi) {
      f <- function(S) {
        a0 * S + a1 * S * sqrt(S) + a2 * S^2 + b * Pi - Ti
      }

      # try solving; return NA if it fails
      tryCatch(
        {
          uniroot(f, lower = 0, upper = 50)$root
        },
        error = function(e) NA
      )
    },
    T,
    P
  )

  return(S_vals)
}

#' Discretise data
cut_mid <- \(x, width, center) {
  breaks <- metR::AnchorBreaks(center + width, binwidth = width * 2)(range(
    x,
    na.rm = TRUE
  ))

  santoku::chop(x, breaks, labels = santoku::lbl_midpoints()) |>
    as.character() |>
    as.numeric()
}


#' Function factory for generating breaks separated by `by`, aligned to `boundary`
#'
#' @param by Numeric step (applied when the returned function is called on
#'   numeric `x`), or a string like "5 years", "3 months", "2 weeks",
#'   "10 days", "6 hours" (applied when called on Date/POSIXt `x`), as in
#'   `seq.Date` / `seq.POSIXt`.
#' @param boundary Numeric. The break sequence is anchored so that its first
#'   break is a multiple of `boundary` (for Dates/datetimes, a multiple of
#'   `boundary` in the units used by `by`, e.g. boundary = 10 with
#'   by = "5 years" means the first break falls on a year divisible by 10).
#'   Defaults to `NULL`, which uses the numeric part of `by` (e.g.
#'   by = "5 years" defaults to boundary = 5; a numeric `by` of 5 also
#'   defaults to boundary = 5).
#'
#' @return A function of one argument `x` (numeric, Date, or POSIXct/POSIXlt)
#'   that returns a vector of breaks covering the range of `x`.
breaks_by <- function(by, boundary = NULL) {
  force(by)
  force(boundary)
  function(x) breaks_by_fun(x, by, boundary)
}

breaks_by_fun <- function(x, by, boundary) {
  UseMethod("breaks_by_fun")
}


breaks_by_fun.default <- function(x, by, boundary) {
  if (is.null(boundary)) {
    boundary <- by
  }
  rng <- range(x, na.rm = TRUE)
  origin <- boundary * floor(rng[1] / boundary)
  n <- ceiling((rng[2] - origin) / by) + 1
  origin + by * (0:n)
}

parse_by_unit <- function(by, units) {
  pattern <- sprintf(
    "^\\s*(-?\\d*)\\s*(%s)s?\\s*$",
    paste(units, collapse = "|")
  )
  parts <- regmatches(by, regexec(pattern, by))[[1]]
  if (length(parts) == 0) {
    stop(sprintf(
      "`by` must look like '5 years', '3 months', etc. (unit one of: %s)",
      paste(units, collapse = ", ")
    ))
  }
  n <- if (parts[2] == "") 1 else as.numeric(parts[2])
  list(n = n, unit = parts[3])
}

breaks_by_fun.Date <- function(x, by, boundary) {
  units <- c("year", "quarter", "month", "week", "day")
  pb <- parse_by_unit(by, units)
  n <- pb$n
  unit <- pb$unit
  if (is.null(boundary)) {
    boundary <- n
  }

  rng <- range(x, na.rm = TRUE)

  get_index <- function(d) {
    switch(
      unit,
      year = as.numeric(format(d, "%Y")),
      quarter = as.numeric(format(d, "%Y")) *
        4 +
        (as.numeric(format(d, "%m")) - 1) %/% 3,
      month = as.numeric(format(d, "%Y")) *
        12 +
        (as.numeric(format(d, "%m")) - 1),
      week = as.numeric(d) %/% 7,
      day = as.numeric(d)
    )
  }

  index_to_date <- function(idx) {
    switch(
      unit,
      year = as.Date(sprintf("%d-01-01", idx)),
      quarter = {
        yr <- idx %/% 4
        q <- idx %% 4
        as.Date(sprintf("%d-%02d-01", yr, q * 3 + 1))
      },
      month = {
        yr <- idx %/% 12
        mo <- idx %% 12
        as.Date(sprintf("%d-%02d-01", yr, mo + 1))
      },
      week = as.Date(idx * 7, origin = "1970-01-01"),
      day = as.Date(idx, origin = "1970-01-01")
    )
  }

  start_idx <- get_index(rng[1])
  origin_idx <- boundary * floor(start_idx / boundary)
  origin_date <- index_to_date(origin_idx)
  by_arg <- paste(n, paste0(unit, "s"))

  breaks <- seq(origin_date, by = by_arg, length.out = 2)
  while (max(breaks) < rng[2]) {
    breaks <- seq(origin_date, by = by_arg, length.out = length(breaks) + 1)
  }
  breaks
}

breaks_by_fun.POSIXt <- function(x, by, boundary) {
  x <- as.POSIXct(x)
  tz <- attr(x, "tzone")
  if (is.null(tz)) {
    tz <- ""
  }

  units <- c("year", "quarter", "month", "week", "day", "hour", "min", "sec")
  pb <- parse_by_unit(by, units)
  n <- pb$n
  unit <- pb$unit
  if (is.null(boundary)) {
    boundary <- n
  }

  rng <- range(x, na.rm = TRUE)

  get_index <- function(d) {
    switch(
      unit,
      year = as.numeric(format(d, "%Y", tz = tz)),
      quarter = as.numeric(format(d, "%Y", tz = tz)) *
        4 +
        (as.numeric(format(d, "%m", tz = tz)) - 1) %/% 3,
      month = as.numeric(format(d, "%Y", tz = tz)) *
        12 +
        (as.numeric(format(d, "%m", tz = tz)) - 1),
      week = as.numeric(d) %/% (7 * 86400),
      day = as.numeric(d) %/% 86400,
      hour = as.numeric(d) %/% 3600,
      min = as.numeric(d) %/% 60,
      sec = as.numeric(d)
    )
  }

  index_to_date <- function(idx) {
    switch(
      unit,
      year = as.POSIXct(sprintf("%d-01-01 00:00:00", idx), tz = tz),
      quarter = {
        yr <- idx %/% 4
        q <- idx %% 4
        as.POSIXct(sprintf("%d-%02d-01 00:00:00", yr, q * 3 + 1), tz = tz)
      },
      month = {
        yr <- idx %/% 12
        mo <- idx %% 12
        as.POSIXct(sprintf("%d-%02d-01 00:00:00", yr, mo + 1), tz = tz)
      },
      week = as.POSIXct(idx * 7 * 86400, origin = "1970-01-01", tz = tz),
      day = as.POSIXct(idx * 86400, origin = "1970-01-01", tz = tz),
      hour = as.POSIXct(idx * 3600, origin = "1970-01-01", tz = tz),
      min = as.POSIXct(idx * 60, origin = "1970-01-01", tz = tz),
      sec = as.POSIXct(idx, origin = "1970-01-01", tz = tz)
    )
  }

  start_idx <- get_index(rng[1])
  origin_idx <- boundary * floor(start_idx / boundary)
  origin_date <- index_to_date(origin_idx)
  by_arg <- paste(n, paste0(unit, "s"))

  breaks <- seq(origin_date, by = by_arg, length.out = 2)
  while (max(breaks) < rng[2]) {
    breaks <- seq(origin_date, by = by_arg, length.out = length(breaks) + 1)
  }
  breaks
}


with_args <- function(args, calls) {
  calls_expr <- substitute(calls)
  stopifnot(is.call(calls_expr), identical(calls_expr[[1]], quote(list)))
  call_list <- as.list(calls_expr)[-1]

  pf <- parent.frame()

  lapply(call_list, function(cl) {
    fname <- cl[[1]]
    existing <- as.list(cl)[-1]
    enames <- names(existing)
    if (is.null(enames)) {
      enames <- rep("", length(existing))
    }

    merged <- args
    mnames <- names(merged)
    if (is.null(mnames)) {
      mnames <- rep("", length(merged))
    }
    mnames[is.na(mnames)] <- ""
    names(merged) <- mnames

    outer_unnamed_pos <- which(mnames == "")
    pos_i <- 0

    for (i in seq_along(existing)) {
      nm <- enames[i]
      if (is.na(nm) || nm == "") {
        pos_i <- pos_i + 1
        if (pos_i <= length(outer_unnamed_pos)) {
          # inner positional arg overrides outer positional arg at same slot
          merged[[outer_unnamed_pos[pos_i]]] <- existing[[i]]
        } else {
          merged <- c(merged, setNames(existing[i], ""))
        }
      } else {
        merged[[nm]] <- existing[[i]]
      }
    }

    eval(as.call(c(fname, merged)), envir = pf)
  })
}

dir_cache <- cachem::cache_disk(
  here::here("data/cache/memoise"),
  max_size = Inf
)

grid_ice <- (function(aice, tas, time = c(NA, NA)) {
  subset <- list(time = time)

  aice <- aice |>
    metR::ReadNetCDF(c(aice = "siconc"), subset = subset) |>
    stats::na.omit() |>
    _[, aice := aice / 100] |>
    _[, daice := c(diff(aice), NA), by = .(lon, lat)]

  tas <- metR::ReadNetCDF(tas, c(t2m = "tas"), subset = subset) |>
    _[, t2m := t2m - 273.15]

  tas[aice, on = .NATURAL] |>
    _[,
      .(daice = mean(daice, na.rm = TRUE), n = sum(!is.na(daice))),
      by = .(t2m = cut_mid(t2m, 0.2, 0), aice = cut_mid(aice, 0.01, 0.11))
    ]
}) |>
  memoise::memoise(cache = dir_cache)

daice_read <- (function() {
  box::use(R / datasets[...])
  box::use(data.table[...])

  ant_ice <- CDRv6() |>
    metR::ReadNetCDF("aice") |>
    normalise_names() |>
    _[, daice := c(diff(aice), NA), by = .(x, y)]

  temp_era_mon <- ERA5_t2m() |>
    metR::ReadNetCDF("t2m")

  sst_era_mon <- ERA5_sst() |>
    metR::ReadNetCDF("sst")

  daice <- ant_ice |>
    _[temp_era_mon, on = .NATURAL] |>
    _[sst_era_mon, on = .NATURAL] |>
    _[data.table::year(time) %between% c(1983, 2024)] |>
    _[, t2m := t2m - 273.15] |>
    _[, sst := sst - 273.15] |>
    _[, time := as.Date(time)]
}) |>
  memoise::memoise(
    cache = dir_cache
  )

era_temp_fun <- function(data) {
  t2m_matrix <- data[, .(time, x, y, t2m)] |>
    metR:::.tidy2matrix(x + y ~ time, value.var = "t2m") |>
    _$matrix
  t2m_time <- 0:(ncol(t2m_matrix) - 1)

  function(t) interpolate_cpp(t2m_matrix, t2m_time, t)
}


stl_anom <- function(x, s.window = 7, t.window = 10) {
  split <- stats:stl(
    stats::ts(x, frequency = 12),
    s.window = 7,
    t.window = t.window * 12
  )

  x - split$time.series[, 1]
}
