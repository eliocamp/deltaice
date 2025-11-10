return_if_exists <- function(file) {
  box::use(rlang)
  if (!file.exists(file)) {
    return(invisible(FALSE))
  }

  call <- rlang::expr(return(!!file))
  rlang::eval_bare(call, env = parent.frame())
}


name_from_dataset <- function(dataset, ...) {
  hash <- hash_list(list(...))
  paste0(tools::file_path_sans_ext(basename(dataset)), "_", hash, ".nc")
}

hash_files_maybe <- function(x) {
  if (!is.character(x) || inherits(x, "AsIs")) {
    return(rlang::hash(x))
  }

  if (file.exists(x)) {
    return(rlang::hash(file.info(x)[c("size", "mtime")]))
  } else {
    return(rlang::hash(x))
  }
}

hash_list <- function(x) {
  # Base case
  # length could be zero (x = NULL)
  if (length(x) <= 1) {
    return(hash_files_maybe(x))
  }

  # Recursive case,
  # apply this to each element and combine the hashes
  hashes <- vapply(x, hash_list, character(1))
  return(rlang::hash(hashes))
}

cache_op <- function(fun, location, ...) {
  force(location)
  dir.create(location, showWarnings = FALSE, recursive = TRUE)
  force(fun)
  funhash <- rlang::hash(fun)
  call <- rlang::call_match()
  cached_fun <- function(dataset) {
    # Need to hash all formals
    call <- rlang::call_match(defaults = TRUE)
    call[[1]] <- match.fun("list")
    tohash <- rlang::eval_bare(call, env = parent.frame())

    hash <- hash_list(list(tohash, funhash))
    filename <- paste0(
      tools::file_path_sans_ext(basename(dataset)),
      "_",
      hash,
      ".nc"
    )

    output <- file.path(location, filename)

    return_if_exists(output)

    args <- append(list(output = output), tohash)
    as.character(do.call(fun, args))
  }

  extra_args <- as.list(call)[-c(1:3)]

  rlang::fn_fmls(cached_fun) <- append(
    rlang::fn_fmls(cached_fun)[1],
    extra_args
  )

  cached_fun
}


# Simpler version of cache_op and maybe more flexible
# It memoises the function and runs it.
# If the output file doesn't exist anymore, it forgets the cache for these arguments and
# re-runs it.

cache_op2 <- function(fun) {
  fun_mem <- memoise::memoise(
    fun,
    cache = cachem::cache_disk(here::here("data/cache"))
  )

  fun_out <- function() {
    args <- rlang::call_match(defaults = TRUE)
    args[[1]] <- match.fun("list")
    args <- rlang::eval_bare(args, env = parent.frame())
    hash <- hash_list(args)
    attr(args[[1]], "hash") <- hash
    out <- do.call(fun_mem, args)

    if (file.exists(out)) {
      return(out)
    }

    do.call(memoise::drop_cache(fun_mem), args)
    return(do.call(fun_mem, args))
  }

  rlang::fn_fmls(fun_out) <- rlang::fn_fmls(fun)
  fun_out
}


compute_climatology <- function(
  dataset,
  climatology = 1981:2011,
  year = 2024,
  options = c("-L"),
  output
) {
  message("Computing climatology to ", output)
  dates <- c(
    paste0(min(climatology), "-01-01"),
    paste0(max(climatology), "-12-31")
  )

  noisy <- dataset |>
    rcdo::cdo_seldate(
      startdate = dates[1],
      enddate = dates[2]
    ) |>
    rcdo::cdo_ydaymean() |>
    rcdo::cdo_setyear(year) |>
    rcdo::cdo_execute(options = options, output = output)

  return(noisy)
}


climatology <- cache_op(
  compute_climatology,
  here::here("data/derived/climatology"),
  climatology = 1981:2011,
  year = 2024,
  options = c("-L")
)


compute_anomalies <- function(dataset, clim = climatology(dataset), output) {
  message("Computing anomalies to ", output)
  rcdo::cdo_ydaysub(cdo_del29feb(dataset), cdo_del29feb(clim)) |>
    rcdo::cdo_execute(output = output, options = "-L")
}

anomalies <- cache_op(
  compute_anomalies,
  location = here::here("data/derived/anomalies"),
  clim = climatology(dataset)
)

compute_process_ice <- function(dataset, output) {
  dataset |>
    rcdo::cdo_seltimestep("1/35") |>
    rcdo::cdo_selname("aice") |>
    rcdo::cdo_setyear(2024) |>
    remap_cdr() |>
    cdo_del29feb() |>
    rcdo::cdo_execute(output)
}


process_ice <- cache_op(
  compute_process_ice,
  location = here::here("data/derived/ice")
)


