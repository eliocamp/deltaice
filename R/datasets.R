cdo_apply <- function(ifile, op, ofile = NULL) {
  rcdo::cdo_operator("apply", params = c("op"), Inf, 1) |>
    rcdo::cdo(
      input = list(ifile),
      params = list(op = op),
      output = ofile
    )
}

CDR_grid <- function() {
  file <- "data/raw/nsidc_grid.txt"
  rcdo::cdo_griddes(CDR()) |>
    rcdo::cdo_execute(cache = FALSE) |>
    writeLines(file)
  return(file)
}

CDR <- function() {
  old <- rcdo::cdo_cache_set(here::here("data/temp"))
  on.exit(rcdo::cdo_cache_set(old))

  out <- here::here("data/derived/cdr_monthly.nc")

  # Short-circuit so I can delete the daily version
  if (file.exists(out)) {
    return(out)
  }

  icecdr::cdr_antarctic_daily(
    date_range = c(1981, 2023),
    file = "cdr_daily.nc",
    dir = here::here("data/raw/cdr"),
    use_cache = TRUE,
    version = 5,
  ) |>
    icecdr::cdr_fix() |>
    rcdo::cdo_monmean() |>
    rcdo::cdo_setday(1) |>
    rcdo::cdo_settime("00:00:00") |>
    rcdo::cdo_execute(output = out)
}


CDRv4 <- function() {
  old <- rcdo::cdo_cache_set(here::here("data/temp"))
  on.exit(rcdo::cdo_cache_set(old))

  out <- here::here("data/derived/cdrv4_monthly.nc")

  # Short-circuit so I can delete the daily version
  if (file.exists(out)) {
    return(out)
  }

  icecdr::cdr_antarctic_daily(
    date_range = c(1981, 2023),
    file = "cdr_daily_v4.nc",
    dir = here::here("data/raw/cdrv4"),
    use_cache = TRUE,
    version = 4,
  ) |>
    icecdr::cdr_fix() |>
    rcdo::cdo_monmean() |>
    rcdo::cdo_setday(1) |>
    rcdo::cdo_settime("00:00:00") |>
    rcdo::cdo_execute(output = out)
}


CDRv6 <- function() {
  old <- rcdo::cdo_cache_set(here::here("data/temp"))
  on.exit(rcdo::cdo_cache_set(old))

  out <- here::here("data/derived/cdrv6_monthly.nc")

  # Short-circuit so I can delete the daily version
  if (file.exists(out)) {
    return(out)
  }

  icecdr::cdr_antarctic_daily(
    date_range = c(1981, 2023),
    file = "cdr_daily_v6.nc",
    dir = here::here("data/raw/cdrv6"),
    use_cache = TRUE,
    version = 6,
  ) |>
    icecdr::cdr_fix() |>
    rcdo::cdo_monmean() |>
    rcdo::cdo_setday(1) |>
    rcdo::cdo_settime("00:00:00") |>
    rcdo::cdo_execute(output = out)
}

# ERA5_t2m <- function() {
#   box::use(R / functions[dir_part])
#   temp_era_full <- here::here("data/derived/era5_temp_antarctic.nc")

#   if (file.exists(temp_era_full)) {
#     return(temp_era_full)
#   }

#   files <- "/g/data/rt52/era5/single-levels/monthly-averaged/2t/*/*.nc" |>
#     Sys.glob()

#   years <- as.numeric(dir_part(files, 1))

#   files <- files[years > 1979]

#   files |>
#     furrr::future_map_chr(
#       \(x) {
#         x |>
#           rcdo::cdo_remapbil(CDR_grid()) |>
#           rcdo::cdo_daymean() |>
#           rcdo::cdo_execute(cache = TRUE)
#       }
#     ) |>
#     rcdo::cdo_mergetime() |>
#     rcdo::cdo_execute(
#       output = temp_era_full,
#       options = "-O -b f32",
#       cache = TRUE
#     )
#   return(temp_era_full)
# }