process_zg <- (function(dataset, output) {
  nlon <- metR::GlanceNetCDF(dataset)$dim$lon$len

  if (nlon == 432) {
    thinning <- \(x) rcdo::cdo_samplegrid(x, 2)
  } else {
    thinning <- identity
  }

  dataset |>
    cdo_sellevel(levels = "300,850") |>
    cdo_seltimestep("1/35") |>
    thinning() |>
    cdo_chname("z1_p_level", "lev") |>
    cdo_setyear(2024) |>
    cdo_execute(output, options = "-L")
}) |>
  cache_op(here::here("data/derived/zg"))


cdo_area_cmip6 <- (function(dataset) {
  dataset |>
    cdo_remapmean("r360x180") |>
    cdo_sellonlatbox(0, 360, -90, -40) |>
    cdo_divc(100) |>
    cdo_fldint() |>
    cdo_execute(tempfile(), options = c("-L -s"))
})


compute_area_cmip6 <- (function(files) {
  output <- here::here("data/derived/ice", hash_list(files))
  files |>
    lapply(cdo_area_cmip6) |>
    cdo_mergetime() |>
    cdo_execute(output, options = "-L -s -O")
}) |>
  cache_op2()


compute_epflux <- function(temperature_file, u_file, v_file) {
  box::use(R / functions[normalise_names])
  box::use(rcdo[...])

  r <- metR:::a
  derv <- function(y, x) {
    c(NA, diff(y) / diff(x))
  }

  kappa <- 2 / 7
  p0 <- 100000

  t_name <- cdo_showname(temperature_file) |>
    cdo_execute() |>
    trimws()

  theta <- temperature_file |>
    cdo_expr(glue::glue("'theta={t_name}*({p0}/clev({t_name}))^{kappa}'")) |>
    cdo_execute()

  cdo_zonanom <- function(x) {
    cdo_sub(x, cdo_enlarge(cdo_zonmean(x), grid = x))
  }

  theta_z <- theta |>
    cdo_zonanom() |>
    cdo_execute(output = tempfile(tmpdir = here::here("data/temp/epflux")))

  u_z <- u_file |>
    cdo_zonanom() |>
    cdo_execute(output = tempfile(tmpdir = here::here("data/temp/epflux")))

  v_z <- v_file |>
    cdo_zonanom() |>
    cdo_execute(output = tempfile(tmpdir = here::here("data/temp/epflux")))

  vu <- cdo_mul(v_z, u_z) |>
    cdo_zonmean() |>
    cdo_execute(output = tempfile(tmpdir = here::here("data/temp/epflux")))

  vt <- cdo_mul(v_z, theta_z) |>
    cdo_zonmean() |>
    cdo_execute(output = tempfile(tmpdir = here::here("data/temp/epflux")))

  theta_m <- cdo_zonmean(theta) |>
    cdo_execute(output = tempfile(tmpdir = here::here("data/temp/epflux")))

  flux <- vu |>
    metR::ReadNetCDF(\(vars) c("vu" = vars[[1]])) |>
    _[, vt := metR::ReadNetCDF(vt, out = "vector")[[1]]] |>
    _[, theta := metR::ReadNetCDF(theta_m, out = "vector")[[1]]] |>
    _[] |>
    normalise_names()

  # These can get big when running the function in parallel
  file.remove(c(theta_z, theta, u_z, v_z, vu, vt, theta_m))

  # Finish up with the fluxes
  flux <- flux[order(-lev)] |>
    _[,
      theta_p := derv(theta, log(lev * 100)) / (lev * 100),
      by = .(time, lat)
    ] |>
    _[, coslat := cos(lat * pi / 180)] |>
    _[, .(
      f_lat = -vu * r * coslat,
      f_lev = vt / theta_p * coslat * metR::coriolis(lat) * r,
      time = time,
      lat = lat,
      lev = lev
    )]
  # Compute divergence
  flux <- flux[,
    f_lat_div := derv(f_lat * cos(lat * pi / 180), lat * pi / 180) /
      (r * cos(lat * pi / 180)),
    by = .(lev, time)
  ] |>
    _[order(-lev)] |>
    _[,
      f_lev_div := derv(f_lev, log(lev * 100)) / (lev * 100),
      by = .(lat, time)
    ] |>
    _[, div := f_lat_div + f_lev_div]

  flux[]
}

write_ep_flux <- function(flux, out) {
  flux[, lon := 0]
  metR:::WriteNetCDF(
    flux,
    file = out,
    vars = c("f_lat", "f_lev", "div"),
    dims = c("lon", "lat", "lev", "time")
  )
}

ep_scale_plot <- function(f_lat, f_lev, lat) {
  r <- metR:::a
  list(
    f_lat_plot = 2 * pi * r * cos(lat * pi / 180) / 9.8 * f_lat,
    f_lev_plot = 2 * pi * r^2 * cos(lat * pi / 180) / 9.8 * f_lev
  )
}