ERA5_sst <- function() {
  old <- rcdo::cdo_cache_set(here::here("data/temp/cache"))
  on.exit(rcdo::cdo_cache_set(old))
  box::use(R / functions[dir_part])
  temp_era_full <- here::here("data/derived/era5_sst_antarctic_mon.nc")

  files <- "/g/data/rt52/era5/single-levels/monthly-averaged/sst/*/*.nc" |>
    Sys.glob()

  years <- as.numeric(dir_part(files, 1))

  files <- files[years > 1979]
  grid <- CDR_grid()
  files |>
    lapply(
      \(x) {
        x |>
          rcdo::cdo_remapbil(grid = grid)
      }
    ) |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_setday(1) |>
    rcdo::cdo_settime("00:00:00") |>
    rcdo::cdo_execute(
      output = temp_era_full,
      options = "-O  -L -b f32",
      cache = TRUE
    )
  return(temp_era_full)
}

ERA5_t2m <- function() {
  old <- rcdo::cdo_cache_set(here::here("data/temp/cache"))
  on.exit(rcdo::cdo_cache_set(old))
  box::use(R / functions[dir_part])
  temp_era_full <- here::here("data/derived/era5_temp_antarctic_mon.nc")

  files <- "/g/data/rt52/era5/single-levels/monthly-averaged/2t/*/*.nc" |>
    Sys.glob()

  years <- as.numeric(dir_part(files, 1))

  files <- files[years > 1979]
  grid <- CDR_grid()

  files |>
    lapply(
      \(x) {
        x |>
          rcdo::cdo_remapbil(grid = grid)
      }
    ) |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_setday(1) |>
    rcdo::cdo_settime("00:00:00") |>
    rcdo::cdo_execute(
      output = temp_era_full,
      options = "-O -L -b f32",
      cache = TRUE
    )
  return(temp_era_full)
}


ERA5_t2msd <- function() {
  old <- rcdo::cdo_cache_set(here::here("data/temp/cache"))
  on.exit(rcdo::cdo_cache_set(old))
  box::use(R / functions[dir_part])
  temp_era_full <- here::here("data/derived/era5_temp_antarctic_day.nc")

  if (file.exists(temp_era_full)) {
    return(temp_era_full)
  }
  files <- "/g/data/rt52/era5/single-levels/reanalysis/2t/*/*.nc" |>
    Sys.glob()

  years <- as.numeric(dir_part(files, 1))

  files <- files[years > 1979]
  grid <- CDR_grid()

  files |>
    furrr::future_map(
      \(x) {
        x |>
          rcdo::cdo_remapbil(grid = grid) |>
          rcdo::cdo_daymean() |>
          rcdo::cdo_monstd1() |>
          rcdo::cdo_execute()
      }
    ) |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_setday(1) |>
    rcdo::cdo_settime("00:00:00") |>
    rcdo::cdo_execute(
      output = temp_era_full,
      options = "-O -L -b f32",
      cache = TRUE
    )
  return(temp_era_full)
}


# ERA5 <- function() {
#   file_raw <- here::here("data/raw/era5_ic.nc")
#   file <- here::here("data/derived/era5_ic.nc")

#   if (file.exists(file)) {
#     return(file)
#   }

#   if (!file.exists(file_raw)) {
#     years <- 1981:2023

#     request <- list(
#       dataset_short_name = "reanalysis-era5-single-levels",
#       product_type = "reanalysis",
#       variable = "sea_ice_cover",
#       year = years,
#       month = 1:12,
#       day = 1:31,
#       time = "00:00",
#       data_format = "netcdf",
#       download_format = "unarchived",
#       area = c(-20, 0, -90, 360),
#       target = basename(file_raw)
#     )

#     ecmwfr::wf_request(request, path = dirname(file_raw))
#   }

#   file_raw |>
#     rcdo::cdo_selname("siconc") |>
#     cdo_chname("siconc", "aice") |>
#     remap_cdr() |>
#     cdo_del29feb() |>
#     rcdo::cdo_execute(output = file, options = c("-L", "-O", "-f nc"))

#   system(paste0(
#     "module load nco && ncrename -O -d valid_time,time -v valid_time,time ",
#     file,
#     " ",
#     file
#   ))

#   return(file)
# }

S2_reanalysis <- function() {
  box::use(R / functions[cdo_del29feb])
  file <- here::here("data/derived/access-s2_reanalylsis.nc")

  if (file.exists(file)) {
    return(file)
  }

  years <- 1981:2023
  grid <- CDR_grid()

  weights <- rcdo::cdo_genbil(
    "/g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_1981.nc",
    grid
  ) |>
    rcdo::cdo_execute(options = "-L")

  out <- furrr::future_map_chr(years, \(year) {
    file <- file.path("data", "temp", paste0("s2-reanalys_", year, ".nc"))
    if (file.exists(file)) {
      return(file)
    }
    paste0(
      "/g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_",
      year,
      ".nc"
    ) |>
      rcdo::cdo_remap(grid = grid, weights = weights) |>
      cdo_del29feb() |>
      rcdo::cdo_execute(output = file, options = "-L")
  })

  out |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_execute(output = file, options = "-L")
}

hindcast <- function(forecast_times, members = 1:9) {
  members <- formatC(members, width = 2, flag = "0")

  data <- data.table::CJ(forecast_time = forecast_times, member = members)

  raw_files <- here::here(
    "data/raw/hindcast",
    format(data$forecast_time, '%Y-%m-%d'),
    paste0(data$member, ".nc")
  )
  data$file <- raw_files

  data[file.exists(file)]
}


s2 <- function() {
  out <- here::here("data/derived/hindcast_1month.nc")
  if (file.exists(out)) {
    return(out)
  }

  forecast_times <- seq(
    as.Date("1981-01-01"),
    as.Date("2018-12-01"),
    by = "1 month"
  )
  hindcasts <- hindcast(forecast_times, members = "em")

  hindcasts[, month := data.table::month(forecast_time)]

  hindcasts[,
    .(op = list(rcdo::cdo_selmonth(file, month) |> rcdo::cdo_monmean())),
    by = .(forecast_time, member, month)
  ] |>
    _$op |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_setday(1) |>
    rcdo::cdo_settime("00:00:00") |>
    rcdo::cdo_execute(out = out, cache = TRUE)
}


cmip_augment <- function(files) {
  box::use(R / functions[dir_part])
  data.table::data.table(
    file = files,
    model = dir_part(files, 7),
    experiment = dir_part(files, 6),
    variable = dir_part(files, 3),
    member = dir_part(files, 5),
    version = dir_part(files, 1)
  ) |>
    _[version != "latest"] |>
    _[, version := as.numeric(gsub("v", "", version))]
}

cmip_latest_version <- function(data) {
  data[,
    .SD[version == max(version)],
    by = .(model, experiment, variable, member)
  ]
}

cmip_get <- function(variable, experiment, member = "r1i1p1f1", model = "*") {
  data.table::CJ(
    variable = variable,
    experiment = experiment,
    source = c("oi10/replicas", "fs38/publications")
  ) |>
    glue::glue_data(
      "/g/data/{source}/CMIP6/*/*/{model}/{experiment}/{member}/*mon/{variable}/gn/*/*.nc"
    ) |>
    Sys.glob() |>
    cmip_augment() |>
    _[]
}


cmip_selantmerge <- function(files) {
  dir <- here::here("data/derived/cmip6")
  out <- file.path(dir, basename(files[1]))
  lapply(files, \(x) {
    x |>
      rcdo::cdo_remapbil("r360x180") |>
      rcdo::cdo_sellonlatbox(0, 360, -90, -50)
  }) |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_execute(options = "-L -O", out = out)
}

cmip_complete <- function(data) {
  incomplete <- data |>
    tidyr::complete(model, experiment, member, variable) |>
    data.table::as.data.table() |>
    _[is.na(file)] |>
    _[, unique(model)]

  data[!(model %in% incomplete)][]
}

cmip6 <- function() {
  cmip_get(
    variable = c("tas", "siconc"),
    experiment = c("historical", "ssp585")
  ) |>
    cmip_latest_version() |>
    cmip_complete() |>
    _[,
      .(file = list(future::future(cmip_selantmerge(file)))),
      by = .(experiment, model, variable)
    ] |>
    _[, file := unlist(future::value(file))] |>
    _[]
}
